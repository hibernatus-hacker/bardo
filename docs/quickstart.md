# Bardo Quickstart Guide

This guide will help you get started with Bardo for your neuroevolution tasks. We'll walk through basic setup, running included examples, and creating a simple XOR experiment.

## Installation

Add Bardo to your mix.exs dependencies:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

Then fetch and compile:

```bash
mix deps.get
mix compile
```

## Your First Experiment: XOR

Let's create a simple experiment to evolve a neural network that can solve the XOR problem.

### 1. Create a new project

```bash
mix new xor_example
cd xor_example
```

### 2. Add Bardo to dependencies

Add Bardo to `mix.exs`:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

### 3. Create an XOR experiment module

Create a file `lib/xor_experiment.ex`:

```elixir
defmodule XorExperiment do
  @moduledoc """
  A simple example demonstrating how to evolve a neural network to solve the XOR problem.
  """
  
  alias Bardo.ExperimentManager
  alias Bardo.AgentManager.Cortex
  
  def run do
    # Create a new experiment
    experiment_id = "xor_experiment_#{:os.system_time(:millisecond)}"
    
    # Configure the experiment
    config = %{
      # Population settings
      population_size: 100,
      max_generations: 100,
      species_distance_threshold: 0.5,
      
      # Neural network settings
      activation_function: :sigmoid,
      weight_range: {-1.0, 1.0},
      bias_range: {-1.0, 1.0},
      
      # Mutation settings
      mutation_rate: 0.3,
      add_neuron_probability: 0.1,
      add_link_probability: 0.2,
      
      # Evaluation settings
      fitness_goal: 3.9 # Perfect solution would be 4.0
    }
    
    IO.puts("Starting XOR experiment: #{experiment_id}")
    
    # Create and configure the experiment
    {:ok, _} = ExperimentManager.new_experiment(experiment_id)
    :ok = ExperimentManager.configure(experiment_id, config)
    
    # Start the experiment with XOR fitness function
    :ok = ExperimentManager.start_evaluation(experiment_id, &xor_fitness/1)
    
    # Wait for completion
    monitor_progress(experiment_id)
    
    # Test the best solution
    test_best_solution(experiment_id)
  end
  
  # Fitness function for XOR
  defp xor_fitness(genotype) do
    # Convert genotype to neural network
    nn = Cortex.from_genotype(genotype)
    
    # Define XOR test cases
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Calculate error for each test case
    total_error = Enum.reduce(test_cases, 0.0, fn {inputs, expected}, acc ->
      # Run the neural network
      outputs = Cortex.activate(nn, inputs)
      
      # Calculate error (difference between expected and actual output)
      error = Enum.zip(outputs, expected)
              |> Enum.map(fn {output, target} -> abs(output - target) end)
              |> Enum.sum()
      
      # Add to total error
      acc + error
    end)
    
    # Convert error to fitness (lower error = higher fitness)
    4.0 - total_error
  end
  
  # Monitor experiment progress
  defp monitor_progress(experiment_id) do
    # Poll for status until complete
    case ExperimentManager.status(experiment_id) do
      {:completed, _} ->
        IO.puts("Experiment completed!")
      
      {:in_progress, %{generation: gen, best_fitness: fitness}} ->
        IO.puts("Generation: #{gen}, Best Fitness: #{fitness}")
        :timer.sleep(500)
        monitor_progress(experiment_id)
      
      {:error, reason} ->
        IO.puts("Error: #{inspect(reason)}")
    end
  end
  
  # Test the best solution against XOR test cases
  defp test_best_solution(experiment_id) do
    # Get best genotype
    {:ok, best_genotype} = ExperimentManager.get_best_solution(experiment_id)
    
    # Convert to neural network
    nn = Cortex.from_genotype(best_genotype)
    
    # Define test cases
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    IO.puts("\nTesting best solution:")
    
    # Test each case
    Enum.each(test_cases, fn {inputs, expected} ->
      outputs = Cortex.activate(nn, inputs)
      
      input_str = inputs |> Enum.map(&Float.to_string/1) |> Enum.join(", ")
      output_str = outputs |> Enum.map(&Float.to_string/1) |> Enum.join(", ")
      expected_str = expected |> Enum.map(&Float.to_string/1) |> Enum.join(", ")
      
      IO.puts("Input: [#{input_str}] => Output: [#{output_str}] (Expected: [#{expected_str}])")
    end)
    
    # Display network topology
    IO.puts("\nNeural Network Structure:")
    IO.inspect(nn, label: "Neural Network")
  end
end
```

### 4. Run the experiment

```elixir
# In IEx
iex -S mix
iex> XorExperiment.run()
```

You should see output showing the progress of the evolutionary process, and finally the performance of the best neural network on the XOR problem.

## Running Built-in Examples

Bardo comes with several built-in examples you can run:

### Double Pole Balancing

```elixir
# Start IEx
iex -S mix

# Run double pole balancing without damping
iex> Bardo.Examples.Benchmarks.Dpb.run_without_damping()

# Run double pole balancing with damping
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping()
```

### Flatland Predator-Prey Simulation

```elixir
# Start IEx
iex -S mix

# Run the flatland simulation
iex> Bardo.Examples.Applications.Flatland.run()
```

## Next Steps

Now that you've run your first experiment, consider:

1. Exploring the [API documentation](api_reference.md) for details on all available functions
2. Checking out the [advanced guide](advanced.md) for more complex usage patterns
3. Looking at the source code of the included examples to understand more complex applications

For more information, refer to the [complete documentation](https://hexdocs.pm/bardo).