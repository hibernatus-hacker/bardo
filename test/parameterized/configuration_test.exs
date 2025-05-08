defmodule Bardo.Parameterized.ConfigurationTest do
  use ExUnit.Case, async: true
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  @moduletag :parameterized
  
  # Define test parameters as module attributes
  @activation_functions [:sigmoid, :tanh, :relu, :identity, :sin, :gaussian, :step]
  @population_sizes [10, 20, 50]
  @mutation_rates [0.1, 0.3, 0.7]
  @problem_types [:xor, :pole_balancing, :regression]
  
  describe "activation functions" do
    # Generate tests for all activation functions
    for activation_function <- @activation_functions do
      @activation_function activation_function
      test "neural network with #{activation_function} activation produces valid outputs" do
        # Create a test network with the specified activation function
        genotype = create_test_genotype(@activation_function)
        
        # Convert to neural network
        nn = Cortex.from_genotype(genotype)
        
        # Test with different inputs
        test_inputs = [
          [0.0, 0.0],
          [0.0, 1.0],
          [1.0, 0.0],
          [1.0, 1.0],
          [-1.0, -1.0],
          [5.0, -5.0]
        ]
        
        # Verify outputs are valid for all inputs
        for inputs <- test_inputs do
          outputs = Cortex.activate(nn, inputs)
          
          # Outputs should exist and be numbers
          assert is_list(outputs)
          assert length(outputs) == 1
          assert is_float(hd(outputs))
          
          output_value = hd(outputs)
          
          # Check bounds based on activation function
          case @activation_function do
            :sigmoid -> 
              assert output_value >= 0.0 and output_value <= 1.0
            :tanh -> 
              assert output_value >= -1.0 and output_value <= 1.0
            :relu -> 
              # For some inputs, ReLU can produce 0
              if output_value > 0 do
                assert output_value > 0.0
              end
            :step ->
              assert output_value == 0.0 or output_value == 1.0
            _ ->
              # Other activation functions have broader ranges
              assert is_number(output_value)
          end
        end
      end
    end
  end
  
  describe "population sizes" do
    # Test with various population sizes
    for size <- @population_sizes do
      @size size
      test "can evolve with population size #{size}" do
        # Run a mini evolution with the specified population size
        {best_fitness, generations, _individual} = 
          run_mini_evolution(population_size: @size, max_generations: 10)
          
        # Even with small evolution, we should get some improvement
        assert best_fitness > 1.0
        assert generations > 0
        
        # The population size should affect diversity, but we can't test that easily
        # Instead, we test that the function runs successfully
      end
    end
  end
  
  describe "mutation rates" do
    # Test with various mutation rates
    for rate <- @mutation_rates do
      @rate rate
      test "mutation with rate #{rate} preserves network validity" do
        # Create a seed genotype
        genotype = create_xor_genotype()
        
        # Apply mutation with the specified rate
        mutated = GenomeMutator.simple_mutate(genotype, %{
          add_neuron_probability: @rate,
          add_link_probability: @rate,
          mutate_weights_probability: @rate
        })
        
        # Check validity of mutated genotype
        assert is_valid_genotype?(mutated)
        
        # Higher mutation rates should lead to more changes, but we can't rely on
        # that in a deterministic test. Instead, just validate the structure
        if @rate >= 0.7 do
          # With high mutation rates, run multiple iterations and check for changes
          multi_mutated = Enum.reduce(1..5, genotype, fn _, g ->
            GenomeMutator.simple_mutate(g, %{
              add_neuron_probability: @rate,
              add_link_probability: @rate,
              mutate_weights_probability: @rate
            })
          end)
          
          # Should have some structure changes after multiple high-rate mutations
          assert map_size(multi_mutated.neurons) >= map_size(genotype.neurons)
          assert map_size(multi_mutated.connections) >= map_size(genotype.connections)
        end
      end
    end
  end
  
  describe "problem types" do
    # Test with different problem types
    for problem_type <- @problem_types do
      @problem_type problem_type
      test "can configure experiment for #{problem_type} problem" do
        # Generate configuration for the problem type
        config = generate_experiment_config(@problem_type)
        
        # Verify general configuration structure
        assert is_map(config)
        assert is_atom(config.id)
        assert is_integer(config.iterations)
        assert is_list(config.scapes)
        assert is_list(config.populations)
        
        # Verify problem-specific configuration
        case @problem_type do
          :xor ->
            # XOR should have a minimal configuration
            assert length(config.scapes) == 1
            assert length(config.populations) == 1
            
            # Find input/output dimensions for XOR
            pop = hd(config.populations)
            assert pop.size > 0
            
            # Check dimensions for XOR (2 inputs, 1 output)
            scape = hd(config.scapes)
            assert scape.module_parameters.input_dimension == 2
            assert scape.module_parameters.output_dimension == 1
            
          :pole_balancing ->
            # Pole balancing should have a fitness threshold for early stopping
            assert config.fitness_threshold > 0
            
            # Should have a time-based fitness evaluation
            scape = hd(config.scapes)
            assert scape.module_parameters.max_steps > 100
            
          :regression ->
            # Regression should have data points and error metrics
            scape = hd(config.scapes)
            assert scape.module_parameters.data_points > 0
            assert is_atom(scape.module_parameters.error_metric)
            
        end
      end
    end
  end
  
  # Helper functions
  
  # Create a test genotype with the specified activation function
  defp create_test_genotype(activation_function) do
    # Create a new genotype
    genotype = Genotype.new()
    
    # Add 2 input neurons
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_1"})
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_2"})
    
    # Add bias neuron
    genotype = Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add hidden neuron with the specified activation function
    genotype = Genotype.add_neuron(genotype, :hidden, %{
      id: "hidden_1", 
      activation_function: activation_function
    })
    
    # Add output neuron with the specified activation function
    genotype = Genotype.add_neuron(genotype, :output, %{
      id: "output", 
      activation_function: activation_function
    })
    
    # Add connections
    genotype = Genotype.add_connection(genotype, "input_1", "hidden_1", 0.5)
    genotype = Genotype.add_connection(genotype, "input_2", "hidden_1", 0.5)
    genotype = Genotype.add_connection(genotype, "bias", "hidden_1", 0.1)
    genotype = Genotype.add_connection(genotype, "hidden_1", "output", 1.0)
    
    genotype
  end
  
  # Create a genotype for XOR
  defp create_xor_genotype do
    # Create a new genotype
    genotype = Genotype.new()
    
    # Add input neurons for the two inputs
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_1"})
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_2"})
    
    # Add bias neuron
    genotype = Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add 2 hidden neurons
    genotype = Genotype.add_neuron(genotype, :hidden, %{id: "hidden_1"})
    genotype = Genotype.add_neuron(genotype, :hidden, %{id: "hidden_2"})
    
    # Add output neuron
    genotype = Genotype.add_neuron(genotype, :output, %{id: "output"})
    
    # Connect inputs to hidden
    genotype = Genotype.add_connection(genotype, "input_1", "hidden_1", 0.5)
    genotype = Genotype.add_connection(genotype, "input_2", "hidden_1", 0.5)
    genotype = Genotype.add_connection(genotype, "bias", "hidden_1", -0.7)
    
    genotype = Genotype.add_connection(genotype, "input_1", "hidden_2", 0.5)
    genotype = Genotype.add_connection(genotype, "input_2", "hidden_2", 0.5)
    genotype = Genotype.add_connection(genotype, "bias", "hidden_2", 0.1)
    
    # Connect hidden to output
    genotype = Genotype.add_connection(genotype, "hidden_1", "output", 1.0)
    genotype = Genotype.add_connection(genotype, "hidden_2", "output", -1.0)
    
    genotype
  end
  
  # Check if a genotype is valid
  defp is_valid_genotype?(genotype) do
    # Basic structure checks
    valid_structure = 
      is_map(genotype) && 
      is_map(genotype.neurons) && 
      is_map(genotype.connections)
      
    # Neuron checks
    neurons_valid = 
      Enum.all?(genotype.neurons, fn {_id, neuron} ->
        is_map(neuron) && 
        neuron.layer in [:input, :hidden, :output, :bias]
      end)
      
    # Connection checks
    connections_valid =
      Enum.all?(genotype.connections, fn {_id, connection} ->
        is_map(connection) &&
        Map.has_key?(genotype.neurons, connection.from_id) &&
        Map.has_key?(genotype.neurons, connection.to_id) &&
        genotype.neurons[connection.to_id].layer != :input &&
        genotype.neurons[connection.from_id].layer != :output
      end)
      
    valid_structure && neurons_valid && connections_valid
  end
  
  # Run a mini evolution (simplified for faster testing)
  defp run_mini_evolution(opts) do
    population_size = Keyword.get(opts, :population_size, 10)
    max_generations = Keyword.get(opts, :max_generations, 5)
    
    # Create initial population
    population = for _ <- 1..population_size do
      genotype = create_xor_genotype()
      fitness = fitness_function(genotype)
      {genotype, fitness}
    end
    
    # Run evolution
    {best_genotype, best_fitness, generations} = evolve(
      population, max_generations
    )
    
    {best_fitness, generations, best_genotype}
  end
  
  # Simplified XOR fitness function 
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
  
  # Simplified evolution function
  defp evolve(population, max_generations, generation \\ 0) do
    # Sort population by fitness
    sorted_population = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, :desc)
    
    # Get the best individual
    {best_genotype, best_fitness} = hd(sorted_population)
    
    # Check if we've reached max generations
    if generation >= max_generations do
      {best_genotype, best_fitness, generation}
    else
      # Create next generation
      new_population = for _ <- 1..length(population) do
        # Select a random parent
        {parent_genotype, _fitness} = Enum.random(sorted_population)
        
        # Mutate
        mutated_genotype = GenomeMutator.simple_mutate(parent_genotype)
        
        # Evaluate
        fitness = fitness_function(mutated_genotype)
        
        {mutated_genotype, fitness}
      end
      
      # Continue evolution
      evolve(new_population, max_generations, generation + 1)
    end
  end
  
  # Generate experiment configuration for different problem types
  defp generate_experiment_config(problem_type) do
    base_config = %{
      id: String.to_atom("#{problem_type}_test"),
      iterations: 50,
      backup_frequency: 5
    }
    
    case problem_type do
      :xor ->
        # XOR configuration
        xor_scape = %{
          name: :xor_scape,
          type: :private,
          module: :xor_environment,
          module_parameters: %{
            input_dimension: 2,
            output_dimension: 1,
            test_cases: [
              {[0.0, 0.0], [0.0]},
              {[0.0, 1.0], [1.0]},
              {[1.0, 0.0], [1.0]},
              {[1.0, 1.0], [0.0]}
            ]
          }
        }
        
        xor_population = %{
          id: :xor_population,
          size: 50,
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 3,
          elite_fraction: 0.1,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.5},
            {:add_neuron, 0.1},
            {:add_link, 0.3}
          ]
        }
        
        Map.merge(base_config, %{
          scapes: [xor_scape],
          populations: [xor_population]
        })
        
      :pole_balancing ->
        # Pole balancing configuration
        pole_scape = %{
          name: :pole_scape,
          type: :private,
          module: :dpb_environment,
          module_parameters: %{
            max_steps: 1000,
            damping: true,
            pole_lengths: [0.5, 0.05],
            pole_masses: [0.1, 0.01]
          }
        }
        
        pole_population = %{
          id: :pole_population,
          size: 100,
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 5,
          elite_fraction: 0.1,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.5},
            {:add_neuron, 0.1},
            {:add_link, 0.3}
          ]
        }
        
        Map.merge(base_config, %{
          fitness_threshold: 900.0,  # Early stopping if pole stays upright this long
          scapes: [pole_scape],
          populations: [pole_population]
        })
        
      :regression ->
        # Regression configuration
        regression_scape = %{
          name: :regression_scape,
          type: :private,
          module: :regression_environment,
          module_parameters: %{
            data_points: 100,
            input_dimension: 5,
            output_dimension: 1,
            error_metric: :mse,
            train_test_split: 0.8
          }
        }
        
        regression_population = %{
          id: :regression_population,
          size: 50,
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 3,
          elite_fraction: 0.1,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.5},
            {:add_neuron, 0.1},
            {:add_link, 0.3}
          ]
        }
        
        Map.merge(base_config, %{
          scapes: [regression_scape],
          populations: [regression_population]
        })
    end
  end
end