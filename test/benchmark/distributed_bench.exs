defmodule Bardo.Benchmark.DistributedBench do
  @moduledoc """
  Benchmarks for distributed operations in the Bardo neuroevolution library.
  
  This module provides benchmarks to measure the performance of distributed
  operations, including parallel fitness evaluation and distributed evolution.
  Since actually distributing across nodes requires a network setup, this benchmark
  simulates distribution using parallel processes.
  
  Run with:
  ```
  mix run test/benchmark/distributed_bench.exs
  ```
  """
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  # Function to run the benchmarks
  def run do
    IO.puts("Running Distributed Operations Benchmarks")
    IO.puts("----------------------------------------\n")
    
    # Run all benchmarks
    benchmark_parallel_fitness()
    benchmark_parallel_evolution()
    benchmark_population_distribution()
    
    # Report completion
    IO.puts("\nBenchmark runs completed successfully.")
  end
  
  # Benchmark parallel fitness evaluation
  defp benchmark_parallel_fitness do
    IO.puts("Benchmark: Parallel Fitness Evaluation")
    IO.puts("-------------------------------------")
    
    # Define population sizes to test
    population_sizes = [10, 100, 1000]
    
    # Define parallelism levels (simulating distributed nodes)
    parallelism_levels = [1, 2, 4, 8]
    
    # Define XOR test cases
    xor_test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Run benchmarks for each population size and parallelism level
    Enum.each(population_sizes, fn pop_size ->
      IO.puts("\nPopulation Size: #{pop_size}")
      
      # Create test population
      population = for _ <- 1..pop_size do
        create_test_network(2, 3, 1)
      end
      
      Enum.each(parallelism_levels, fn num_workers ->
        IO.write("  Workers: #{num_workers}: ")
        
        # Measure time for parallel fitness evaluation
        {time_us, _fitness_values} = :timer.tc(fn -> 
          parallel_fitness_evaluation(population, xor_test_cases, num_workers)
        end)
        
        # Calculate time in milliseconds
        time_ms = time_us / 1000
        
        # Report results
        IO.puts("#{format_float(time_ms)} ms")
      end)
    end)
    
    IO.puts("")
  end
  
  # Benchmark parallel evolution
  defp benchmark_parallel_evolution do
    IO.puts("Benchmark: Parallel Evolution")
    IO.puts("----------------------------")
    
    # Define experiment configs
    experiment_configs = [
      {"Small (Gen: 5, Subpops: 2)", 5, 2},
      {"Medium (Gen: 10, Subpops: 4)", 10, 4},
      {"Large (Gen: 15, Subpops: 8)", 15, 8}
    ]
    
    # Run benchmarks for each experiment configuration
    Enum.each(experiment_configs, fn {name, generations, num_subpops} ->
      IO.write("#{name}: ")
      
      # Fixed population size for all subpopulations
      subpop_size = 20
      total_population = subpop_size * num_subpops
      
      # Measure time for parallel evolution
      {time_us, result} = :timer.tc(fn -> 
        parallel_evolution(generations, subpop_size, num_subpops)
      end)
      
      # Calculate time in milliseconds and seconds
      time_ms = time_us / 1000
      time_s = time_ms / 1000
      
      # Report results
      {best_fitness, _} = result
      IO.puts("#{format_float(time_s)} seconds, Best fitness: #{format_float(best_fitness)}, Total population: #{total_population}")
    end)
    
    IO.puts("")
  end
  
  # Benchmark population distribution strategies
  defp benchmark_population_distribution do
    IO.puts("Benchmark: Population Distribution Strategies")
    IO.puts("--------------------------------------------")
    
    # Define population sizes to test
    population_size = 100
    
    # Define distribution strategies
    distribution_strategies = [
      {"Even Distribution", &distribute_evenly(&1, &2)},
      {"Random Distribution", &distribute_randomly(&1, &2)},
      {"Fitness-Based Distribution", &distribute_by_fitness(&1, &2)}
    ]
    
    # Define XOR test cases
    xor_test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Create test population
    population = 
      for _ <- 1..population_size do
        genotype = create_test_network(2, 3, 1)
        fitness = fitness_function(genotype, xor_test_cases)
        {genotype, fitness}
      end
    
    # Run benchmarks for each distribution strategy
    Enum.each(distribution_strategies, fn {name, strategy_fn} ->
      # Try different numbers of subpopulations
      for num_subpops <- [2, 4, 8] do
        IO.write("  #{name} (#{num_subpops} subpopulations): ")
        
        # Measure time for distribution
        {time_us, subpopulations} = :timer.tc(fn -> 
          strategy_fn.(population, num_subpops)
        end)
        
        # Calculate time in milliseconds
        time_ms = time_us / 1000
        
        # Verify that distribution was correct
        total_distributed = Enum.reduce(subpopulations, 0, fn subpop, acc -> acc + length(subpop) end)
        
        # Report results
        IO.puts("#{format_float(time_ms)} ms, #{total_distributed}/#{population_size} individuals distributed")
      end
    end)
    
    IO.puts("")
  end
  
  # Parallel fitness evaluation implementation
  defp parallel_fitness_evaluation(population, test_cases, num_workers) do
    # Split population into chunks for workers
    chunks = split_into_chunks(population, num_workers)
    
    # Start worker processes
    worker_refs = 
      for chunk <- chunks do
        # Spawn a worker process to evaluate a chunk of the population
        parent = self()
        spawn_monitor(fn -> 
          results = Enum.map(chunk, fn genotype -> 
            fitness_function(genotype, test_cases)
          end)
          send(parent, {:fitness_results, results})
        end)
      end
    
    # Collect results from all workers
    fitness_values = collect_worker_results(worker_refs, [])
    
    # Flatten the results and return
    List.flatten(fitness_values)
  end
  
  # Collect results from worker processes
  defp collect_worker_results([], acc), do: acc
  
  defp collect_worker_results([{pid, ref} | rest], acc) do
    receive do
      {:fitness_results, results} ->
        collect_worker_results(rest, [results | acc])
        
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        # Worker crashed, continue without its results
        collect_worker_results(rest, acc)
    end
  end
  
  # Parallel evolution implementation
  defp parallel_evolution(generations, subpop_size, num_subpops) do
    # Create initial subpopulations
    subpopulations = 
      for _ <- 1..num_subpops do
        # Create a subpopulation
        for _ <- 1..subpop_size do
          genotype = create_test_network(2, 3, 1)
          fitness = fitness_function(genotype, xor_test_cases())
          {genotype, fitness}
        end
      end
    
    # Evolve all subpopulations in parallel
    evolved_subpops = evolve_subpopulations(subpopulations, generations)
    
    # Find best individual across all subpopulations
    all_individuals = List.flatten(evolved_subpops)
    best_individual = Enum.max_by(all_individuals, fn {_genotype, fitness} -> fitness end)
    
    best_individual
  end
  
  # Evolve multiple subpopulations in parallel
  defp evolve_subpopulations(subpopulations, generations) do
    # Start worker processes for each subpopulation
    worker_refs = 
      for subpop <- subpopulations do
        # Spawn a worker process to evolve a subpopulation
        parent = self()
        spawn_monitor(fn -> 
          # Evolve the subpopulation
          evolved_subpop = evolve_subpopulation(subpop, generations)
          send(parent, {:evolved_subpop, evolved_subpop})
        end)
      end
    
    # Collect results from all workers
    evolved_subpops = collect_evolved_results(worker_refs, [])
    
    evolved_subpops
  end
  
  # Collect evolution results from worker processes
  defp collect_evolved_results([], acc), do: acc
  
  defp collect_evolved_results([{pid, ref} | rest], acc) do
    receive do
      {:evolved_subpop, subpop} ->
        collect_evolved_results(rest, [subpop | acc])
        
      {:DOWN, ^ref, :process, ^pid, _reason} ->
        # Worker crashed, continue without its results
        collect_evolved_results(rest, acc)
    end
  end
  
  # Evolve a single subpopulation
  defp evolve_subpopulation(subpop, generations) do
    # Evolve for specified number of generations
    Enum.reduce(1..generations, subpop, fn _gen, pop ->
      evolve_generation(pop, xor_test_cases())
    end)
  end
  
  # Distribute population evenly among subpopulations
  defp distribute_evenly(population, num_subpops) do
    # Split population into roughly equal chunks
    chunk_size = ceil(length(population) / num_subpops)
    Enum.chunk_every(population, chunk_size)
  end
  
  # Distribute population randomly among subpopulations
  defp distribute_randomly(population, num_subpops) do
    # Shuffle the population
    shuffled = Enum.shuffle(population)
    
    # Split into roughly equal chunks
    chunk_size = ceil(length(population) / num_subpops)
    Enum.chunk_every(shuffled, chunk_size)
  end
  
  # Distribute population based on fitness
  defp distribute_by_fitness(population, num_subpops) do
    # Sort by fitness
    sorted = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Distribute individuals in a round-robin fashion based on fitness
    subpops = for _ <- 1..num_subpops, do: []
    
    {final_subpops, _} = 
      Enum.reduce(sorted, {subpops, 0}, fn individual, {subpops, index} ->
        # Add individual to the current subpopulation
        updated_subpops = List.update_at(subpops, index, fn subpop -> [individual | subpop] end)
        
        # Move to the next subpopulation
        next_index = rem(index + 1, num_subpops)
        
        {updated_subpops, next_index}
      end)
    
    # Reverse each subpopulation to maintain the original fitness order
    Enum.map(final_subpops, &Enum.reverse/1)
  end
  
  # Split a list into roughly equal chunks
  defp split_into_chunks(list, num_chunks) do
    chunk_size = ceil(length(list) / num_chunks)
    Enum.chunk_every(list, chunk_size)
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
  
  # XOR test cases
  defp xor_test_cases do
    [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
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
      tournament_size = 3
      tournament = Enum.take_random(sorted_population, min(tournament_size, population_size))
      {parent_genotype, _} = Enum.max_by(tournament, fn {_g, f} -> f end)
      
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
Bardo.Benchmark.DistributedBench.run()