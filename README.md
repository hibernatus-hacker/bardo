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

The library has been updated to support running all examples. The simple XOR example is a good starting point, but the more complex examples (DPB, Flatland, FX) are now fully functional as well, providing more advanced neuroevolution scenarios.

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
# Parameters: experiment_id, population_size, generations, max_steps
iex -S mix
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 20, 10, 10000)

# For a longer run with more agents
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 100, 50, 100000)

# Run without damping (more challenging)
iex> Bardo.Examples.Benchmarks.Dpb.run_without_damping(:dpb_wo_damping_example, 20, 10, 10000)
```

### 3. Flatland Predator-Prey Simulation

A more complex simulation where predator and prey agents co-evolve in a 2D world.

```elixir
# Run with small populations for quick testing
# Parameters: experiment_id, predator_population, prey_population, plant_quantity, simulation_steps, generations
iex -S mix
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example, 5, 5, 20, 500, 5)

# Run with default settings
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example)

# Run with custom settings for a more complex simulation
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example, 20, 20, 40, 1000, 50)
```

### 4. Forex (FX) Trading

Evolves a trading strategy for foreign exchange markets using historical price data. This example demonstrates how neuroevolution can be applied to financial market forecasting and trading strategy development.

```elixir
# Run with small parameters for quick testing
# Parameters: experiment_id, population_size, data_window, generations
iex -S mix
iex> Bardo.Examples.Applications.Fx.run(:fx_example, 5, 500, 5)

# Run with default settings
iex> Bardo.Examples.Applications.Fx.run(:fx_example)

# Run with custom settings for a more thorough exploration
iex> Bardo.Examples.Applications.Fx.run(:fx_example, 50, 5000, 50)

# After running an experiment, you can test the best agent on out-of-sample data
iex> Bardo.Examples.Applications.Fx.test_best_agent(:fx_example)
```

The FX example:
- Uses EUR/USD forex historical data (located in priv/fx_tables/)
- Evolves neural networks that take price patterns as input and produce trading signals
- Evaluates agents based on trading performance metrics (profit/loss, win rate, drawdown)
- Provides a backtesting function to evaluate the best agent on out-of-sample data

When you run this example, you'll see detailed output including:
- Experiment configuration (population size, data window, generations)
- Progress indicators as the evolution runs
- Detailed test results showing trading metrics when you run test_best_agent

This example is particularly interesting for those interested in applying machine learning to financial markets, as it demonstrates how neuroevolution can discover non-linear patterns in time series data.

See the [examples documentation](docs/examples.md) for more details on these examples, their configurations, and what to expect when running them.

### Troubleshooting Common Issues

When running the examples, you might encounter some issues:

1. **Warning messages during compilation**: There are several warnings about unused variables and implementation conflicts that you can safely ignore. These are planned to be addressed in future versions but don't affect the functionality of the examples.

2. **Recommend using IEx**: We recommend running the examples within an interactive Elixir shell (`iex -S mix`) rather than using `mix run -e`. This allows you to examine the state of the system during and after the experiments.

3. **Start with small parameters**: The examples can be resource-intensive with large populations or many generations. Start with the small parameter sets we provide and increase them as needed.

4. **Memory usage**: For very long runs, be aware of memory usage, as the system stores information about all agents throughout evolution.

5. **Understanding the output**: All examples now provide detailed output at each stage:
   - At startup: Configuration details and experiment parameters
   - During execution: Progress indicators in the logs
   - After completion: Summary of results and performance metrics
   - Follow-up testing: Each example has test functions with detailed output

**Note on Complex Examples**: 
- All examples (DPB, Flatland, and FX) are now fully functional with enhanced user feedback.
- They showcase different aspects of the neuroevolution framework:
  - DPB: Control problem with continuous state and action spaces
  - Flatland: Multi-agent co-evolution in a 2D environment
  - FX: Time series prediction and decision making

Begin with the examples with reduced parameters to verify functionality before attempting longer evolutionary runs. For example:

```elixir
# Quick test runs (will complete in minutes)
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_test, 5, 3, 1000)
iex> Bardo.Examples.Applications.Flatland.run(:flatland_test, 5, 5, 10, 100, 3)
iex> Bardo.Examples.Applications.Fx.run(:fx_test, 5, 500, 3)
```

After the evolution completes, don't forget to try the testing/visualization functions:
```elixir
# Test the evolved agents
iex> Bardo.Examples.Benchmarks.Dpb.test_best_solution(:dpb_test)
iex> Bardo.Examples.Applications.Flatland.visualize(:flatland_test)
iex> Bardo.Examples.Applications.Fx.test_best_agent(:fx_test)
```

### Key Implementation Modules

The following modules have been implemented or enhanced to enable the complex examples:

1. **Bardo.PolisMgr**: A facade for the Polis.Manager module, providing a simplified interface for setting up and running experiments.

2. **Bardo.PopulationManager.ExtendedMorphology**: A behavior that extends the basic Morphology behavior with additional callbacks needed for complex examples.

3. **Bardo.Models**: Extended with additional functions for data persistence, including `read/2`, `write/3`, `delete/2`, and `exists?/2`.

4. **Bardo.DB**: Enhanced with a `backup/0` function to support experiment persistence.

5. **Example-specific modules**: Each example (DPB, Flatland, FX) has dedicated sensor, actuator, and morphology modules that implement the required behaviors.

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