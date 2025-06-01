using EnzymeML
using DifferentialEquations
using Plots

enzmldoc = load_enzmldoc("./ode_example.json")

# Create the ODE system directly from the document
sys, vars, params = @system(enzmldoc)

# Extract the initial conditions and observable data for each measurement
# extract_measurements returns (initial_values, data)
# where data contains time series data for parameter fitting
initial_values, data = extract_measurements(enzmldoc, vars)
p = extract_parameters(enzmldoc, params)

# Define the time span
tspan = (0.0, 200.0)

# Create the base ODEProblem
prob = ODEProblem(sys, first(initial_values), tspan, p)

# Formulate a prob_func for usage in an EnsembleProblem
prob_func = @prob_func(prob, initial_values)

# Create an EnsembleProblem
ensemble_prob = EnsembleProblem(prob, prob_func=prob_func)

# Solve the EnsembleProblem
ensemble_sol = solve(ensemble_prob, Tsit5(), EnsembleThreads(), trajectories=length(initial_values))

# Plot the results
p1 = plot(ensemble_sol[1], idxs=[vars["substrate"], vars["product"]],
    title="Condition 1", xlabel="Time [mins]", ylabel="Concentration [mmol/l]")
p2 = plot(ensemble_sol[2], idxs=[vars["substrate"], vars["product"]],
    title="Condition 2", xlabel="Time [mins]", ylabel="Concentration [mmol/l]")

plot(p1, p2, layout=(1, 2))

# Write the parameters to the enzymeml document
# Assume we have fitted the document to the data
update_parameters(enzmldoc, p)

# Write the document to a file and save the new document
save_enzmldoc(enzmldoc, "odes_updated.json")

# Save the plot
savefig("odes.png")