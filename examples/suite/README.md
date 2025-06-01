# EnzymeML Suite Example

The EnzymeML Suite is a graphical tool for managing EnzymeML documents and offers a local REST interface to fetch and update documents. This way, users can use the EnzymeML Suite to define an EnzymeML document and then use the EnzymeML.jl package to solve the ODEs or reactions defined in the document.

> **Note:** Before using this example, you need to have the EnzymeML Suite installed and running. You can download it from the [EnzymeML website](https://enzymeml.org/usage/) or the [GitHub repository](https://github.com/EnzymeML/enzymeml-suite).

## Overview

The `suite_example.jl` script shows how to:

1. Create a suite instance
2. Get the current document using method syntax
3. Create an ODE system from the document's reactions
4. Solve the ODE system for multiple initial conditions
5. Plot the results
6. Update the parameters in the document
7. Save the updated document

## Running the Example

To run this example:

1. Make sure you have EnzymeML.jl installed
2. Navigate to the examples/suite directory
3. Run the script with Julia:

```bash
julia suite_example.jl
```