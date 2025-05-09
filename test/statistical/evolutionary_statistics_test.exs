defmodule Bardo.Statistical.EvolutionaryStatisticsTest do
  use ExUnit.Case, async: true
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  @moduletag :statistical
  @moduletag timeout: 300_000  # Allow up to 5 minutes for these tests
  
  # Number of trials to run for statistical tests
  @num_trials 10
  # Maximum generations for each trial
  @max_generations 100
  # Population size for each trial
  @population_size 20
  
  describe "XOR problem statistical performance" do
    @tag :skip
    test "consistently finds solutions with good fitness" do
      # Run multiple evolution trials
      trial_results = run_multiple_evolution_trials(@num_trials)
      
      # Calculate statistics
      final_fitness_values = Enum.map(trial_results, &elem(&1, 0))
      generations_to_converge = Enum.map(trial_results, &elem(&1, 1))
      convergence_rates = Enum.map(trial_results, &elem(&1, 2))
      
      # Calculate mean, standard deviation, min, max
      stats = calculate_statistics(final_fitness_values)
      gen_stats = calculate_statistics(generations_to_converge)
      conv_stats = calculate_statistics(convergence_rates)
      
      # Output results
      IO.puts("\nEvolutionary Performance Statistics (#{@num_trials} trials):")
      IO.puts("Final Fitness: mean=#{stats.mean}, stddev=#{stats.stddev}, min=#{stats.min}, max=#{stats.max}")
      IO.puts("Generations: mean=#{gen_stats.mean}, stddev=#{gen_stats.stddev}, min=#{gen_stats.min}, max=#{gen_stats.max}")
      IO.puts("Convergence Rate (fitness gain per generation): mean=#{conv_stats.mean}, stddev=#{conv_stats.stddev}")
      
      # Success criteria - based on statistical performance
      # 1. Mean fitness should be at least 3.5 (fairly good solutions)
      assert stats.mean >= 3.5, "Mean fitness (#{stats.mean}) is below threshold"
      
      # 2. At least 80% of runs should exceed fitness of 3.0
      success_rate = Enum.count(final_fitness_values, &(&1 >= 3.0)) / @num_trials
      assert success_rate >= 0.8, "Success rate (#{success_rate}) is below threshold"
      
      # 3. Standard deviation should be reasonable (not too much variance)
      assert stats.stddev < 1.0, "Fitness standard deviation (#{stats.stddev}) is too high"
      
      # 4. Should converge within a reasonable number of generations
      assert gen_stats.mean < @max_generations, "Average convergence (#{gen_stats.mean}) takes too many generations"
    end
    
    test "selects correctly for improved fitness" do
      # Compare random search vs. evolutionary search
      random_results = run_random_search(@num_trials)
      evolution_results = run_multiple_evolution_trials(@num_trials)
      
      # Extract final fitness values
      random_fitness = Enum.map(random_results, &elem(&1, 0))
      evolution_fitness = Enum.map(evolution_results, &elem(&1, 0))
      
      # Calculate statistics
      random_stats = calculate_statistics(random_fitness)
      evolution_stats = calculate_statistics(evolution_fitness)
      
      # Output comparison
      IO.puts("\nComparison of Random Search vs. Evolution:")
      IO.puts("Random Search: mean=#{random_stats.mean}, stddev=#{random_stats.stddev}, min=#{random_stats.min}, max=#{random_stats.max}")
      IO.puts("Evolution: mean=#{evolution_stats.mean}, stddev=#{evolution_stats.stddev}, min=#{evolution_stats.min}, max=#{evolution_stats.max}")
      
      # Evolution should perform better than random search
      assert evolution_stats.mean > random_stats.mean, "Evolution (#{evolution_stats.mean}) not better than random search (#{random_stats.mean})"
      assert evolution_stats.max > random_stats.max, "Best evolution result (#{evolution_stats.max}) not better than best random result (#{random_stats.max})"
    end
    
    @tag :skip
    test "mutation parameters affect convergence speed" do
      # Test different mutation parameters
      low_mutation_results = run_multiple_evolution_trials(@num_trials, %{
        add_neuron_probability: 0.05,
        add_link_probability: 0.1, 
        mutate_weights_probability: 0.3
      })
      
      high_mutation_results = run_multiple_evolution_trials(@num_trials, %{
        add_neuron_probability: 0.3,
        add_link_probability: 0.5, 
        mutate_weights_probability: 0.9
      })
      
      # Extract generations to converge
      low_mut_generations = Enum.map(low_mutation_results, &elem(&1, 1))
      high_mut_generations = Enum.map(high_mutation_results, &elem(&1, 1))
      
      # Calculate statistics
      low_mut_stats = calculate_statistics(low_mut_generations)
      high_mut_stats = calculate_statistics(high_mut_generations)
      
      # Extract final fitness
      low_mut_fitness = Enum.map(low_mutation_results, &elem(&1, 0))
      high_mut_fitness = Enum.map(high_mutation_results, &elem(&1, 0))
      
      low_fit_stats = calculate_statistics(low_mut_fitness)
      high_fit_stats = calculate_statistics(high_mut_fitness)
      
      # Output comparison
      IO.puts("\nEffect of Mutation Parameters on Convergence:")
      IO.puts("Low Mutation: generations mean=#{low_mut_stats.mean}, fitness mean=#{low_fit_stats.mean}")
      IO.puts("High Mutation: generations mean=#{high_mut_stats.mean}, fitness mean=#{high_fit_stats.mean}")
      
      # Different mutation rates should produce measurably different outcomes
      # (not asserting which is better, as it depends on the problem)
      mean_diff = abs(low_mut_stats.mean - high_mut_stats.mean)
      assert mean_diff > 1.0, "Insufficient difference in convergence speed between mutation rates (diff=#{mean_diff})"
    end
    
    test "population size affects solution quality" do
      # Test different population sizes
      small_pop_results = run_multiple_evolution_trials(@num_trials, %{}, 10)  # Population size of 10
      large_pop_results = run_multiple_evolution_trials(@num_trials, %{}, 50)  # Population size of 50
      
      # Extract final fitness
      small_pop_fitness = Enum.map(small_pop_results, &elem(&1, 0))
      large_pop_fitness = Enum.map(large_pop_results, &elem(&1, 0))
      
      # Calculate statistics
      small_pop_stats = calculate_statistics(small_pop_fitness)
      large_pop_stats = calculate_statistics(large_pop_fitness)
      
      # Output comparison
      IO.puts("\nEffect of Population Size on Solution Quality:")
      IO.puts("Small Population (10): mean=#{small_pop_stats.mean}, stddev=#{small_pop_stats.stddev}")
      IO.puts("Large Population (50): mean=#{large_pop_stats.mean}, stddev=#{large_pop_stats.stddev}")
      
      # Larger populations should have less variance and potentially better quality
      assert large_pop_stats.stddev <= small_pop_stats.stddev * 1.5, 
        "Larger population doesn't reduce variance as expected"
      
      # Not strictly requiring larger populations to have better mean fitness,
      # as small populations might sometimes get lucky
    end
  end
  
  # Run multiple evolution trials with the same parameters
  defp run_multiple_evolution_trials(num_trials, mutation_params \\ %{}, population_size \\ @population_size) do
    1..num_trials |> Enum.map(fn i ->
      IO.write("Trial #{i}/#{num_trials}...")
      result = run_evolution_trial(mutation_params, population_size)
      IO.puts(" fitness: #{elem(result, 0)}, generations: #{elem(result, 1)}")
      result
    end)
  end
  
  # Run a single evolution trial
  defp run_evolution_trial(mutation_params, population_size) do
    # Set default mutation parameters if not provided
    mutation_params = Map.merge(%{
      add_neuron_probability: 0.1,
      add_link_probability: 0.3,
      mutate_weights_probability: 0.8
    }, mutation_params)
    
    # Create initial population
    population = create_initial_population(population_size)
    
    # Run evolution
    {best_fitness, generations, fitness_progression} = evolve_xor(population, mutation_params)
    
    # Calculate convergence rate (fitness improvement per generation)
    convergence_rate = calculate_convergence_rate(fitness_progression)
    
    {best_fitness, generations, convergence_rate}
  end
  
  # Run a random search (no evolution/selection) for comparison
  defp run_random_search(num_trials) do
    1..num_trials |> Enum.map(fn i ->
      IO.write("Random trial #{i}/#{num_trials}...")
      
      # Generate random networks
      networks = for _ <- 1..(@population_size * @max_generations) do
        genotype = create_random_genotype()
        fitness = fitness_function(genotype, xor_test_cases())
        {genotype, fitness}
      end
      
      # Find the best one
      {_best_genotype, best_fitness} = 
        Enum.max_by(networks, fn {_genotype, fitness} -> fitness end)
        
      IO.puts(" fitness: #{best_fitness}")
      
      # Return similar format to evolution trials
      {best_fitness, @max_generations, 0.0}  # Convergence rate is 0 for random search
    end)
  end
  
  # Create a completely random genotype for the random search baseline
  defp create_random_genotype do
    # Start with a seed genotype
    genotype = create_seed_genotype()
    
    # Add 1-5 hidden neurons randomly
    hidden_count = Enum.random(1..5)
    genotype = Enum.reduce(1..hidden_count, genotype, fn i, g ->
      Genotype.add_neuron(g, :hidden, %{id: "hidden_#{i}"})
    end)
    
    # Get all neuron IDs by layer
    input_ids = Genotype.get_layer_neuron_ids(genotype, :input)
    bias_ids = Genotype.get_layer_neuron_ids(genotype, :bias)
    hidden_ids = Genotype.get_layer_neuron_ids(genotype, :hidden)
    output_ids = Genotype.get_layer_neuron_ids(genotype, :output)
    
    # Add random connections with 50% probability for each possible connection
    possible_connections = [
      # Input to hidden
      for(from_id <- input_ids ++ bias_ids, to_id <- hidden_ids, do: {from_id, to_id}),
      # Hidden to hidden (forward connections only)
      for i <- 0..(length(hidden_ids)-2), j <- (i+1)..(length(hidden_ids)-1) do
        {Enum.at(hidden_ids, i), Enum.at(hidden_ids, j)}
      end,
      # Hidden to output
      for(from_id <- hidden_ids, to_id <- output_ids, do: {from_id, to_id}),
      # Input to output
      for(from_id <- input_ids ++ bias_ids, to_id <- output_ids, do: {from_id, to_id})
    ] |> List.flatten()
    
    # Add 50% of possible connections randomly
    genotype = Enum.reduce(possible_connections, genotype, fn {from_id, to_id}, g ->
      if :rand.uniform() < 0.5 do
        weight = :rand.uniform() * 4 - 2  # Random weight between -2 and 2
        Genotype.add_connection(g, from_id, to_id, weight)
      else
        g
      end
    end)
    
    genotype
  end
  
  # Calculate statistics (mean, stddev, min, max)
  defp calculate_statistics(values) when is_list(values) and length(values) > 0 do
    sum = Enum.sum(values)
    count = length(values)
    mean = sum / count
    
    # Calculate standard deviation
    sum_squared_diff = Enum.reduce(values, 0, fn val, acc ->
      diff = val - mean
      acc + diff * diff
    end)
    
    # Use sample standard deviation (n-1 denominator)
    variance = if count > 1, do: sum_squared_diff / (count - 1), else: 0
    stddev = :math.sqrt(variance)
    
    # Find min and max
    min_val = Enum.min(values)
    max_val = Enum.max(values)
    
    %{
      mean: mean,
      stddev: stddev,
      min: min_val,
      max: max_val,
      count: count
    }
  end
  
  # Calculate convergence rate from fitness progression
  defp calculate_convergence_rate(fitness_progression) when length(fitness_progression) <= 1 do
    0.0  # Can't calculate rate with 0 or 1 data point
  end
  
  defp calculate_convergence_rate(fitness_progression) do
    # Get initial and final fitness
    initial_fitness = List.last(fitness_progression)
    final_fitness = List.first(fitness_progression)
    
    # Calculate improvement divided by generations
    generations = length(fitness_progression) - 1
    (final_fitness - initial_fitness) / generations
  end
  
  # Evolve a population to solve XOR
  defp evolve_xor(population, mutation_params) do
    evolve_xor(population, mutation_params, 0, [])
  end
  
  defp evolve_xor(population, _mutation_params, generation, fitness_history) 
       when generation >= @max_generations do
    # Return best fitness, generations, and history
    {_genotype, best_fitness} = 
      Enum.max_by(population, fn {_genotype, fitness} -> fitness end)
    {best_fitness, generation, [best_fitness | fitness_history]}
  end
  
  defp evolve_xor(population, mutation_params, generation, fitness_history) do
    # Sort population by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Get the best individual
    {_best_genotype, best_fitness} = hd(sorted_population)
    
    # Add to fitness history
    updated_history = [best_fitness | fitness_history]
    
    # Check if we've found a solution
    if best_fitness >= 3.95 do
      # Success - return early
      {best_fitness, generation + 1, updated_history}
    else
      # Create next generation
      new_population = next_generation(sorted_population, length(population), mutation_params)
      
      # Continue evolution
      evolve_xor(new_population, mutation_params, generation + 1, updated_history)
    end
  end
  
  # Create a new generation
  defp next_generation(sorted_population, population_size, mutation_params) do
    # Keep the top 25% (elitism)
    elite_count = max(2, floor(population_size * 0.25))
    elites = Enum.take(sorted_population, elite_count)
    
    # Create offspring to fill the population
    offspring_count = population_size - elite_count
    
    offspring = for _ <- 1..offspring_count do
      # Tournament selection (pick 3 random individuals, take the best)
      tournament_size = min(3, floor(length(sorted_population) / 2))
      tournament = Enum.take_random(sorted_population, tournament_size)
      
      {parent_genotype, _fitness} = 
        Enum.max_by(tournament, fn {_genotype, fitness} -> fitness end)
      
      # Mutate the parent
      mutated_genotype = GenomeMutator.simple_mutate(parent_genotype, mutation_params)
      
      # Evaluate the offspring
      fitness = fitness_function(mutated_genotype, xor_test_cases())
      
      {mutated_genotype, fitness}
    end
    
    # Combine elites and offspring
    elites ++ offspring
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
  
  # Create the initial population
  defp create_initial_population(size) do
    for _ <- 1..size do
      # Create a simple genotype with basic structure for XOR
      genotype = create_seed_genotype()
      
      # Add some random connections
      genotype = add_random_connections(genotype)
      
      # Evaluate the genotype
      fitness = fitness_function(genotype, xor_test_cases())
      
      # Return the genotype and its fitness
      {genotype, fitness}
    end
  end
  
  # Create a seed genotype for the XOR problem
  defp create_seed_genotype do
    # Create a new genotype
    genotype = Genotype.new()
    
    # Add input neurons for the two inputs
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_1"})
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_2"})
    
    # Add bias neuron
    genotype = Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add output neuron
    genotype = Genotype.add_neuron(genotype, :output, %{id: "output"})
    
    # Return the base genotype
    genotype
  end
  
  # Add random connections to a genotype
  defp add_random_connections(genotype) do
    # Add 1-3 hidden neurons
    genotype = Enum.reduce(1..Enum.random(1..3), genotype, fn i, g ->
      Genotype.add_neuron(g, :hidden, %{id: "hidden_#{i}"})
    end)
    
    # Get lists of inputs, hidden, and outputs
    input_ids = Genotype.get_layer_neuron_ids(genotype, :input)
    bias_ids = Genotype.get_layer_neuron_ids(genotype, :bias)
    hidden_ids = Genotype.get_layer_neuron_ids(genotype, :hidden)
    output_ids = Genotype.get_layer_neuron_ids(genotype, :output)
    
    # Connect inputs to hidden
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(hidden_ids, g, fn hidden_id, g2 ->
        weight = (Enum.random(-10..10) / 10)
        Genotype.add_connection(g2, input_id, hidden_id, weight)
      end)
    end)
    
    # Connect hidden to outputs
    genotype = Enum.reduce(hidden_ids, genotype, fn hidden_id, g ->
      Enum.reduce(output_ids, g, fn output_id, g2 ->
        weight = (Enum.random(-10..10) / 10)
        Genotype.add_connection(g2, hidden_id, output_id, weight)
      end)
    end)
    
    # Some direct input to output connections
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(output_ids, g, fn output_id, g2 ->
        if Enum.random(0..1) == 1 do
          weight = (Enum.random(-10..10) / 10)
          Genotype.add_connection(g2, input_id, output_id, weight)
        else
          g2
        end
      end)
    end)
    
    genotype
  end
  
  # Fitness function
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
    # Maximum fitness is 4.0 (zero error on all 4 test cases)
    4.0 - total_error
  end
end