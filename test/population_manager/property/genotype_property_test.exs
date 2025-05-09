defmodule Bardo.PopulationManager.GenotypePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Bardo.PopulationManager.{Genotype, GenomeMutator}
  
  # Generators for genotype components
  
  # Generate a valid layer type
  def layer_generator do
    StreamData.member_of([:input, :hidden, :output, :bias])
  end
  
  # Generate a valid activation function
  def activation_function_generator do
    StreamData.member_of([:sigmoid, :tanh, :relu, :identity, :sin, :gaussian, :step])
  end
  
  # Generate a valid weight
  def weight_generator do
    StreamData.float(min: -5.0, max: 5.0)
  end
  
  # Generate a valid neuron ID
  def neuron_id_generator do
    StreamData.map(
      StreamData.string(:alphanumeric, min_length: 5, max_length: 10),
      &("neuron_#{&1}")
    )
  end
  
  # Generate a valid neuron with specified layer
  def neuron_generator(layer) do
    StreamData.map(
      activation_function_generator(),
      fn activation_function ->
        %{
          layer: layer,
          activation_function: activation_function
        }
      end
    )
  end
  
  # Generate a connection between neurons
  def connection_generator(from_id, to_id) do
    StreamData.map(
      weight_generator(),
      fn weight ->
        %{
          from_id: from_id,
          to_id: to_id,
          weight: weight
        }
      end
    )
  end
  
  # Generate a minimal valid genotype
  def minimal_genotype_generator do
    StreamData.map(
      {neuron_id_generator(), neuron_id_generator(), neuron_id_generator()},
      fn {input_id, hidden_id, output_id} ->
        %{
          neurons: %{
            input_id => %{layer: :input, activation_function: :sigmoid},
            hidden_id => %{layer: :hidden, activation_function: :tanh},
            output_id => %{layer: :output, activation_function: :sigmoid}
          },
          connections: %{
            "connection_1" => %{from_id: input_id, to_id: hidden_id, weight: 0.5},
            "connection_2" => %{from_id: hidden_id, to_id: output_id, weight: 0.3}
          },
          next_neuron_id: 4,
          next_connection_id: 3
        }
      end
    )
  end
  
  # Generate a more complex genotype
  def complex_genotype_generator do
    # We'll build a genotype with multiple inputs, hidden neurons and outputs
    inputs = StreamData.list_of(
      neuron_id_generator(), min_length: 1, max_length: 3
    )
    hidden = StreamData.list_of(
      neuron_id_generator(), min_length: 1, max_length: 5
    )
    outputs = StreamData.list_of(
      neuron_id_generator(), min_length: 1, max_length: 2
    )
    
    StreamData.bind(
      {inputs, hidden, outputs},
      fn {input_ids, hidden_ids, output_ids} ->
        # Ensure all IDs are unique
        all_ids = input_ids ++ hidden_ids ++ output_ids
        if length(all_ids) != length(Enum.uniq(all_ids)) do
          StreamData.constant(:invalid)
        else
          # Create neurons
          neurons = 
            Enum.map(input_ids, fn id -> {id, %{layer: :input, activation_function: :sigmoid}} end) ++
            Enum.map(hidden_ids, fn id -> {id, %{layer: :hidden, activation_function: :tanh}} end) ++
            Enum.map(output_ids, fn id -> {id, %{layer: :output, activation_function: :sigmoid}} end)
            |> Map.new()
          
          # Create connections - each input connects to each hidden, each hidden to each output
          connection_id = 1
          connections = 
            for from_id <- input_ids, to_id <- hidden_ids do
              {connection_id, from_id, to_id}
            end ++
            for from_id <- hidden_ids, to_id <- output_ids do
              {connection_id + length(input_ids) * length(hidden_ids), from_id, to_id}
            end
          
          connections_map = 
            connections
            |> Enum.with_index(1)
            |> Enum.map(fn {{_id, from_id, to_id}, idx} -> 
              {"connection_#{idx}", %{from_id: from_id, to_id: to_id, weight: :rand.uniform() * 2 - 1}}
            end)
            |> Map.new()
          
          StreamData.constant(%{
            neurons: neurons,
            connections: connections_map,
            next_neuron_id: length(all_ids) + 1,
            next_connection_id: length(connections) + 1
          })
        end
      end
    )
    |> StreamData.filter(fn x -> x != :invalid end)
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
    
    if !valid_structure, do: (IO.puts("Invalid structure"); false), else: true
      
    # Neuron checks
    neurons_valid = 
      Enum.all?(genotype.neurons, fn {_id, neuron} ->
        is_map(neuron) && 
        neuron.layer in [:input, :hidden, :output, :bias] &&
        is_atom(neuron.activation_function)
      end)
    
    if !neurons_valid, do: (IO.puts("Invalid neurons"); false), else: true
      
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
  
  # Test that the new function creates a valid genotype
  @tag property: true
  property "new/0 creates a valid empty genotype" do
    genotype = Genotype.new()
    
    assert is_map(genotype)
    assert is_map(genotype.neurons)
    assert is_map(genotype.connections)
    assert genotype.next_neuron_id == 1
    assert genotype.next_connection_id == 1
    assert map_size(genotype.neurons) == 0
    assert map_size(genotype.connections) == 0
  end
  
  # Test that add_neuron maintains genotype validity
  @tag property: true
  property "add_neuron/3 creates valid neurons" do
    check all(
      layer <- layer_generator(),
      activation_function <- activation_function_generator()
    ) do
      genotype = Genotype.new()
      updated = Genotype.add_neuron(genotype, layer, %{activation_function: activation_function})
      
      assert map_size(updated.neurons) == 1
      neuron_id = "neuron_#{genotype.next_neuron_id}"
      assert Map.has_key?(updated.neurons, neuron_id)
      assert updated.neurons[neuron_id].layer == layer
      assert updated.neurons[neuron_id].activation_function == activation_function
      assert updated.next_neuron_id == genotype.next_neuron_id + 1
    end
  end
  
  # Test that add_connection maintains genotype validity
  @tag property: true
  property "add_connection/4 creates valid connections" do
    check all genotype <- minimal_genotype_generator() do
      # Pick random input and output neurons
      input_id = genotype.neurons 
                |> Enum.filter(fn {_id, n} -> n.layer == :input end) 
                |> Enum.map(fn {id, _} -> id end)
                |> Enum.at(0)
      
      output_id = genotype.neurons 
                |> Enum.filter(fn {_id, n} -> n.layer == :output end) 
                |> Enum.map(fn {id, _} -> id end)
                |> Enum.at(0)
      
      # Connect them directly
      weight = :rand.uniform() * 2 - 1
      updated = Genotype.add_connection(genotype, input_id, output_id, weight)
      
      # Check the new connection
      connection_id = "connection_#{genotype.next_connection_id}"
      assert Map.has_key?(updated.connections, connection_id)
      assert updated.connections[connection_id].from_id == input_id
      assert updated.connections[connection_id].to_id == output_id
      assert updated.connections[connection_id].weight == weight
      assert updated.next_connection_id == genotype.next_connection_id + 1
    end
  end
  
  # Test that mutations maintain genotype validity
  @tag property: true
  property "simple_mutate/2 produces valid genotypes" do
    check all genotype <- complex_genotype_generator() do
      opts = %{
        add_neuron_probability: 0.2,
        add_link_probability: 0.3,
        mutate_weights_probability: 0.8
      }
      
      mutated = GenomeMutator.simple_mutate(genotype, opts)
      assert is_valid_genotype?(mutated)
      
      # Structural changes should preserve connectivity
      input_neurons = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> length()
        
      output_neurons = 
        mutated.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> length()
        
      # Input and output layers should remain unchanged
      input_neurons_orig = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> length()
        
      output_neurons_orig = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> length()
        
      assert input_neurons == input_neurons_orig
      assert output_neurons == output_neurons_orig
      
      # Mutations may add new neurons or connections
      assert map_size(mutated.neurons) >= map_size(genotype.neurons)
      assert map_size(mutated.connections) >= map_size(genotype.connections)
    end
  end
  
  # Test that get_layer_neuron_ids/2 returns correct neurons
  @tag property: true
  property "get_layer_neuron_ids/2 returns correct neurons for each layer" do
    check all genotype <- complex_genotype_generator() do
      input_ids = Genotype.get_layer_neuron_ids(genotype, :input)
      hidden_ids = Genotype.get_layer_neuron_ids(genotype, :hidden)
      output_ids = Genotype.get_layer_neuron_ids(genotype, :output)
      
      # All returned IDs should exist in the genotype
      assert Enum.all?(input_ids, &Map.has_key?(genotype.neurons, &1))
      assert Enum.all?(hidden_ids, &Map.has_key?(genotype.neurons, &1))
      assert Enum.all?(output_ids, &Map.has_key?(genotype.neurons, &1))
      
      # They should be in the correct layers
      assert Enum.all?(input_ids, fn id -> genotype.neurons[id].layer == :input end)
      assert Enum.all?(hidden_ids, fn id -> genotype.neurons[id].layer == :hidden end)
      assert Enum.all?(output_ids, fn id -> genotype.neurons[id].layer == :output end)
      
      # All neurons of each layer should be included
      genotype_input_count = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :input end)
        |> length()
        
      genotype_hidden_count = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :hidden end)
        |> length()
        
      genotype_output_count = 
        genotype.neurons
        |> Enum.filter(fn {_id, n} -> n.layer == :output end)
        |> length()
        
      assert length(input_ids) == genotype_input_count
      assert length(hidden_ids) == genotype_hidden_count
      assert length(output_ids) == genotype_output_count
    end
  end
end