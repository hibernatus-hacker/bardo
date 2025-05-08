defmodule Bardo.Integration.EvolutionaryXorTest do
  use ExUnit.Case, async: true
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  @moduletag :integration
  @moduletag timeout: 60000  # Allow up to 60 seconds for this test
  
  describe "XOR evolutionary process" do
    test "can evolve a solution to XOR problem" do
      # Configuration
      population_size = 20  # Small population for faster tests
      max_generations = 100
      
      # Create initial population
      population = create_initial_population(population_size)
      
      # Track progress
      generations_record = []
      
      # Define test cases for XOR
      test_cases = [
        {[0.0, 0.0], [0.0]},
        {[0.0, 1.0], [1.0]},
        {[1.0, 0.0], [1.0]},
        {[1.0, 1.0], [0.0]}
      ]
      
      # Evolve the population with early stopping if solution found
      {best_genotype, best_fitness, generation, fitness_history} = 
        evolve(population, max_generations, test_cases, generations_record)
      
      # Convert best genotype to neural network
      nn = Cortex.from_genotype(best_genotype)
      
      # Verify results
      IO.puts("\nEvolution completed after #{generation} generations")
      IO.puts("Best fitness: #{best_fitness}")
      IO.puts("\nTesting best solution on XOR:")
      
      # Test network on all XOR cases
      results = 
        Enum.map(test_cases, fn {inputs, expected} ->
          # Activate the network
          outputs = Cortex.activate(nn, inputs)
          
          # Calculate error
          error = 
            Enum.zip(outputs, expected)
            |> Enum.map(fn {output, target} -> abs(output - target) end)
            |> Enum.sum()
          
          # Format for output
          %{
            inputs: inputs,
            outputs: outputs,
            expected: expected,
            error: error
          }
        end)
      
      # Display results
      Enum.each(results, fn result ->
        inputs_str = Enum.map(result.inputs, &format_number/1) |> Enum.join(", ")
        outputs_str = Enum.map(result.outputs, &format_number/1) |> Enum.join(", ")
        expected_str = Enum.map(result.expected, &format_number/1) |> Enum.join(", ")
        
        IO.puts("Input: [#{inputs_str}] => Output: [#{outputs_str}] (Expected: [#{expected_str}], Error: #{format_number(result.error)})")
      end)
      
      # Calculate total error
      total_error = Enum.reduce(results, 0.0, fn result, acc -> acc + result.error end)
      
      # Assert that evolution succeeded in finding a good solution
      # Success criteria: average error per output < 0.2
      avg_error = total_error / length(results)
      assert avg_error < 0.2, "Evolution did not find a good solution (avg error: #{avg_error})"
      
      # Track convergence
      assert length(fitness_history) <= max_generations
      assert length(fitness_history) > 0
      assert best_fitness > 3.5, "Solution fitness (#{best_fitness}) is too low"
      
      # Verify neural network structure
      assert map_size(best_genotype.neurons) >= 4, "Network is too simple"
      
      # Create a graph showing the fitness over generations for manual review
      if generation > 1 do
        IO.puts("\nFitness progression:")
        IO.puts(generate_ascii_chart(fitness_history, 40, 10))
      end
    end
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
  
  # XOR test cases
  defp xor_test_cases do
    [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
  end
  
  # Fitness function for XOR
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
  
  # Evolve the population
  defp evolve(population, max_generations, test_cases, generations_record, generation \\ 0) do
    # Sort population by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Get the best individual
    {best_genotype, best_fitness} = hd(sorted_population)
    
    # Add fitness to history
    updated_record = [best_fitness | generations_record]
    
    # Check if we've found a solution or reached max generations
    cond do
      best_fitness >= 3.95 ->
        # Found good solution
        {best_genotype, best_fitness, generation + 1, Enum.reverse(updated_record)}
        
      generation >= max_generations ->
        # Reached max generations
        {best_genotype, best_fitness, generation, Enum.reverse(updated_record)}
        
      true ->
        # Show progress every 10 generations
        if rem(generation, 10) == 0 do
          IO.write(".")
        end
        
        # Continue evolution
        new_population = next_generation(sorted_population, length(population), test_cases)
        evolve(new_population, max_generations, test_cases, updated_record, generation + 1)
    end
  end
  
  # Create the next generation
  defp next_generation(sorted_population, population_size, test_cases) do
    # Keep the top 25% (elitism)
    elite_count = max(2, floor(population_size * 0.25))
    elites = Enum.take(sorted_population, elite_count)
    
    # Create offspring to fill the population
    offspring_count = population_size - elite_count
    
    offspring = for _ <- 1..offspring_count do
      # Select a parent using tournament selection
      parent_genotype = select_parent(sorted_population)
      
      # Create a mutated offspring
      mutated_genotype = GenomeMutator.simple_mutate(parent_genotype, %{
        add_neuron_probability: 0.1,
        add_link_probability: 0.3,
        mutate_weights_probability: 0.8
      })
      
      # Evaluate the new genotype
      fitness = fitness_function(mutated_genotype, test_cases)
      
      # Return the genotype and its fitness
      {mutated_genotype, fitness}
    end
    
    # Combine elites and offspring
    elites ++ offspring
  end
  
  # Tournament selection
  defp select_parent(population) do
    tournament_size = min(3, floor(length(population) / 2))
    
    # Select random individuals for tournament
    tournament = 
      Enum.take_random(population, tournament_size)
      |> Enum.sort_by(fn {_genotype, fitness} -> fitness end, :desc)
    
    # Return winner's genotype
    {genotype, _fitness} = hd(tournament)
    genotype
  end
  
  # Format a number for display
  defp format_number(num) do
    :io_lib.format("~.4f", [1.0 * num]) |> to_string()
  end
  
  # Generate a simple ASCII chart for the fitness history
  defp generate_ascii_chart(values, width, height) do
    # Find min and max values
    min_value = Enum.min(values)
    max_value = Enum.max(values)
    value_range = max(0.001, max_value - min_value)  # Avoid division by zero
    
    # Normalize values to fit in the height
    normalized = 
      Enum.map(values, fn value -> 
        round((value - min_value) / value_range * (height - 1))
      end)
    
    # Generate rows
    rows = 
      for row <- (height-1)..0 do
        # Create a row of the chart
        row_chars = 
          Enum.map(normalized, fn norm_value -> 
            if norm_value >= row, do: "*", else: " "
          end)
          |> Enum.take(width)  # Limit width
        
        # Add y-axis label for some rows
        y_label = 
          cond do
            row == height - 1 -> format_number(max_value)
            row == 0 -> format_number(min_value)
            row == div(height - 1, 2) -> format_number(min_value + value_range / 2)
            true -> ""
          end
        
        # Pad the label for alignment
        y_label_padded = String.pad_leading(y_label, 8)
        
        # Combine label and row
        y_label_padded <> " |" <> Enum.join(row_chars, "")
      end
    
    # Add x-axis
    x_axis = String.pad_leading("", 10) <> String.duplicate("-", Enum.min([width, length(normalized)]))
    
    # Add generation labels
    first_gen = "0"
    last_gen = to_string(length(values) - 1)
    middle_gen = to_string(div(length(values) - 1, 2))
    
    x_labels = String.pad_leading("", 10) <> first_gen <> 
               String.pad_leading(middle_gen, div(width, 2) - String.length(first_gen)) <> 
               String.pad_leading(last_gen, width - div(width, 2) - String.length(middle_gen))
    
    # Combine all parts
    Enum.join(rows, "\n") <> "\n" <> x_axis <> "\n" <> x_labels
  end
end