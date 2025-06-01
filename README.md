# EnzymeML.jl

<div align="center">

[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.1.0-orange)](Project.toml)
</div>

---

## 🧬 About

**EnzymeML.jl** is the Julia implementation of the EnzymeML data format, providing seamless interfaces to popular modeling packages including `DifferentialEquations.jl` and `ModelingToolkit.jl`. It enables researchers to easily extract ODE systems, initial conditions, and parameters from EnzymeML documents for advanced biochemical modeling and parameter estimation.

## ✨ Features

- 🔄 **Direct ODE System Creation**: Generate ODE systems directly from EnzymeML documents
- 📊 **Multi-measurement Support**: Handle multiple initial conditions from experimental data
- 🎯 **Parameter Extraction**: Automatically extract and manage model parameters
- 📈 **Visualization Ready**: Built-in plotting capabilities for results analysis
- 🌐 **EnzymeML Suite Integration**: Seamless integration with the EnzymeML Suite GUI
- ⚡ **High Performance**: Leverages Julia's speed for computational efficiency

## 📦 Installation

> **Note:** EnzymeML.jl is currently under development and not yet registered in the Julia package registry. You can install it by cloning the repository and adding it to your local Julia package environment.

```julia
using Pkg
Pkg.add("EnzymeML")
```

Or via the Julia REPL package manager:
```julia
] add EnzymeML
```

## 🚀 Quick Start

Here's a simple example to get you started:

```julia
using EnzymeML
using DifferentialEquations
using Plots

# Load an EnzymeML document
json_string = read("./test.json", String)
enzmldoc = JSON3.read(json_string, EnzymeMLDocument)

# Create the ODE system directly from the document
sys, vars, params = @system(enzmldoc)

# Extract initial conditions and parameters
u0s = extract_measurements(enzmldoc, vars)
p = extract_parameters(enzmldoc, params)

# Create and solve the ODE problem
tspan = (0.0, 200.0)
prob = ODEProblem(sys, first(u0s), tspan, p)
sol = solve(prob, Tsit5())

# Visualize results
plot(sol)
```

## 📚 Examples

Explore comprehensive examples demonstrating different aspects of EnzymeML.jl:

### 🔬 [ODE Systems](./examples/odes/)

Learn how to create and solve ordinary differential equations from EnzymeML documents.

- Load EnzymeML documents
- Create ODE systems from reactions
- Handle multiple initial conditions
- Parameter estimation and updating

### ⚗️ [Reaction Networks](./examples/reactions/)

Work with biochemical reaction networks using Catalyst.jl integration.

- Reaction system creation
- Multi-condition solving
- Results visualization
- Document updates

### 📊 [Visualization](./examples/visualize/)

Create publication-ready plots from your EnzymeML data.

- Data plotting
- Result visualization
- Export capabilities

### 🖥️ [EnzymeML Suite Integration](./examples/suite/)

Connect with the EnzymeML Suite for GUI-based document management.

- REST API integration
- Document synchronization
- Live parameter updates

## 🤝 Contributing

We welcome contributions! Please open an issue or pull request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [EnzymeML](https://github.com/EnzymeML/EnzymeML) - Python implementation
- [EnzymeML Suite](https://github.com/EnzymeML/enzymeml-suite) - GUI application
- [EnzymeML Specification](https://github.com/EnzymeML/enzymeml-specifications) - Data format specification

## 💬 Support

- 📧 **Email**: [jan.range@simtech.uni-stuttgart.de](mailto:jan.range@simtech.uni-stuttgart.de)
- 🐛 **Issues**: [GitHub Issues](https://github.com/EnzymeML/EnzymeML.jl/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/EnzymeML/EnzymeML.jl/discussions)

---

<div align="center">
<strong>Made with ❤️ by the EnzymeML Team</strong>
</div>
