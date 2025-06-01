module EnzymeML

# Include the submodules in correct dependency order
include("V2.jl")
include("System.jl")
include("ReactionNetwork.jl")
include("V2Utils.jl")
include("Visualize.jl")
include("Suite.jl")

# Re-export commonly used third-party packages
using DifferentialEquations
using Symbolics
using Catalyst
using ModelingToolkit
using Plots
using JSON3

using .EnzymemlV2
using .EnzymeMLSystem
using .ReactionNetwork
using .V2Utils
using .Visualize
using .Suite

# Export third-party packages
export DifferentialEquations, Symbolics, ModelingToolkit, Plots, JSON3, Catalyst

# Export commonly used Plots functions for convenience
export savefig, plot, plot!, scatter, scatter!, display

# Export our submodules and functions
export enzymeml_v2
export @system, @prob_func
export @reaction_system, extract_species_from_reactions, build_reaction_side, format_stoichiometry
export extract_measurements, extract_measurement, extract_parameters
export load_enzmldoc, save_enzmldoc, update_parameters
export extract_observable_data, has_observable_data
export plot_enzymeml_document

# Export the EnzymeMLDocument type
export EnzymeMLDocument

# Export the Suite functionality
export EnzymeMLSuite

end # module EnzymeML