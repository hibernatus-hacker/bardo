# Bardo API Reference

This document provides comprehensive details on the main public interfaces of Bardo, a neuroevolution library for Elixir. Use this as your primary reference when integrating Bardo into your own applications.

## Getting Started

To use Bardo in your project, add it to your mix.exs dependencies:

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

## Bardo

The main module provides basic library information and startup functions.

```elixir
# Start all required Bardo processes
Bardo.start()

# Returns the current library version
Bardo.version()
```

## ExperimentManager

The `Bardo.ExperimentManager` module handles the creation and management of evolutionary experiments.

### Creating and Configuring Experiments

```elixir
# Create a new experiment
{:ok, _} = Bardo.ExperimentManager.new_experiment(experiment_id)

# Configure an experiment with specific parameters
:ok = Bardo.ExperimentManager.configure(experiment_id, %{
  population_size: 100,
  max_generations: 50,
  mutation_rate: 0.3
})

# Start evaluation using a fitness function
:ok = Bardo.ExperimentManager.start_evaluation(experiment_id, &my_fitness_function/1)

# Get the current status of an experiment
{:in_progress, stats} = Bardo.ExperimentManager.status(experiment_id)

# Get the best solution from an experiment
{:ok, best_genotype} = Bardo.ExperimentManager.get_best_solution(experiment_id)

# Stop an experiment
:ok = Bardo.ExperimentManager.stop(experiment_id)
```

### Common Configuration Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `population_size` | integer | Number of agents in the population | 50 |
| `max_generations` | integer | Maximum number of generations | 100 |
| `mutation_rate` | float | Probability of mutation for each gene | 0.3 |
| `add_neuron_probability` | float | Probability of adding a neuron | 0.1 |
| `add_link_probability` | float | Probability of adding a link | 0.2 |
| `weight_range` | {float, float} | Min/max values for weight initialization | {-1.0, 1.0} |
| `fitness_goal` | float | Target fitness to end evolution | nil (run to max_generations) |
| `species_distance_threshold` | float | Threshold for speciation | 0.5 |
| `activation_function` | atom | Default activation function | :sigmoid |
| `evaluation_method` | atom | :generational or :steady_state | :generational |

## AgentManager

The `Bardo.AgentManager` module manages neural network agents.

### Creating and Working with Neural Networks

```elixir
# Create a neural network from a genotype
nn = Bardo.AgentManager.Cortex.from_genotype(genotype)

# Activate a neural network with inputs
output = Bardo.AgentManager.Cortex.activate(nn, inputs)

# Add a sensor to a neural network
nn = Bardo.AgentManager.Cortex.add_sensor(nn, sensor_module, params)

# Add an actuator to a neural network
nn = Bardo.AgentManager.Cortex.add_actuator(nn, actuator_module, params)
```

### Neuron Management

```elixir
# Add a neuron to a neural network
nn = Bardo.AgentManager.Cortex.add_neuron(nn, :hidden, %{
  activation_function: :sigmoid,
  bias: 0.0
})

# Connect neurons
nn = Bardo.AgentManager.Cortex.connect_neurons(nn, source_id, target_id, weight)

# Set neuron parameters
nn = Bardo.AgentManager.Cortex.set_neuron_params(nn, neuron_id, %{
  bias: 1.0,
  activation_function: :tanh
})
```

## PopulationManager

The `Bardo.PopulationManager` module manages populations of evolving agents.

### Genotype Management

```elixir
# Create a new genotype
genotype = Bardo.PopulationManager.Genotype.new()

# Add a neuron to a genotype
genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :hidden)

# Add a connection to a genotype
genotype = Bardo.PopulationManager.Genotype.add_connection(
  genotype, 
  source_id, 
  target_id, 
  weight
)
```

### Mutation Operations

```elixir
# Mutate a genotype
mutated_genotype = Bardo.PopulationManager.GenomeMutator.mutate(genotype, %{
  add_neuron_probability: 0.1,
  add_link_probability: 0.2,
  mutate_weights_probability: 0.8
})

# Apply specific mutation
genotype = Bardo.PopulationManager.GenomeMutator.mutate_weights(genotype)
genotype = Bardo.PopulationManager.GenomeMutator.add_neuron(genotype)
genotype = Bardo.PopulationManager.GenomeMutator.add_link(genotype)
```

### Selection Algorithms

```elixir
# Select agents for reproduction
selected = Bardo.PopulationManager.SelectionAlgorithm.select(
  population, 
  selection_method, 
  selection_params
)
```

## ScapeManager

The `Bardo.ScapeManager` module manages environments that agents interact with.

```elixir
# Create a new scape
{:ok, scape_id} = Bardo.ScapeManager.new_scape(scape_type, params)

# Enter an agent into a scape
:ok = Bardo.ScapeManager.enter(scape_id, agent_id, params)

# Sense from the environment
{:ok, sensory_data} = Bardo.ScapeManager.sense(scape_id, agent_id, sensor_params)

# Act on the environment
:ok = Bardo.ScapeManager.actuate(scape_id, agent_id, actuator_params)

# Leave a scape
:ok = Bardo.ScapeManager.leave(scape_id, agent_id)
```

## Creating Custom Components

### Custom Sensor

```elixir
defmodule MySensor do
  @behaviour Bardo.AgentManager.Sensor
  
  @impl true
  def init(params) do
    # Initialize sensor state
    {:ok, params}
  end
  
  @impl true
  def sense(state, environment) do
    # Process environment to produce sensory signals
    sensory_data = process_environment(environment)
    
    # Return sensory data and updated state
    {:ok, sensory_data, state}
  end
  
  defp process_environment(environment) do
    # Custom logic to extract sensory information
    # ...
    [0.5, 0.2, 0.7]  # Example return value
  end
end
```

### Custom Actuator

```elixir
defmodule MyActuator do
  @behaviour Bardo.AgentManager.Actuator
  
  @impl true
  def init(params) do
    # Initialize actuator state
    {:ok, params}
  end
  
  @impl true
  def actuate(state, environment, output_vector) do
    # Process neural network output to affect environment
    new_environment = apply_outputs(environment, output_vector)
    
    # Return updated environment and state
    {:ok, new_environment, state}
  end
  
  defp apply_outputs(environment, output_vector) do
    # Custom logic to apply neural outputs to environment
    # ...
    updated_environment
  end
end
```

### Custom Fitness Function

```elixir
def my_fitness_function(genotype) do
  # Convert genotype to neural network
  nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
  
  # Evaluate performance on some task
  performance = evaluate_performance(nn)
  
  # Return fitness score (higher is better)
  performance
end

defp evaluate_performance(nn) do
  # Custom evaluation logic
  # ...
  fitness_score
end
```

## Substrate Encoding

Bardo supports several types of substrate encoding for neural networks:

```elixir
# Configure hypercube substrate encoding
Bardo.ExperimentManager.configure(experiment_id, %{
  substrate: %{
    type: :hypercube,
    dimensions: 3,
    resolution: 5
  }
})

# Configure hyperplane substrate encoding
Bardo.ExperimentManager.configure(experiment_id, %{
  substrate: %{
    type: :hyperplane,
    input_dimensions: 2,
    output_dimensions: 1,
    hidden_layers: 1
  }
})
```

## Utility Functions

```elixir
# Save a genotype to file
Bardo.Utils.save_genotype(genotype, "models/best_genotype.gen")

# Load a genotype from file
loaded_genotype = Bardo.Utils.load_genotype("models/best_genotype.gen")

# Analyze neural network complexity
stats = Bardo.Utils.analyze_network(nn)

# Calculate compatibility distance between genotypes
distance = Bardo.PopulationManager.SpecieIdentifier.compatibility_distance(
  genotype1, 
  genotype2
)
```

## Event Handling

```elixir
# Subscribe to experiment events
Bardo.EventManager.subscribe(experiment_id, :generation_complete)

# Handle events
def handle_info({:generation_complete, experiment_id, stats}, state) do
  # Process generation statistics
  # ...
  {:noreply, state}
end
```

## Visualization

```elixir
# Generate visualization data
viz_data = Bardo.Visualization.generate_network_visualization(nn)

# Plot fitness over generations
Bardo.Visualization.plot_fitness(experiment_id)

# Plot species over generations
Bardo.Visualization.plot_species(experiment_id)

# Plot complexity over generations
Bardo.Visualization.plot_complexity(experiment_id)
```