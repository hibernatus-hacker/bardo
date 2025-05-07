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

### Setting Up a Simple Experiment

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

## Examples

Bardo includes several example applications and benchmarks:

### 1. Double Pole Balancing

A classic control problem where a neural network learns to balance two poles of different lengths on a cart.

```elixir
# Run the double pole balancing example
Bardo.Examples.Benchmarks.Dpb.run()
```

### 2. Flatland Predator-Prey Simulation

A more complex simulation where predator and prey agents co-evolve in a 2D world.

```elixir
# Run the flatland simulation
Bardo.Examples.Applications.Flatland.run()
```

See the [examples documentation](docs/examples.md) for more details.

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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgements

- Based on concepts from the [Handbook of Neuroevolution Through Erlang](http://www.amazon.com/Handbook-Neuroevolution-Through-Erlang-Gene/dp/1461444624) by Gene Sher
- Inspired by DXNN and other TWEANN systems