# rn = @reaction_network begin
#     d, A --> 0
#     kp*sqrt(A), 0 --> P
# end

module ReactionNetwork

using Symbolics, Catalyst, ModelingToolkit
using ..EnzymemlV2: EnzymeMLDocument, Reaction, ReactionElement, Equation

"""
    format_stoichiometry(stoich::Float64)

Format stoichiometry for display in reaction equations.
Returns empty string for 1.0, the number for other values.
"""
function format_stoichiometry(stoich::Float64)
    if stoich == 1.0
        return ""
    else
        return string(Int(stoich)) * "*"
    end
end

"""
    build_reaction_side(elements::Vector{ReactionElement}, species_map::Dict{String, String})

Build the reactant or product side of a reaction equation.

# Arguments
- `elements::Vector{ReactionElement}`: The reaction elements (reactants or products)
- `species_map::Dict{String, String}`: Mapping from species IDs to their symbols

# Returns
- String representation of the reaction side
"""
function build_reaction_side(elements::Vector{ReactionElement}, species_map::Dict{String,String})
    if isempty(elements)
        return "0"
    end

    terms = String[]
    for element in elements
        stoich_str = format_stoichiometry(abs(element.stoichiometry))
        species_symbol = species_map[element.species_id]
        push!(terms, stoich_str * species_symbol)
    end

    return join(terms, " + ")
end

"""
    extract_species_from_reactions(reactions::Vector{Reaction})

Extract all unique species involved in reactions.

# Arguments
- `reactions::Vector{Reaction}`: List of reactions from EnzymeML document

# Returns
- Vector of unique species IDs
"""
function extract_species_from_reactions(reactions::Vector{Reaction})
    species_ids = Set{String}()

    for reaction in reactions
        if reaction.reactants !== nothing
            for reactant in reaction.reactants
                push!(species_ids, reactant.species_id)
            end
        end

        if reaction.products !== nothing
            for product in reaction.products
                push!(species_ids, product.species_id)
            end
        end

        if reaction.modifiers !== nothing
            for modifier in reaction.modifiers
                push!(species_ids, modifier.species_id)
            end
        end
    end

    return collect(species_ids)
end

"""
    extract_non_constant_species(enzmldoc::EnzymeMLDocument, reactions::Vector{Reaction})

Extract all unique non-constant species involved in reactions.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document containing species information
- `reactions::Vector{Reaction}`: List of reactions from EnzymeML document

# Returns
- Vector of unique non-constant species IDs
"""
function extract_non_constant_species(enzmldoc::EnzymeMLDocument, reactions::Vector{Reaction})
    # Get all species from reactions
    all_species_ids = extract_species_from_reactions(reactions)

    # Create a map of species ID to constant status
    species_constant_map = Dict{String,Bool}()

    # Check small molecules
    if enzmldoc.small_molecules !== nothing
        for sm in enzmldoc.small_molecules
            species_constant_map[sm.id] = sm.constant
        end
    end

    # Check proteins
    if enzmldoc.proteins !== nothing
        for protein in enzmldoc.proteins
            species_constant_map[protein.id] = protein.constant
        end
    end

    # Filter out constant species
    non_constant_species = String[]
    for species_id in all_species_ids
        if haskey(species_constant_map, species_id) && !species_constant_map[species_id]
            push!(non_constant_species, species_id)
        elseif !haskey(species_constant_map, species_id)
            # If not found in species definitions, assume it's non-constant
            push!(non_constant_species, species_id)
        end
    end

    return non_constant_species
end

"""
    @reaction_system(enzmldoc::EnzymeMLDocument)

Create a Catalyst reaction system from reactions in an EnzymeMLDocument.

# Arguments
- `enzmldoc`: An EnzymeMLDocument containing reaction specifications

# Returns
- Tuple containing:
  - The Catalyst ReactionSystem (or ODESystem equivalent)
  - Dictionary of species symbols (as Symbol, matching @system format)
  - Dictionary of parameter symbols

# Example
```julia
enzmldoc = JSON3.read(json_string, EnzymeMLDocument)
rn, species, params = @reaction_system(enzmldoc)
```
"""
macro reaction_system(enzmldoc::Symbol)
    quote
        let
            doc = $(esc(enzmldoc))

            # Check if there are reactions
            if doc.reactions === nothing || isempty(doc.reactions)
                error("No reactions found in EnzymeML document")
            end

            # Create time variable first
            t = eval(:(@independent_variables t))[1]

            # Extract parameters
            parameters = Dict{String,Any}()
            param_symbols = Dict{String,Symbolics.Num}()
            if doc.parameters !== nothing
                for parameter in doc.parameters
                    parameters[parameter.symbol] = parameter
                    param_symbols[parameter.symbol] = eval(:(@parameters $(Symbol(parameter.symbol))))[1]
                end
            end

            # Extract only non-constant species from reactions
            species_ids = extract_non_constant_species(doc, doc.reactions)

            # Parse kinetic laws to identify what variables are actually used
            used_symbols = Set{String}()
            for reaction in doc.reactions
                if reaction.kinetic_law !== nothing
                    # Extract symbols from the kinetic law equation
                    # This is a simple approach - could be improved with proper parsing
                    equation = reaction.kinetic_law.equation
                    for species_id in extract_species_from_reactions(doc.reactions)
                        if occursin(species_id, equation)
                            push!(used_symbols, species_id)
                        end
                    end
                    # Also check for parameters
                    if doc.parameters !== nothing
                        for param in doc.parameters
                            if occursin(param.symbol, equation)
                                push!(used_symbols, param.symbol)
                            end
                        end
                    end
                end
            end

            # Only handle constant species that are actually used in kinetic laws
            all_species_ids = extract_species_from_reactions(doc.reactions)
            constant_species_ids = setdiff(all_species_ids, species_ids)
            used_constant_species = intersect(constant_species_ids, used_symbols)

            # Add used constant species as parameters (with their concentrations)
            for species_id in used_constant_species
                param_symbols[species_id] = eval(:(@parameters $(Symbol(species_id))))[1]
            end

            # Create species symbols (matching @system format with Symbol values)
            species_symbols_dict = Dict{String,Symbol}()
            species_vars = Dict{String,Symbolics.Num}()
            for species_id in species_ids
                species_symbols_dict[species_id] = Symbol(species_id)
                species_vars[species_id] = eval(:(@species $(Symbol(species_id))(t)))[1]
            end

            # Create symbolic variables for used constant species (needed for rate expressions)
            constant_species_vars = Dict{String,Symbolics.Num}()
            for species_id in used_constant_species
                constant_species_vars[species_id] = param_symbols[species_id]
            end

            # Combine all species variables for rate expression parsing
            all_species_vars = merge(species_vars, constant_species_vars)

            # Build reactions using Catalyst.Reaction
            reactions = []
            rate_expressions = Dict{String,String}()

            for reaction in doc.reactions
                # Extract kinetic law if available
                rate_expr = "1.0"  # default rate
                if reaction.kinetic_law !== nothing
                    rate_expr = reaction.kinetic_law.equation
                    rate_expressions[reaction.id] = rate_expr
                end

                # Parse rate expression
                rate = eval(Meta.parse(rate_expr))

                # Build reactants
                reactants = []
                reactant_stoich = []
                if reaction.reactants !== nothing
                    for reactant in reaction.reactants
                        push!(reactants, all_species_vars[reactant.species_id])
                        push!(reactant_stoich, Int(abs(reactant.stoichiometry)))
                    end
                end

                # Build products
                products = []
                product_stoich = []
                if reaction.products !== nothing
                    for product in reaction.products
                        push!(products, all_species_vars[product.species_id])
                        push!(product_stoich, Int(abs(product.stoichiometry)))
                    end
                end

                # Create Catalyst Reaction
                if reaction.reversible
                    # For reversible reactions, create two separate reactions for now
                    # Forward reaction
                    forward_rxn = Catalyst.Reaction(rate, reactants, products, reactant_stoich, product_stoich)
                    push!(reactions, forward_rxn)

                    # Backward reaction (using same rate for simplicity)
                    backward_rxn = Catalyst.Reaction(rate, products, reactants, product_stoich, reactant_stoich)
                    push!(reactions, backward_rxn)
                else
                    # Irreversible reaction
                    rxn = Catalyst.Reaction(rate, reactants, products, reactant_stoich, product_stoich)
                    push!(reactions, rxn)
                end
            end

            # Create all species and parameters for the system
            all_species = collect(values(species_vars))  # Only non-constant species
            all_params = collect(values(param_symbols))

            # Create the reaction system
            rn = ReactionSystem(reactions, t, all_species, all_params, name=:reaction_system)

            # Convert to ODESystem and simplify to match @system output format
            ode_sys = convert(ODESystem, complete(rn))
            simplified_sys = structural_simplify(ode_sys)

            # Return in same format as @system: (simplified_system, vars_as_symbols, params)
            (simplified_sys, species_symbols_dict, param_symbols)
        end
    end
end

export @reaction_system, extract_species_from_reactions, extract_non_constant_species, build_reaction_side, format_stoichiometry

end # module ReactionNetwork

