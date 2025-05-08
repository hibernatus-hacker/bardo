defmodule Bardo.Benchmark.EvolutionaryBench do
  @moduledoc """
  Benchmarks for genetic operations in the Bardo neuroevolution library.
  
  This module provides benchmarks for various genetic operations,
  including mutation, selection, and evolutionary processes.
  
  Run with:
  ```
  mix run test/benchmark/evolutionary_bench.exs
  ```
  """
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  # Function to run the benchmarks
  def run do
    IO.puts("Running Evolutionary Operations Benchmarks")
    IO.puts("------------------------------------------\n")
    
    # Run all benchmarks
    benchmark_mutation()
    benchmark_selection()
    benchmark_evolution()
    
    # Report completion
    IO.puts("\nBenchmark runs completed successfully.")
  end
  
  # Benchmark mutation operations
  defp benchmark_mutation do
    IO.puts("Benchmark: Mutation Operations")
    IO.puts("-----------------------------")
    
    # Define network sizes to test
    network_sizes = [
      {"Small (5 neurons)", 2, 2, 1, 100},
      {"Medium (20 neurons)", 5, 10, 5, 50},
      {"Large (50 neurons)", 10, 30, 10, 20}
    ]
    
    # Define mutation types
    mutation_types = [
      {"Add Neuron", %{add_neuron_probability: 1.0, add_link_probability: 0.0, mutate_weights_probability: 0.0}},
      {"Add Link", %{add_neuron_probability: 0.0, add_link_probability: 1.0, mutate_weights_probability: 0.0}},
      {"Mutate Weights", %{add_neuron_probability: 0.0, add_link_probability: 0.0, mutate_weights_probability: 1.0}},
      {"Combined", %{add_neuron_probability: 0.3, add_link_probability: 0.3, mutate_weights_probability: 0.7}}
    ]
    
    # Run benchmarks for each network size and mutation type
    Enum.each(network_sizes, fn {size_name, inputs, hidden, outputs, iterations} ->
      IO.puts("\n#{size_name} Network:")
      
      # Create test network
      genotype = create_test_network(inputs, hidden, outputs)
      
      Enum.each(mutation_types, fn {mut_name, mut_params} ->
        IO.write("  #{mut_name}: ")
        
        # Measure time for mutation
        {time_us, _results} = :timer.tc(fn -> 
          for _ <- 1..iterations do
            GenomeMutator.simple_mutate(genotype, mut_params)
          end
        end)
        
        # Calculate average time per mutation
        avg_time_us = time_us / iterations
        avg_time_ms = avg_time_us / 1000
        
        # Report results
        IO.puts("#{format_float(avg_time_ms)} ms per mutation")
      end)
    end)
    
    IO.puts("")
  end
  
  # Benchmark selection operations
  defp benchmark_selection do
    IO.puts("Benchmark: Selection Operations")
    IO.puts("------------------------------")
    
    # Define population sizes to test
    population_sizes = [10, 100, 1000]
    
    # Define selection algorithms
    selection_algorithms = [
      {"Tournament (size 3)", &tournament_selection(&1, 3)},
      {"Tournament (size 5)", &tournament_selection(&1, 5)},
      {"Truncation (top 20%)", &truncation_selection(&1, 0.2)},
      {"Roulette Wheel", &roulette_wheel_selection/1}
    ]
    
    # Run benchmarks for each population size and selection algorithm
    Enum.each(population_sizes, fn pop_size ->
      IO.puts("\nPopulation Size: #{pop_size}")
      
      # Create test population
      population = create_test_population(pop_size)
      
      Enum.each(selection_algorithms, fn {alg_name, selection_fn} ->
        IO.write("  #{alg_name}: ")
        
        # Measure time for selection
        {time_us, _selected} = :timer.tc(fn -> 
          # Select half the population
          selection_count = max(1, div(pop_size, 2))
          for _ <- 1..selection_count do
            selection_fn.(population)
          end
        end)
        
        # Calculate time in milliseconds
        time_ms = time_us / 1000
        
        # Report results
        IO.puts("#{format_float(time_ms)} ms for #{max(1, div(pop_size, 2))} selections")
      end)
    end)
    
    IO.puts("")
  end
  
  # Benchmark full evolution process
  defp benchmark_evolution do
    IO.puts("Benchmark: Full Evolution Process")
    IO.puts("--------------------------------")
    
    # Define experiment configs to test
    experiment_configs = [
      {"Small (Pop: 10, Gen: 5)", 10, 5},
      {"Medium (Pop: 50, Gen: 10)", 50, 10},
      {"Large (Pop: 100, Gen: 20)", 100, 20}
    ]
    
    # Define XOR test cases
    xor_test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Run benchmarks for each experiment configuration
    Enum.each(experiment_configs, fn {name, pop_size, generations} ->
      IO.write("#{name}: ")
      
      # Measure time for full evolution
      {time_us, {best_fitness, _best_genotype}} = :timer.tc(fn -> 
        evolve_xor(pop_size, generations, xor_test_cases)
      end)
      
      # Calculate time in milliseconds and seconds
      time_ms = time_us / 1000
      time_s = time_ms / 1000
      
      # Report results
      IO.puts("#{format_float(time_s)} seconds, Best fitness: #{format_float(best_fitness)}")
    end)
    
    IO.puts("")
  end
  
  # Create a test network with the specified dimensions
  defp create_test_network(input_count, hidden_count, output_count) do
    # Create a new genotype
    genotype = Genotype.new()
    
    # Add input neurons
    genotype = Enum.reduce(1..input_count, genotype, fn i, g ->
      Genotype.add_neuron(g, :input, %{id: "input_#{i}"})
    end)
    
    # Add bias neuron
    genotype = Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add hidden neurons
    genotype = Enum.reduce(1..hidden_count, genotype, fn i, g ->
      Genotype.add_neuron(g, :hidden, %{id: "hidden_#{i}"})
    end)
    
    # Add output neurons
    genotype = Enum.reduce(1..output_count, genotype, fn i, g ->
      Genotype.add_neuron(g, :output, %{id: "output_#{i}"})
    end)
    
    # Add connections
    genotype = add_random_connections(genotype)
    
    genotype
  end
  
  # Add random connections to a genotype
  defp add_random_connections(genotype) do
    # Get neuron IDs by layer
    input_ids = Genotype.get_layer_neuron_ids(genotype, :input)
    bias_ids = Genotype.get_layer_neuron_ids(genotype, :bias)
    hidden_ids = Genotype.get_layer_neuron_ids(genotype, :hidden)
    output_ids = Genotype.get_layer_neuron_ids(genotype, :output)
    
    # Connect inputs to hidden
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(hidden_ids, g, fn hidden_id, g2 ->
        weight = :rand.uniform() * 2 - 1
        Genotype.add_connection(g2, input_id, hidden_id, weight)
      end)
    end)
    
    # Connect hidden to outputs
    genotype = Enum.reduce(hidden_ids, genotype, fn hidden_id, g ->
      Enum.reduce(output_ids, g, fn output_id, g2 ->
        weight = :rand.uniform() * 2 - 1
        Genotype.add_connection(g2, hidden_id, output_id, weight)
      end)
    end)
    
    genotype
  end
  
  # Create a test population with random fitness values
  defp create_test_population(size) do
    for i <- 1..size do
      # Every 10th individual has a high fitness, the rest have random fitness
      fitness = if rem(i, 10) == 0, do: :rand.uniform() * 0.5 + 3.5, else: :rand.uniform() * 3.0
      genotype = create_test_network(2, 3, 1)
      {genotype, fitness}
    end
  end
  
  # Tournament selection
  defp tournament_selection(population, tournament_size) do
    # Select random individuals for tournament
    tournament = Enum.take_random(population, min(tournament_size, length(population)))
    
    # Select the best individual
    {genotype, _fitness} = Enum.max_by(tournament, fn {_genotype, fitness} -> fitness end)
    
    genotype
  end
  
  # Truncation selection
  defp truncation_selection(population, fraction) do
    # Sort population by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Select from the top fraction
    top_count = max(1, floor(length(population) * fraction))
    top_individuals = Enum.take(sorted_population, top_count)
    
    # Select a random individual from the top
    {genotype, _fitness} = Enum.random(top_individuals)
    
    genotype
  end
  
  # Roulette wheel selection
  defp roulette_wheel_selection(population) do
    # Calculate total fitness
    total_fitness = Enum.reduce(population, 0, fn {_genotype, fitness}, acc -> acc + max(0, fitness) end)
    
    # Generate a random point on the wheel
    r = :rand.uniform() * total_fitness
    
    # Find the individual at that point
    {genotype, _} = select_roulette(population, r, 0)
    
    genotype
  end
  
  # Helper for roulette wheel selection
  defp select_roulette([{genotype, fitness} | rest], r, acc) do
    acc = acc + max(0, fitness)
    if acc >= r do
      {genotype, fitness}
    else
      select_roulette(rest, r, acc)
    end
  end
  
  # Fallback if nothing is selected (shouldn't happen with valid fitness values)
  defp select_roulette([], _r, _acc) do
    {create_test_network(2, 3, 1), 0.0}
  end
  
  # XOR fitness function
  defp fitness_function(genotype, test_cases) do
    # Convert genotype to neural network
    nn = Cortex.from_genotype(genotype)
    
    # Calculate error across all test cases
    total_error = Enum.reduce(test_cases, 0.0, fn {inputs, expected}, acc ->
      # Activate the network
      outputs = Cortex.activate(nn, inputs)
      
      # Calculate squared error
      error = Enum.zip(outputs, expected)
              |> Enum.map(fn {output, target} -> (output - target) * (output - target) end)
              |> Enum.sum()
      
      # Add to total error
      acc + error
    end)
    
    # Convert error to fitness (lower error = higher fitness)
    4.0 - total_error
  end
  
  # Evolve for XOR problem
  defp evolve_xor(population_size, generations, test_cases) do
    # Create initial population
    population = for _ <- 1..population_size do
      genotype = create_test_network(2, Enum.random(2..5), 1)
      fitness = fitness_function(genotype, test_cases)
      {genotype, fitness}
    end
    
    # Evolve for specified number of generations
    final_population = Enum.reduce(1..generations, population, fn _gen, pop ->
      evolve_generation(pop, test_cases)
    end)
    
    # Return best individual
    Enum.max_by(final_population, fn {_genotype, fitness} -> fitness end)
  end
  
  # Evolve a single generation
  defp evolve_generation(population, test_cases) do
    # Sort by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Keep the best 20% (elitism)
    population_size = length(population)
    elite_count = max(1, floor(population_size * 0.2))
    elites = Enum.take(sorted_population, elite_count)
    
    # Create offspring to fill the population
    offspring_count = population_size - elite_count
    
    offspring = for _ <- 1..offspring_count do
      # Select parent using tournament selection
      parent_genotype = tournament_selection(sorted_population, 3)
      
      # Mutate
      mutated_genotype = GenomeMutator.simple_mutate(parent_genotype, %{
        add_neuron_probability: 0.1,
        add_link_probability: 0.3,
        mutate_weights_probability: 0.8
      })
      
      # Evaluate fitness
      fitness = fitness_function(mutated_genotype, test_cases)
      
      {mutated_genotype, fitness}
    end
    
    # Combine elites and offspring
    elites ++ offspring
  end
  
  # Format a float to 2 decimal places
  defp format_float(value) do
    :erlang.float_to_binary(value, [decimals: 2])
  end
end

# Run the benchmarks when this file is executed directly
Bardo.Benchmark.EvolutionaryBench.run()