# Bardo

![Bardo Logo](https://via.placeholder.com/150/0A0A0A/FFFFFF?text=Bardo)

Bardo is a powerful and approachable neuroevolution library for Elixir. It provides a complete toolkit for building, training and running neuroevolution systems that learn through evolutionary algorithms.

Built on a foundation of concurrent topology and parameter evolving neural networks (TWEANN), Bardo makes advanced neuroevolution techniques accessible while leveraging Elixir/OTP's built-in concurrency for highly efficient parallel training.

## Features

- **Topology and Parameter Evolving Neural Networks**: Evolve both the weights and structure of neural networks
- **Distributed and Concurrent**: Leverage the BEAM VM for parallel evolution and training
- **Sensor and Actuator Framework**: Easy integration with various environments
- **Ready-to-use Examples**: Including predator-prey simulations and control problems
- **Modular Design**: Easily extend with custom components and algorithms
- **Built-in Visualization**: Tools for monitoring evolutionary progress

## Installation

Add `bardo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:bardo, github: "username/bardo"}
  ]
end
```

## Quick Start

### Running the Simple XOR Example

The simplest way to get started with Bardo is to run the XOR example, which demonstrates how to evolve a neural network to solve the XOR problem:

```bash
# Clone the repository
git clone https://github.com/username/bardo.git
cd bardo

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run the XOR example
mix run -e "Bardo.Examples.Simple.Xor.run()"
```

This will evolve a population of neural networks over multiple generations and display the best solution's performance on the XOR problem.

### Setting Up Your Own Experiment

Once you're familiar with the XOR example, you can set up your own experiment with the full framework:

```elixir
# Create a new experiment
experiment = Bardo.ExperimentManager.new_experiment("my_first_experiment")

# Configure the experiment
Bardo.ExperimentManager.configure(experiment, %{
  population_size: 50,
  max_generations: 100,
  mutation_rate: 0.3
})

# Start the experiment with a fitness function
Bardo.ExperimentManager.start(experiment, &MyApp.FitnessFunctions.xor_fitness/1)

# Check progress
Bardo.ExperimentManager.status(experiment)

# Get the best solution
best_neural_network = Bardo.ExperimentManager.get_best_solution(experiment)
```

### Development Status

The library is currently under active development. The Simple XOR example is fully functional, while the more complex examples (DPB, Flatland, FX) may require additional implementation of framework components like `PolisMgr` and `Models` modules.

## Examples

Bardo includes several example applications and benchmarks:

### 1. Simple XOR

A simple demonstration of evolving a neural network to solve the XOR problem. This is a great starting point as it doesn't require the full machinery of the population and experiment managers.

```elixir
# Run with default settings (population size: 100, generations: 50)
mix run -e "Bardo.Examples.Simple.Xor.run()"

# Run with custom settings
mix run -e "Bardo.Examples.Simple.Xor.run(population_size: 50, max_generations: 100)"

# Run with verbose output to see progress of evolution
mix run -e "Bardo.Examples.Simple.Xor.run(population_size: 50, max_generations: 100, verbose: true)"
```

The XOR example demonstrates several key concepts:

1. **Creating a population of neural networks**: Each with a slightly different genotype (neural structure and weights)
2. **Fitness function**: Evaluating how well each neural network solves the XOR problem
3. **Evolution process**: Selection of the best networks, mutation to create offspring
4. **Visualization**: Displaying the progress of evolution and final results

Here's a simplified view of what happens in the XOR example:

```elixir
# 1. Create initial population of random genotypes
initial_population = create_initial_population(population_size)

# 2. Evolve the population through many generations
{best_genotype, best_fitness, generations} = evolve(
  initial_population, 
  max_generations
)

# 3. Convert the best genotype to a neural network
best_neural_network = Cortex.from_genotype(best_genotype)

# 4. Test the best neural network on all XOR inputs
display_xor_results(best_neural_network)
```

This example provides a template for creating your own self-contained neuroevolution experiments.

### 2. Double Pole Balancing

A classic control problem where a neural network learns to balance two poles of different lengths on a cart.

```elixir
# Run the double pole balancing example with damping
mix run -e "Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 100, 50)"

# Run without damping (more challenging)
mix run -e "Bardo.Examples.Benchmarks.Dpb.run_without_damping(:dpb_wo_damping_example, 100, 50)"
```

### 3. Flatland Predator-Prey Simulation

A more complex simulation where predator and prey agents co-evolve in a 2D world.

```elixir
# Run with default settings
mix run -e "Bardo.Examples.Applications.Flatland.run(:flatland_example)"

# Run with custom settings (predator population, prey population, plants, steps, generations)
mix run -e "Bardo.Examples.Applications.Flatland.run(:flatland_example, 20, 20, 40, 1000, 50)"
```

### 4. Forex (FX) Trading

Evolves a trading strategy for foreign exchange markets using historical price data.

```elixir
# Run with default settings
mix run -e "Bardo.Examples.Applications.Fx.run(:fx_example)"

# Run with custom settings (population size, data window, generations)
mix run -e "Bardo.Examples.Applications.Fx.run(:fx_example, 50, 5000, 50)"
```

See the [examples documentation](docs/examples.md) for more details on these examples, their configurations, and what to expect when running them.

### Troubleshooting Common Issues

When running the examples, you might encounter some issues:

1. **Undefined module errors**: The more complex examples require modules like `PolisMgr` or `Models` that may not be fully implemented yet. Use the Simple XOR example while the library is under development.

2. **Function name conflicts**: If you see errors about function naming conflicts, check for duplicate function names in the modules. An example fix might be renaming functions with distinct names.

3. **Missing behavior callbacks**: Some modules may implement behaviours but not define all required callbacks. Add missing callback implementations to fix these errors.

4. **Warnings about unused variables**: Add underscores to variable names that are intentionally unused (e.g., `_unused_var`).

**Note on Complex Examples**: The Double Pole Balancing, Flatland, and FX examples require the full machinery of the Bardo framework, including the population manager, experiment manager, and other components. If you're getting errors with these examples, stick with the Simple XOR example instead, which is self-contained and doesn't depend on the full framework.

## Core Concepts

Bardo is built around these key components:

### Genotype

The genetic representation of a neural network, used for evolution and mutation.

```elixir
# Create a new genotype
genotype = Bardo.PopulationManager.Genotype.new()

# Add a new neuron
genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :hidden)

# Mutate the genotype
mutated_genotype = Bardo.PopulationManager.GenomeMutator.mutate(genotype)
```

### Phenotype (Neural Network)

The functional neural network created from a genotype.

```elixir
# Create a neural network from a genotype
nn = Bardo.AgentManager.Cortex.from_genotype(genotype)

# Activate the neural network with inputs
output = Bardo.AgentManager.Cortex.activate(nn, [1.0, 0.0])
```

### Sensors and Actuators

Interface between neural networks and their environment.

```elixir
# Add a sensor to a neural network
nn = Bardo.AgentManager.Cortex.add_sensor(nn, MyApp.Sensors.Vision)

# Add an actuator to a neural network
nn = Bardo.AgentManager.Cortex.add_actuator(nn, MyApp.Actuators.Motor)
```

## Architecture

Bardo is organized into several key managers:

- **ExperimentManager**: Controls the overall experiment process
- **PopulationManager**: Handles populations of evolving agents
- **AgentManager**: Manages the neural networks and their interactions
- **ScapeManager**: Provides environments for agents to operate in

## Advanced Usage

See our [advanced guide](docs/advanced.md) for topics including:

- Custom fitness functions
- Specialized sensor and actuator development  
- Distributed training across multiple nodes
- Custom mutation operators

## Testing

Bardo includes both ExUnit tests and example applications for validation:

```bash
# Run the unit tests
mix test

# Run specific tests
mix test test/bardo/population_manager/genotype_test.exs

# Run the XOR example (functional test)
mix run -e "Bardo.Examples.Simple.Xor.run(verbose: true)"
```

The XOR example can be used to verify that the core components of the library are working correctly, as it demonstrates a complete neuroevolution process from initialization to evaluation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

When contributing, please:

- Add tests for new features
- Ensure all tests pass
- Update documentation as needed
- Follow existing code style and patterns

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgements

- Based on concepts from the [Handbook of Neuroevolution Through Erlang](http://www.amazon.com/Handbook-Neuroevolution-Through-Erlang-Gene/dp/1461444624) by Gene Sher
- Inspired by DXNN and other TWEANN systems