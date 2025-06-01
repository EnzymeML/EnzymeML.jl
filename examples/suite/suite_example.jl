using EnzymeML

# Create a suite instance
suite = EnzymeMLSuite()

# Get the current document using method syntax
enzmldoc = suite.get_current()

# Create the ODE system directly from the document
sys, species, params = @reaction_system(enzmldoc)

# Extract the initial conditions for each measurement
u0s = extract_measurements(enzmldoc, species)
p = extract_parameters(enzmldoc, params)

# Define the time span
tspan = (0.0, 20.0)

# Create the base ODEProblem
prob = ODEProblem(sys, first(u0s), tspan, p)

# Formulate a prob_func for usage in an EnsembleProblem
prob_func = @prob_func(prob, u0s)

# Create an EnsembleProblem
ensemble_prob = EnsembleProblem(prob, prob_func=prob_func)

# Solve the EnsembleProblem
ensemble_sol = solve(ensemble_prob, Tsit5(), EnsembleThreads(), trajectories=length(u0s))

# Plot the results
p1 = plot(ensemble_sol[1], idxs=[vars["substrate"], vars["product"]],
    title="Condition 1", xlabel="Time [mins]", ylabel="Concentration [mmol/l]")
p2 = plot(ensemble_sol[2], idxs=[vars["substrate"], vars["product"]],
    title="Condition 2", xlabel="Time [mins]", ylabel="Concentration [mmol/l]")

plot(p1, p2, layout=(1, 2))

# Write the parameters to the enzymeml document
# Assume we have fitted the document to the data
update_parameters(enzmldoc, p)

# Write the document back to the suite
suite.update_current(enzmldoc)


