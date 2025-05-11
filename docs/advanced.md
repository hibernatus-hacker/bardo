# Advanced Bardo Usage

This guide covers advanced topics and techniques for working with Bardo.

## Custom Fitness Functions

A fitness function evaluates how well a neural network performs at a given task. Here's how to create your own:

```elixir
defmodule MyApp.FitnessFunctions do
  def xor_fitness(genotype) do
    # Create neural network from genotype
    nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
    
    # Test cases for XOR
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Calculate error across all test cases
    total_error = Enum.reduce(test_cases, 0, fn {inputs, expected}, acc ->
      outputs = Bardo.AgentManager.Cortex.activate(nn, inputs)
      error = Enum.sum(Enum.map(Enum.zip(outputs, expected), fn {o, e} -> abs(o - e) end))
      acc + error
    end)
    
    # Convert error to fitness (lower error = higher fitness)
    fitness = 4 - total_error
    
    # Return fitness score
    fitness
  end
end
```

When creating fitness functions, consider:
- Normalization: Keep fitness values in a consistent range
- Granularity: Provide enough differentiation between solutions
- Guidance: Shape the fitness landscape to guide evolution toward desired behaviors

## Developing Custom Sensors

Sensors provide input to neural networks. To create a custom sensor:

```elixir
defmodule MyApp.Sensors.TemperatureSensor do
  @behaviour Bardo.AgentManager.Sensor
  
  @impl true
  def init(params) do
    # Initialize sensor with given parameters
    {:ok, params}
  end
  
  @impl true
  def sense(state, world_state) do
    # Extract temperature from world state
    temperature = world_state.temperature
    
    # Normalize temperature to range [0,1]
    normalized_temp = (temperature - state.min_temp) / (state.max_temp - state.min_temp)
    
    # Return sensor reading
    {:ok, [normalized_temp], state}
  end
end
```

When designing sensors:
- Normalize inputs to a standard range (typically [-1, 1] or [0, 1])
- Consider sensor placement and field of view
- Determine appropriate sensor resolution and update frequency

## Developing Custom Actuators

Actuators allow neural networks to interact with their environment:

```elixir
defmodule MyApp.Actuators.JointActuator do
  @behaviour Bardo.AgentManager.Actuator
  
  @impl true
  def init(params) do
    # Initialize actuator with given parameters
    {:ok, params}
  end
  
  @impl true
  def actuate(state, world_state, output_vector) do
    # Extract joint angle from neural network output
    [joint_angle] = output_vector
    
    # Scale from [-1,1] to actual joint limits
    scaled_angle = state.min_angle + (joint_angle + 1) * (state.max_angle - state.min_angle) / 2
    
    # Apply to world state
    new_world_state = put_in(world_state.joint_positions[state.joint_id], scaled_angle)
    
    # Return new world state
    {:ok, new_world_state, state}
  end
end
```

## Advanced Mutation Operators

Bardo comes with standard mutation operators, but you can create custom ones:

```elixir
defmodule MyApp.CustomMutator do
  def mutate_weights_with_noise(genotype, config) do
    noise_scale = config[:noise_scale] || 0.1
    
    # Apply Gaussian noise to all weights
    updated_weights = Enum.map(genotype.weights, fn {id, weight} ->
      noise = :rand.normal() * noise_scale
      {id, weight + noise}
    end)
    
    # Return updated genotype
    %{genotype | weights: Map.new(updated_weights)}
  end
end
```

To use custom mutation operators:

```elixir
# Configure experiment with custom mutation operator
Bardo.ExperimentManager.configure(experiment, %{
  population_size: 50,
  mutation_operators: [
    {MyApp.CustomMutator, :mutate_weights_with_noise, [%{noise_scale: 0.05}], 0.3}
  ]
})
```

<!-- Distributed training will be supported in a future release -->

## Custom Neural Activation Functions

By default, Bardo uses sigmoid activation functions, but you can define others:

```elixir
defmodule MyApp.ActivationFunctions do
  def relu(x) do
    max(0, x)
  end
  
  def leaky_relu(x) do
    if x > 0, do: x, else: 0.01 * x
  end
  
  def tanh(x) do
    :math.tanh(x)
  end
end

# Use custom activation function when creating a neuron
Bardo.PopulationManager.Genotype.add_neuron(genotype, :hidden, %{
  activation_function: {MyApp.ActivationFunctions, :tanh}
})
```

## Custom Substrate Encodings

For complex problems, you may want to use indirect encodings (where genotype doesn't directly specify each connection):

```elixir
# Configure hypercube substrate encoding
Bardo.ExperimentManager.configure(experiment, %{
  substrate: %{
    type: :hypercube,
    dimensions: 3,
    resolution: 5,
    connectivity_function: {MyApp.Substrate, :connectivity_function}
  }
})
```

## Real-time Visualization

To visualize evolution progress:

```elixir
# Start visualization server
Bardo.Visualization.start(%{
  port: 8080,
  refresh_rate: 1000,  # ms
  metrics: [:fitness, :complexity, :diversity]
})

# Configure experiment to send data to visualization
Bardo.ExperimentManager.configure(experiment, %{
  visualize: true,
  visualization_endpoint: "http://localhost:8080/data"
})
```

## Saving and Loading Evolved Networks

To save your best evolved networks for later use:

```elixir
# Get best solution from experiment
best_solution = Bardo.ExperimentManager.get_best_solution(experiment)

# Save to file
Bardo.Utils.save_genotype(best_solution, "models/xor_solution.gen")

# Load from file
loaded_genotype = Bardo.Utils.load_genotype("models/xor_solution.gen")

# Create neural network from saved genotype
nn = Bardo.AgentManager.Cortex.from_genotype(loaded_genotype)
```

## Custom Selection Algorithms

Bardo supports different selection algorithms for choosing which individuals reproduce:

```elixir
defmodule MyApp.SelectionAlgorithms do
  def tournament_selection(population, tournament_size, elite_count) do
    # Sort population by fitness
    sorted_pop = Enum.sort_by(population, fn agent -> agent.fitness end, :desc)
    
    # Keep elite individuals
    {elite, rest} = Enum.split(sorted_pop, elite_count)
    
    # Fill remaining slots with tournament selection
    selected = elite ++ tournament_select(rest, length(sorted_pop) - elite_count, tournament_size)
    
    selected
  end
  
  defp tournament_select(population, count, tournament_size) do
    Enum.map(1..count, fn _ ->
      # Select random individuals for tournament
      contestants = Enum.take_random(population, tournament_size)
      
      # Return winner (highest fitness)
      Enum.max_by(contestants, fn agent -> agent.fitness end)
    end)
  end
end

# Configure experiment with custom selection algorithm
Bardo.ExperimentManager.configure(experiment, %{
  selection_algorithm: {MyApp.SelectionAlgorithms, :tournament_selection, [5, 2]}
})
```

## Speciation and Diversity Preservation

To maintain genetic diversity during evolution:

```elixir
# Configure experiment with speciation
Bardo.ExperimentManager.configure(experiment, %{
  enable_speciation: true,
  species_distance_threshold: 0.3,
  species_compatibility_function: {Bardo.PopulationManager.SpecieIdentifier, :compatibility_distance},
  species_elitism: true,
  minimum_species_size: 5
})
```