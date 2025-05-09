defmodule Bardo.PopulationManager.GenomeMutatorPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  # Define our generators and helpers inline to avoid dependency issues

  # Generate a valid weight
  def weight_generator do
    StreamData.float(min: -5.0, max: 5.0)
  end

  # Generate a basic genotype for testing
  def complex_genotype_generator do
    # Create a minimal valid genotype with 1 input, 1 hidden, and 1 output neuron
    genotype = %{
      neurons: %{
        "input_1" => %{layer: :input, activation_function: :sigmoid},
        "hidden_1" => %{layer: :hidden, activation_function: :tanh},
        "output_1" => %{layer: :output, activation_function: :sigmoid}
      },
      connections: %{
        "connection_1" => %{from_id: "input_1", to_id: "hidden_1", weight: 0.5},
        "connection_2" => %{from_id: "hidden_1", to_id: "output_1", weight: 0.3}
      },
      next_neuron_id: 4,
      next_connection_id: 3
    }

    StreamData.constant(genotype)
  end

  # Validator function to check if a genotype is valid
  def is_valid_genotype?(genotype) do
    # Basic structure checks
    valid_structure =
      is_map(genotype) &&
      is_map(genotype.neurons) &&
      is_map(genotype.connections) &&
      is_integer(genotype.next_neuron_id) &&
      is_integer(genotype.next_connection_id)

    # Neuron checks
    neurons_valid =
      Enum.all?(genotype.neurons, fn {_id, neuron} ->
        is_map(neuron) &&
        neuron.layer in [:input, :hidden, :output, :bias] &&
        is_atom(neuron.activation_function)
      end)

    # Connection checks
    connections_valid =
      Enum.all?(genotype.connections, fn {_id, connection} ->
        is_map(connection) &&
        is_binary(connection.from_id) &&
        is_binary(connection.to_id) &&
        is_number(connection.weight) &&
        # Source exists
        Map.has_key?(genotype.neurons, connection.from_id) &&
        # Target exists
        Map.has_key?(genotype.neurons, connection.to_id) &&
        # Can't connect to input layer
        genotype.neurons[connection.to_id].layer != :input &&
        # Can't connect from output layer
        genotype.neurons[connection.from_id].layer != :output
      end)

    valid_structure && neurons_valid && connections_valid
  end
  
  # Test that all possible mutation probabilities work correctly
  @tag property: true
  property "simple_mutate handles all probability combinations" do
    check all(
      genotype <- complex_genotype_generator(),
      add_neuron_prob <- StreamData.float(min: 0.0, max: 1.0),
      add_link_prob <- StreamData.float(min: 0.0, max: 1.0),
      mutate_weights_prob <- StreamData.float(min: 0.0, max: 1.0)
    ) do
      opts = %{
        add_neuron_probability: add_neuron_prob,
        add_link_probability: add_link_prob,
        mutate_weights_probability: mutate_weights_prob
      }
      
      mutated = GenomeMutator.simple_mutate(genotype, opts)
      
      # The mutated genotype should always be valid
      assert is_valid_genotype?(mutated)
      
      # Input and output neurons should be preserved
      input_neurons_before = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> length()
        
      output_neurons_before = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> length()
        
      input_neurons_after = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> length()
        
      output_neurons_after = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> length()
        
      assert input_neurons_before == input_neurons_after
      assert output_neurons_before == output_neurons_after
      
      # The structure should never decrease in size from mutations
      assert map_size(mutated.neurons) >= map_size(genotype.neurons)
      assert map_size(mutated.connections) >= map_size(genotype.connections)
    end
  end
  
  # Test that neuron addition creates valid neuron and connections
  @tag property: true
  property "adding neurons preserves network connectivity" do
    check all genotype <- complex_genotype_generator() do
      # Force a neuron addition mutation
      mutated = GenomeMutator.simple_mutate(genotype, %{
        add_neuron_probability: 1.0,  # 100% chance of adding neuron
        add_link_probability: 0.0,
        mutate_weights_probability: 0.0
      })
      
      # Since we're adding a neuron, the count should increase
      assert map_size(mutated.neurons) > map_size(genotype.neurons)
      
      # For each neuron added, we should have AT LEAST 2 new connections
      # (since we're replacing one connection with two)
      neuron_diff = map_size(mutated.neurons) - map_size(genotype.neurons)
      connection_diff = map_size(mutated.connections) - map_size(genotype.connections)
      assert connection_diff >= neuron_diff
      
      # Validate that the network is still properly connected
      # Every output neuron should be reachable from an input neuron
      output_ids = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> Enum.map(fn {id, _} -> id end)
        
      input_ids = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> Enum.map(fn {id, _} -> id end)
        
      # Check connectivity from inputs to outputs
      # For each output, there should be at least one path from an input
      for output_id <- output_ids do
        assert connected_to_input?(mutated, output_id, input_ids)
      end
    end
  end
  
  # Test that link addition creates valid connections
  @tag property: true
  property "adding links maintains valid network structure" do
    check all genotype <- complex_genotype_generator() do
      # Force a link addition mutation
      mutated = GenomeMutator.simple_mutate(genotype, %{
        add_neuron_probability: 0.0,
        add_link_probability: 1.0,  # 100% chance of adding link
        mutate_weights_probability: 0.0
      })
      
      # Neuron count should remain the same
      assert map_size(mutated.neurons) == map_size(genotype.neurons)
      
      # Connection count should increase or stay the same
      # (might stay the same if all possible connections already exist)
      assert map_size(mutated.connections) >= map_size(genotype.connections)
      
      # Check that all connections are valid
      Enum.each(mutated.connections, fn {_id, connection} ->
        # Source and target neurons should exist
        assert Map.has_key?(mutated.neurons, connection.from_id)
        assert Map.has_key?(mutated.neurons, connection.to_id)
        
        # Source shouldn't be an output neuron
        assert mutated.neurons[connection.from_id].layer != :output
        
        # Target shouldn't be an input neuron
        assert mutated.neurons[connection.to_id].layer != :input
      end)
    end
  end
  
  # Test that weight mutation only changes weights, not structure
  @tag property: true
  property "weight mutation preserves network structure" do
    check all genotype <- complex_genotype_generator() do
      # Force just weight mutations
      mutated = GenomeMutator.simple_mutate(genotype, %{
        add_neuron_probability: 0.0,
        add_link_probability: 0.0,
        mutate_weights_probability: 1.0  # 100% chance of mutating weights
      })
      
      # Structure should be identical
      assert map_size(mutated.neurons) == map_size(genotype.neurons)
      assert map_size(mutated.connections) == map_size(genotype.connections)
      
      # Same connection IDs should be preserved
      connection_ids = Map.keys(genotype.connections)
      mutated_connection_ids = Map.keys(mutated.connections)
      assert Enum.sort(connection_ids) == Enum.sort(mutated_connection_ids)
      
      # Same neuron IDs should be preserved
      neuron_ids = Map.keys(genotype.neurons)
      mutated_neuron_ids = Map.keys(mutated.neurons)
      assert Enum.sort(neuron_ids) == Enum.sort(mutated_neuron_ids)
      
      # At least one weight should be different (high probability)
      # Compare weights
      weight_changes = 
        Enum.map(connection_ids, fn id ->
          original_weight = genotype.connections[id].weight
          mutated_weight = mutated.connections[id].weight
          original_weight != mutated_weight
        end)
        |> Enum.filter(&(&1))
      
      # With high probability at least one weight changed, but not guaranteed
      # due to the Gaussian nature of perturbations
      # This is why we don't assert on it - but we check during debugging
      _changed_weights = length(weight_changes)
    end
  end
  
  # Test that multiple mutations produce valid structure
  @tag property: true
  property "multiple mutations maintain network validity" do
    check all(
      genotype <- complex_genotype_generator(),
      iterations <- StreamData.integer(1..5)
    ) do
      # Apply multiple generations of mutations
      final_genotype = 
        Enum.reduce(1..iterations, genotype, fn _, g ->
          GenomeMutator.simple_mutate(g, %{
            add_neuron_probability: 0.3,
            add_link_probability: 0.3,
            mutate_weights_probability: 0.8
          })
        end)
      
      # Final genotype should be valid
      assert is_valid_genotype?(final_genotype)
      
      # Network should grow or at least maintain the same size
      assert map_size(final_genotype.neurons) >= map_size(genotype.neurons)
      assert map_size(final_genotype.connections) >= map_size(genotype.connections)
      
      # Connections should follow layer constraints
      Enum.each(final_genotype.connections, fn {_id, connection} ->
        from_layer = final_genotype.neurons[connection.from_id].layer
        to_layer = final_genotype.neurons[connection.to_id].layer
        
        # No connections TO input layer
        assert to_layer != :input
        
        # No connections FROM output layer
        assert from_layer != :output
      end)
    end
  end
  
  # Helper function to check if a neuron is connected to an input
  defp connected_to_input?(genotype, neuron_id, input_ids) do
    incoming_connections = 
      genotype.connections
      |> Enum.filter(fn {_id, conn} -> conn.to_id == neuron_id end)
      |> Enum.map(fn {_id, conn} -> conn.from_id end)
    
    # Direct connection to input  
    direct_input_connection = Enum.any?(incoming_connections, &(&1 in input_ids))
    
    if direct_input_connection do
      true
    else
      # Check indirect connections through other neurons
      Enum.any?(incoming_connections, fn from_id ->
        genotype.neurons[from_id].layer != :output && # Skip if output (shouldn't happen anyway)
        connected_to_input?(genotype, from_id, input_ids)
      end)
    end
  end
end