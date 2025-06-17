# Reactions Example

This example demonstrates how to use EnzymeML.jl to create and solve reaction systems from an EnzymeML document.

## Overview

The `reaction_example.jl` script shows how to:

1. Load an EnzymeML document
2. Create a reaction system from the document's reactions
3. Extract initial conditions from measurements
4. Extract parameters from the document
5. Solve the reaction system for multiple initial conditions
6. Visualize the results
7. Update parameters in the document
8. Save the updated document

## Running the Example

To run this example:

1. Make sure you have EnzymeML.jl installed
2. Navigate to the examples/odes directory
3. Run the script with Julia:

```bash
julia reaction_example.jl
```
