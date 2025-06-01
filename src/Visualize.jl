module Visualize

using ..EnzymemlV2: EnzymeMLDocument
using ..EnzymeMLSystem: @system
using ..V2Utils: extract_measurements, extract_parameters
using DifferentialEquations
using Plots

"""
    plot_enzymeml_document(enzmldoc::EnzymeMLDocument)

Plot experimental data from an EnzymeML document. If the document contains model equations
and all parameters have values, also plot the simulation fit.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to visualize

# Returns
- Plot object containing subplots for each measurement
"""
function plot_enzymeml_document(enzmldoc::EnzymeMLDocument)
    # Extract experimental data
    u0s, obs_data = extract_measurements(enzmldoc, _get_variable_symbols(enzmldoc))

    sim_data = nothing
    if _can_simulate(enzmldoc)
        sim_data = _create_simulation_data(enzmldoc, u0s)
    end

    return _create_measurement_plots(enzmldoc.measurements, obs_data, sim_data)
end

"""
    _can_simulate(enzmldoc::EnzymeMLDocument) -> Bool

Check if the document has model equations and all parameters have values.
"""
function _can_simulate(enzmldoc::EnzymeMLDocument)
    return _has_model_equations(enzmldoc) && _all_parameters_have_values(enzmldoc)
end

"""
    _has_model_equations(enzmldoc::EnzymeMLDocument) -> Bool

Check if the document contains equations or kinetic laws.
"""
function _has_model_equations(enzmldoc::EnzymeMLDocument)
    has_equations = enzmldoc.equations !== nothing && !isempty(enzmldoc.equations)
    has_kinetic_laws = false

    if enzmldoc.reactions !== nothing
        for reaction in enzmldoc.reactions
            if reaction.kinetic_law !== nothing
                has_kinetic_laws = true
                break
            end
        end
    end

    return has_equations || has_kinetic_laws
end

"""
    _all_parameters_have_values(enzmldoc::EnzymeMLDocument) -> Bool

Check if all parameters have actual values (not nothing).
"""
function _all_parameters_have_values(enzmldoc::EnzymeMLDocument)
    if enzmldoc.parameters === nothing || isempty(enzmldoc.parameters)
        return false
    end

    for parameter in enzmldoc.parameters
        if parameter.value === nothing
            return false
        end
    end

    return true
end

"""
    _get_variable_symbols(enzmldoc::EnzymeMLDocument) -> Dict{String,Symbol}

Extract variable symbols from the document for species.
"""
function _get_variable_symbols(enzmldoc::EnzymeMLDocument)
    vars = Dict{String,Symbol}()

    if enzmldoc.small_molecules !== nothing
        for sm in enzmldoc.small_molecules
            vars[sm.id] = Symbol(sm.id)
        end
    end

    if enzmldoc.proteins !== nothing
        for protein in enzmldoc.proteins
            if !protein.constant
                vars[protein.id] = Symbol(protein.id)
            end
        end
    end

    if enzmldoc.complexes !== nothing
        for complex in enzmldoc.complexes
            if !complex.constant
                vars[complex.id] = Symbol(complex.id)
            end
        end
    end

    return vars
end

"""
    _create_simulation_data(enzmldoc::EnzymeMLDocument, u0s::Vector) -> Vector

Create simulation data by solving the ODE system.
"""
function _create_simulation_data(enzmldoc::EnzymeMLDocument, u0s::Vector)
    try
        # Create ODE system
        sys, vars, params = @system(enzmldoc)
        p = extract_parameters(enzmldoc, params)

        # Determine time span from experimental data
        tspan = _get_time_span(enzmldoc)

        # Solve for each initial condition
        solutions = []
        for u0 in u0s
            prob = ODEProblem(sys, u0, tspan, p)
            sol = solve(prob, Tsit5())
            push!(solutions, (solution=sol, vars=vars))
        end

        return solutions
    catch e
        @warn "Failed to create simulation: $e"
        return nothing
    end
end

"""
    _get_time_span(enzmldoc::EnzymeMLDocument) -> Tuple{Float64,Float64}

Determine appropriate time span from experimental data.
"""
function _get_time_span(enzmldoc::EnzymeMLDocument)
    max_time = 0.0

    for measurement in enzmldoc.measurements
        if measurement.species_data !== nothing
            for species in measurement.species_data
                if species.time !== nothing && !isempty(species.time)
                    max_time = max(max_time, maximum(species.time))
                end
            end
        end
    end

    return (0.0, max_time > 0 ? max_time * 1.1 : 50.0)  # Add 10% buffer
end

"""
    _create_measurement_plots(measurements::Vector, obs_data::Vector, sim_data::Union{Vector,Nothing}) -> Plot

Create subplots for each measurement.
"""
function _create_measurement_plots(measurements::Vector, obs_data::Vector, sim_data::Union{Vector,Nothing})
    n_measurements = length(measurements)

    if n_measurements == 0
        return plot(title="No measurements found")
    end

    # Create individual plots
    plots_array = []

    for (i, measurement) in enumerate(measurements)
        measurement_plot = _plot_single_measurement(
            measurement,
            obs_data[i],
            sim_data !== nothing ? sim_data[i] : nothing
        )
        push!(plots_array, measurement_plot)
    end

    # Arrange in appropriate layout
    layout = _determine_layout(n_measurements)

    # Calculate width based on number of columns with legend space
    base_width_per_col = 400  # Increased base width to accommodate legends
    width = base_width_per_col * layout[2]
    height = 300 * layout[1]

    return plot(plots_array..., layout=layout, size=(width, height))
end

"""
    _plot_single_measurement(measurement, obs_data, sim_data) -> Plot

Plot data for a single measurement.
"""
function _plot_single_measurement(measurement, obs_data, sim_data)
    # Create plot with measurement name or ID as title
    title = measurement.name !== nothing ? measurement.name : measurement.id
    p = plot(title=title, xlabel="Time", ylabel="Concentration",
        legend=:outerright, legendfontsize=8, titlefontsize=10)

    # Get consistent colors for each species
    species_colors = _get_species_colors(obs_data)

    # Plot experimental data and simulation with matching colors
    _add_experimental_data!(p, obs_data, species_colors)

    # Plot simulation if available
    if sim_data !== nothing
        _add_simulation_data!(p, sim_data, obs_data, species_colors)
    end

    return p
end

"""
    _get_species_colors(obs_data) -> Dict{String,Int}

Get consistent color indices for each species.
"""
function _get_species_colors(obs_data)
    species_colors = Dict{String,Int}()
    color_index = 1

    for species_id in keys(obs_data.observables)
        species_colors[species_id] = color_index
        color_index += 1
    end

    return species_colors
end

"""
    _add_experimental_data!(p, obs_data, species_colors) -> Nothing

Add experimental data points to the plot with specified colors.
"""
function _add_experimental_data!(p, obs_data, species_colors)
    for (species_id, data) in obs_data.observables
        if haskey(obs_data.times, species_id)
            color_idx = species_colors[species_id]
            scatter!(p, obs_data.times[species_id], data,
                label="$species_id (data)", markersize=3, markerstrokewidth=0,
                color=color_idx)
        end
    end
end

"""
    _add_simulation_data!(p, sim_data, obs_data, species_colors) -> Nothing

Add simulation curves to the plot with matching colors.
"""
function _add_simulation_data!(p, sim_data, obs_data, species_colors)
    solution = sim_data.solution
    vars = sim_data.vars

    # Only plot species that have experimental data
    for species_id in keys(obs_data.observables)
        if haskey(vars, species_id)
            color_idx = species_colors[species_id]
            plot!(p, solution, idxs=vars[species_id],
                label="$species_id (model)", linewidth=2,
                color=color_idx)
        end
    end
end

"""
    _determine_layout(n_plots::Int) -> Tuple{Int,Int}

Determine optimal subplot layout based on number of plots.
"""
function _determine_layout(n_plots::Int)
    if n_plots == 1
        return (1, 1)
    elseif n_plots == 2
        return (1, 2)
    elseif n_plots <= 4
        return (2, 2)
    elseif n_plots <= 6
        return (2, 3)
    elseif n_plots <= 9
        return (3, 3)
    else
        # For larger numbers, create a roughly square layout
        rows = ceil(Int, sqrt(n_plots))
        cols = ceil(Int, n_plots / rows)
        return (rows, cols)
    end
end

export plot_enzymeml_document

end # module Visualize 