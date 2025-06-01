using EnzymeML
using DifferentialEquations
using Plots

# Parse JSON into a mutable struct
enzmldoc = load_enzmldoc("./reactions_example.json")

# Create the ODE system directly from the document
sys, species, params = @reaction_system(enzmldoc)

# Extract the initial conditions and observable data for each measurement
# extract_measurements returns (initial_values, data)
# where data contains time series data for parameter fitting
initial_values, data = extract_measurements(enzmldoc, species)
p = extract_parameters(enzmldoc, params)

# Define the time span
tspan = (0.0, 20.0)

# Create the base ODEProblem
prob = ODEProblem(sys, first(initial_values), tspan, p)

# Formulate a prob_func for usage in an EnsembleProblem
prob_func = @prob_func(prob, initial_values)

# Create an EnsembleProblem
ensemble_prob = EnsembleProblem(prob, prob_func=prob_func)

# Solve the EnsembleProblem
ensemble_sol = solve(ensemble_prob, Tsit5(), EnsembleThreads(), trajectories=length(initial_values))

# Plot the results
plot(ensemble_sol[1], idxs=[species["substrate"], species["product"]],
    title="Enzymatic Reaction", xlabel="Time [s]", ylabel="Concentration [mmol/l]",
    labels=["Substrate" "Product"])

# Save the plot
savefig("reactions.png")

# Write the parameters to the enzymeml document
# Assume we have fitted the document to the data
update_parameters(enzmldoc, p)

# Write the document to a file and save the new document
save_enzmldoc(enzmldoc, "reactions_updated.json")