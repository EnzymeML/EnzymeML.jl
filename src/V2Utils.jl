module V2Utils

using ..EnzymemlV2: EnzymeMLDocument
using Symbolics
using JSON3

"""
    load_enzmldoc(path::String)

Load an EnzymeML document from a file.

# Arguments
- `path::String`: The path to the EnzymeML document.

# Returns
- An EnzymeMLDocument.
"""
function load_enzmldoc(path::String)
    json_string = read(path, String)
    return JSON3.read(json_string, EnzymeMLDocument)
end

"""
    save_enzmldoc(enzmldoc::EnzymeMLDocument, path::String)

Save an EnzymeML document to a file.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to save.
- `path::String`: The path to save the EnzymeML document to.
"""
function save_enzmldoc(enzmldoc::EnzymeMLDocument, path::String)
    open(path, "w") do f
        JSON3.pretty(f, enzmldoc)
    end
end

"""
    update_parameters(enzmldoc::EnzymeMLDocument, params::Dict{Symbolics.Num,Float64})

Update the parameters in the EnzymeML document.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to update.
- `params::Dict{Symbolics.Num,Float64}`: A dictionary of parameter names and their corresponding values.
"""
function update_parameters(enzmldoc::EnzymeMLDocument, params::Dict{Symbolics.Num,Float64})
    # Create a reverse mapping from parameter symbols to parameter objects
    param_symbol_map = Dict{String,Symbolics.Num}()
    for (symbol_key, value) in params
        param_symbol_map[string(symbol_key)] = symbol_key
    end

    for parameter in enzmldoc.parameters
        # Check if this parameter's symbol matches any in the params dict
        if parameter.symbol in keys(param_symbol_map)
            parameter.value = params[param_symbol_map[parameter.symbol]]
        end
    end
end

"""
    get_initial_values(enzmldoc::EnzymeMLDocument, m_id::String, vars::Dict{String,Symbol})

Get the initial values for a given measurement ID.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to get the initial values from.
- `m_id::String`: The ID of the measurement to get the initial values from.
- `vars::Dict{String,Symbol}`: A dictionary of variable names and their corresponding symbols.

# Returns
- A tuple with:
  - First element: Dictionary of variable symbols and their initial values (backward compatible)
  - Second element: NamedTuple with `observables` (species_id -> data) and `times` (species_id -> time)
"""
function extract_measurement(enzmldoc::EnzymeMLDocument, id::String, vars::Dict{String,Symbol})
    initial_values = Dict{Symbol,Float64}()
    observables = Dict{String,Vector{Float64}}()
    times = Dict{String,Vector{Float64}}()

    for measurement in enzmldoc.measurements
        if measurement.id == id
            for species in measurement.species_data
                species_id = species.species_id

                # Extract initial values
                if species.initial !== nothing
                    initial_values[vars[species_id]] = species.initial
                end

                # Extract observable data (time series)
                if species.data !== nothing && species.time !== nothing
                    observables[species_id] = species.data
                    times[species_id] = species.time
                end
            end
        end
    end

    return initial_values, (observables=observables, times=times)
end

export extract_measurement

"""
    extract_observable_data(enzmldoc::EnzymeMLDocument, species_id::String)

Extract only the observable time series data for a specific species across all measurements.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to extract data from.
- `species_id::String`: The species ID to extract data for.

# Returns
- Dictionary mapping measurement IDs to NamedTuples with `data` and `time` vectors
"""
function extract_observable_data(enzmldoc::EnzymeMLDocument, species_id::String)
    observable_data = Dict{String,NamedTuple{(:data, :time),Tuple{Vector{Float64},Vector{Float64}}}}()

    for measurement in enzmldoc.measurements
        for species in measurement.species_data
            if species.species_id == species_id && species.data !== nothing && species.time !== nothing
                observable_data[measurement.id] = (data=species.data, time=species.time)
            end
        end
    end

    return observable_data
end

"""
    has_observable_data(enzmldoc::EnzymeMLDocument, species_id::String)

Check if a species has observable time series data in any measurement.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to check.
- `species_id::String`: The species ID to check for observable data.

# Returns
- Boolean indicating whether the species has observable data
"""
function has_observable_data(enzmldoc::EnzymeMLDocument, species_id::String)
    for measurement in enzmldoc.measurements
        for species in measurement.species_data
            if species.species_id == species_id && species.data !== nothing && species.time !== nothing
                return true
            end
        end
    end
    return false
end

"""
    extract_measurements(enzmldoc::EnzymeMLDocument, symbols::Dict{String,Symbol})

Extract all measurements from the EnzymeML document.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to extract measurements from.
- `symbols::Dict{String,Symbol}`: A dictionary of variable names and their corresponding symbols.

# Returns
- A tuple with:
  - First element: Vector of dictionaries, each containing the initial values for a measurement (backward compatible)
  - Second element: Vector of NamedTuples, each containing `observables` and `times` for a measurement
"""
function extract_measurements(enzmldoc::EnzymeMLDocument, symbols::Dict{String,Symbol})
    initial_values_list = []
    observables_list = []

    for measurement in enzmldoc.measurements
        initial_values, observables_data = extract_measurement(enzmldoc, measurement.id, symbols)
        push!(initial_values_list, initial_values)
        push!(observables_list, observables_data)
    end

    return initial_values_list, observables_list
end

"""
    extract_parameters(enzmldoc::EnzymeMLDocument, symbols::Dict{String,Symbol}, initials::Bool=false)

Extract all parameters from the EnzymeML document.

# Arguments
- `enzmldoc::EnzymeMLDocument`: The EnzymeML document to extract parameters from.
- `symbols::Dict{String,Symbol}`: A dictionary of parameter names and their corresponding symbols.
- `initials::Bool=false`: Whether to extract the initial values or the values.

# Returns
- A dictionary of parameter names and their corresponding parameters.
"""
function extract_parameters(enzmldoc::EnzymeMLDocument, symbols::Dict{String,Symbolics.Num}, initials::Bool=false)
    parameters = Dict{Symbolics.Num,Float64}()
    for parameter in enzmldoc.parameters
        if initials
            if parameter.initial !== nothing
                parameters[symbols[parameter.symbol]] = parameter.initial
            end
        else
            if parameter.value !== nothing
                parameters[symbols[parameter.symbol]] = parameter.value
            end
        end
    end
    return parameters
end

export extract_measurements, extract_measurement, extract_parameters
export load_enzmldoc, save_enzmldoc, update_parameters
export extract_observable_data, has_observable_data

end # module V2Utils

