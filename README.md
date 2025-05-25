# Bardo

## About

Bardo is a focused neuroevolution library for Elixir that evolves neural networks through evolutionary algorithms. Built on the Erlang VM, it leverages concurrent processes for efficient neural network simulation and evolution.

## Features

- **Topology and Parameter Evolving Neural Networks (TWEANN)**: Neural networks evolve their structure and weights over time
- **Efficient ETS-based Storage**: Simple and fast in-memory storage with periodic backups
- **Modular Sensor/Actuator Framework**: Easily connect networks to different environments
- **Built-in Evolutionary Algorithms**: Includes selection algorithms and mutation operators
- **Substrate Encoding**: Hypercube-based encoding for efficient pattern recognition
- **Example Environments**: XOR, Double Pole Balancing, Flatland, and Simple FX simulations

## Installation

Add `bardo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

Then run:

```shell
mix deps.get
```

Start the Bardo processes in your application's supervision tree or startup code:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # ...your other children
    {Bardo, []}
  ]

  Supervisor.start_link(children, strategy: :one_for_one)
end
```

Or start it manually in your code:

```elixir
Bardo.start()
```

## Documentation

Comprehensive documentation is available:

- [Quick Start Guide](docs/quickstart.md) - Get up and running quickly
- [Library Tutorial](docs/library_tutorial.md) - Using Bardo in your own applications
- [API Reference](docs/api_reference.md) - Detailed API documentation
- [Examples](docs/examples.md) - Example usages
- [Extending Bardo](docs/extending.md) - Creating custom components
- [Advanced Topics](docs/advanced.md) - Advanced features and techniques

## Quick Start

### XOR Example

The simplest way to get started is to run the XOR example:

```elixir
# Start IEx with Bardo
iex -S mix

# Run the XOR example
iex> Bardo.Examples.Simple.Xor.run()
```

### Creating Your Own Experiment

To set up your own neuroevolution experiment:

```elixir
# Create a new experiment
experiment = Bardo.ExperimentManager.new_experiment("my_experiment")

# Configure it
Bardo.ExperimentManager.configure(experiment, %{
  population_size: 100,
  max_generations: 200,
  mutation_rate: 0.3
})

# Define a fitness function
defmodule MyFitness do
  def evaluate(agent) do
    # Your fitness calculation here
    # Returns a numeric score
  end
end

# Start the experiment with your fitness function
Bardo.ExperimentManager.start(experiment, &MyFitness.evaluate/1)

# Check progress
Bardo.ExperimentManager.status(experiment)

# Get the best solution
best_agent = Bardo.ExperimentManager.get_best_solution(experiment)
```

## Core Examples

Bardo includes several examples to demonstrate different aspects of neuroevolution:

### 1. XOR

A simple example that evolves a neural network to solve the XOR problem.

```elixir
Bardo.Examples.Simple.Xor.run(population_size: 100, max_generations: 50)
```

### 2. Double Pole Balancing

A classic control problem where a neural network learns to balance two poles on a cart.

```elixir
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 50, 20, 10000)
```

### 3. Flatland

A predator-prey simulation in a 2D world where agents co-evolve.

```elixir
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example, 10, 10, 20, 500, 10)
```

### 4. Simple FX

A basic forex trading simulation to demonstrate time series prediction.

```elixir
# Standard FX example
iex> Bardo.Examples.Applications.Fx.run(:fx_example, 50, 1000, 20)
```

## Core Concepts

### Genotypes

Genetic representations of neural networks:

```elixir
# Create a new genotype
genotype = Bardo.PopulationManager.Genotype.new()

# Add neurons
genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :hidden)

# Add connections between neurons
genotype = Bardo.PopulationManager.Genotype.add_connection(genotype, input_id, output_id, weight)

# Mutate the genotype
mutated_genotype = Bardo.PopulationManager.GenomeMutator.mutate(genotype)
```

### Neural Networks

Working with the neural networks created from genotypes:

```elixir
# Convert genotype to neural network
nn = Bardo.AgentManager.Cortex.from_genotype(genotype)

# Activate the network with inputs
outputs = Bardo.AgentManager.Cortex.activate(nn, [1.0, 0.0])
```

### Sensors and Actuators

Interface between neural networks and their environment:

```elixir
# Add a sensor to a neural network
nn = Bardo.AgentManager.Cortex.add_sensor(nn, MyApp.Sensors.Vision)

# Add an actuator to a neural network
nn = Bardo.AgentManager.Cortex.add_actuator(nn, MyApp.Actuators.Motor)
```

## Architecture

Bardo is organized into several key modules:

- **ExperimentManager**: Controls the overall experiment process
- **PopulationManager**: Handles populations of evolving agents
- **AgentManager**: Manages the neural networks and their interactions
- **ScapeManager**: Provides environments for agents to operate in

## Custom Environments

To create your own environment, you'll need to define custom sensors and actuators:

```elixir
defmodule MyEnvironment.Sensor do
  @behaviour Bardo.AgentManager.Sensor

  # Implementation of the Sensor behaviour
  def sense(state) do
    # Convert environment state to neural network inputs
  end
end

defmodule MyEnvironment.Actuator do
  @behaviour Bardo.AgentManager.Actuator

  # Implementation of the Actuator behaviour
  def act(outputs, state) do
    # Convert neural network outputs to actions
    # Return updated state
  end
end
```

Then create a morphology that defines the neural network structure:

```elixir
defmodule MyEnvironment.Morphology do
  @behaviour Bardo.Morphology

  # Implementation of the Morphology behaviour
  def sensor_spec do
    # Define sensor inputs
  end

  def actuator_spec do
    # Define actuator outputs
  end
end
```

## Testing

To run the tests:

```bash
mix test
```

## License

Distributed under the Apache License 2.0. See `LICENSE` for more information.

## Acknowledgements

This is a vibe coded port of this project: [github - Rober-t/apxr_run](https://github.com/Rober-t/apxr_run)

Which was based on this code: [Gene Sher - DXNN2](https://github.com/CorticalComputer/DXNN2)

Based on concepts from this amazing book: [Handbook of Neuroevolution Through Erlang](http://www.amazon.com/Handbook-Neuroevolution-Through-Erlang-Gene/dp/1461444624) by Gene Sher.

## DISLAIMER

Please use at your own risk as this is experimental and awaiting contributions and code review.
