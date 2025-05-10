defmodule Bardo.Examples.Simple.Xor do
  @moduledoc """
  A simple example demonstrating how to evolve a neural network to solve the XOR problem.
  
  This is a self-contained example that doesn't rely on the full machinery of the
  population and experiment managers, making it easier to understand and a good
  starting point.
  """
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  @doc """
  Run the XOR example.
  
  ## Options
  
  * `:population_size` - size of the population (default: 100)
  * `:max_generations` - maximum number of generations (default: 50)
  * `:show_progress` - show progress during evolution (default: true)
  * `:verbose` - show detailed information (default: false)
  
  ## Examples
  
      iex> Bardo.Examples.Simple.Xor.run()
      
      # With custom parameters
      iex> Bardo.Examples.Simple.Xor.run(population_size: 150, max_generations: 100)
  """
  def run(opts \\ []) do
    # Configuration
    population_size = Keyword.get(opts, :population_size, 100)
    max_generations = Keyword.get(opts, :max_generations, 50)
    show_progress = Keyword.get(opts, :show_progress, true)
    verbose = Keyword.get(opts, :verbose, false)
    
    # Create initial population
    IO.puts("Creating initial population of size #{population_size}...")
    population = create_initial_population(population_size)
    
    # Evolve the population
    IO.puts("Starting evolution for #{max_generations} generations...")
    {best_genotype, best_fitness, generations} = evolve(
      population, 
      max_generations,
      show_progress: show_progress,
      verbose: verbose
    )
    
    # Create neural network from best genotype
    nn = Cortex.from_genotype(best_genotype)
    
    # Display results
    IO.puts("\nEvolution completed after #{generations} generations")
    IO.puts("Best fitness: #{best_fitness}")
    
    IO.puts("\nTesting best solution on XOR:")
    display_xor_results(nn)
    
    # Return the best neural network
    nn
  end
  
  # Create the initial population
  defp create_initial_population(size) do
    for _ <- 1..size do
      # Create a simple genotype with basic structure for XOR
      genotype = create_seed_genotype()
      
      # Add some random connections
      genotype = add_random_connections(genotype)
      
      # Evaluate the genotype
      fitness = fitness_function(genotype)
      
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
  
  # Evolve the population
  defp evolve(population, max_generations, opts) do
    evolve(population, 0, max_generations, nil, 0, opts)
  end
  
  defp evolve(_population, generation, max_generations, best_genotype, best_fitness, _opts) 
    when generation >= max_generations do
    {best_genotype, best_fitness, generation}
  end
  
  defp evolve(population, generation, max_generations, current_best_genotype, current_best_fitness, opts) do
    # Sort population by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Get the best individual
    {best_genotype, best_fitness} = hd(sorted_population)
    
    # Check if we've found a solution
    if best_fitness >= 3.99 do
      {best_genotype, best_fitness, generation + 1}
    else
      # Show progress
      if Keyword.get(opts, :show_progress, true) and rem(generation, 5) == 0 do
        IO.puts("Generation #{generation}: Best fitness = #{best_fitness}")
        
        if Keyword.get(opts, :verbose, false) do
          show_xor_results(best_genotype)
        end
      end
      
      # Record new best fitness if improved
      {tracked_best_genotype, tracked_best_fitness} = 
        if best_fitness > current_best_fitness do
          {best_genotype, best_fitness}
        else
          {current_best_genotype, current_best_fitness}
        end
      
      # Select parents for next generation
      parents = select_parents(sorted_population)
      
      # Create new population
      new_population = create_new_generation(parents, Enum.count(population))
      
      # Continue evolution
      evolve(new_population, generation + 1, max_generations, tracked_best_genotype, tracked_best_fitness, opts)
    end
  end
  
  # Select parents for reproduction
  defp select_parents(sorted_population) do
    # Take the top 30% of the population as parents (increased from 25%)
    # This gives more diversity in the gene pool for selection
    count = max(4, ceil(length(sorted_population) * 0.30))
    Enum.take(sorted_population, count)
  end
  
  # Create a new generation
  defp create_new_generation(parents, population_size) do
    # Keep the parents (elitism)
    elites = parents

    # Create offspring to fill the population
    offspring_count = population_size - length(elites)

    # Use more than one parent - tournament selection
    offspring = for _ <- 1..offspring_count do
      # Select a random parent using tournament selection (better than just random selection)
      {parent_genotype, _fitness} = select_parent_by_tournament(parents)

      # Create a mutated offspring with improved mutation probabilities
      mutated_genotype = GenomeMutator.simple_mutate(parent_genotype, %{
        add_neuron_probability: 0.15,  # Slightly increased to promote structural innovation
        add_link_probability: 0.4,     # Increased to ensure better connectivity
        mutate_weights_probability: 0.9 # Very high to fine-tune weights
      })

      # Evaluate the new genotype
      fitness = fitness_function(mutated_genotype)

      # Return the genotype and its fitness
      {mutated_genotype, fitness}
    end

    # Combine elites and offspring
    elites ++ offspring
  end

  # Tournament selection - select the best from a random subset
  defp select_parent_by_tournament(parents) do
    # Take 3 random parents for tournament
    tournament_size = min(3, length(parents))
    tournament = for _ <- 1..tournament_size, do: Enum.random(parents)

    # Select the best one
    Enum.max_by(tournament, fn {_genotype, fitness} -> fitness end)
  end
  
  # XOR fitness function
  defp fitness_function(genotype) do
    # Convert genotype to neural network
    nn = Cortex.from_genotype(genotype)

    # Test cases for XOR
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]

    # Calculate error across all test cases
    {total_error, correct_outputs} = Enum.reduce(test_cases, {0.0, 0}, fn {inputs, expected}, {error_acc, correct_acc} ->
      # Activate the network
      outputs = Cortex.activate(nn, inputs)

      # Calculate squared error
      error = Enum.zip(outputs, expected)
              |> Enum.map(fn {output, target} -> (output - target) * (output - target) end)
              |> Enum.sum()

      # Count correct outputs (less than 0.3 error is considered correct)
      # This helps drive evolution toward the correct solutions faster
      is_correct = error < 0.3
      correct_count = if is_correct, do: correct_acc + 1, else: correct_acc

      # Add to total error - weigh cases with high error more
      # to encourage fixing the harder cases
      weighted_error = if error > 0.5, do: error * 1.2, else: error

      {error_acc + weighted_error, correct_count}
    end)

    # Calculate base fitness (lower error = higher fitness)
    base_fitness = 4.0 - total_error

    # Add bonus for getting correct outputs to encourage correct solutions
    bonus = correct_outputs * 0.05

    # Return total fitness with bonus
    base_fitness + bonus
  end
  
  # Display XOR results for a given neural network
  defp display_xor_results(nn) do
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    Enum.each(test_cases, fn {inputs, expected} ->
      # Activate the network
      outputs = Cortex.activate(nn, inputs)
      
      # Format inputs and outputs for display
      input_str = inputs |> Enum.map(&format_number/1) |> Enum.join(", ")
      output_str = outputs |> Enum.map(&format_number/1) |> Enum.join(", ")
      expected_str = expected |> Enum.map(&format_number/1) |> Enum.join(", ")
      
      # Calculate and format error
      error = Enum.zip(outputs, expected)
              |> Enum.map(fn {o, e} -> abs(o - e) end)
              |> Enum.sum()
              |> format_number()
      
      IO.puts("Input: [#{input_str}] => Output: [#{output_str}] (Expected: [#{expected_str}], Error: #{error})")
    end)
  end
  
  # Show XOR results for a given genotype
  defp show_xor_results(genotype) do
    nn = Cortex.from_genotype(genotype)
    display_xor_results(nn)
  end
  
  # Format a number for display
  defp format_number(num) do
    :erlang.float_to_binary(1.0 * num, decimals: 4)
  end
end