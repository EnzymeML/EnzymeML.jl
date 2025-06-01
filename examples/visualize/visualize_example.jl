using EnzymeML

# Load the EnzymeML document with experimental data
enzmldoc = load_enzmldoc("./enzmldoc.json")

# Create visualization using the new Visualize module
# This will automatically:
# - Plot experimental data for each measurement
# - Check if model equations and parameters are available
# - If yes, overlay simulation curves
plot_obj = plot_enzymeml_document(enzmldoc)

# Display the plot
display(plot_obj)

# Save the plot
savefig(plot_obj, "visualize.png")