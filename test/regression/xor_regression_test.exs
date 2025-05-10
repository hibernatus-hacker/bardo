defmodule Bardo.Regression.XorRegressionTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Simple.Xor
  alias Bardo.AgentManager.Cortex
  
  @moduletag :regression
  
  describe "XOR example" do
    test "run/1 evolves a solution to the XOR problem" do
      # Define small parameters for faster testing
      opts = [
        population_size: 20,
        max_generations: 50,
        show_progress: false
      ]
      
      # Run the XOR example
      nn = Xor.run(opts)
      
      # Check that a neural network was returned
      assert is_map(nn)
      assert is_map(nn.neurons)
      assert is_map(nn.connections)
      
      # Test the evolved network on XOR inputs
      test_cases = [
        {[0.0, 0.0], [0.0]},
        {[0.0, 1.0], [1.0]},
        {[1.0, 0.0], [1.0]},
        {[1.0, 1.0], [0.0]}
      ]
      
      # Calculate total error to verify network performance
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
      fitness = 4.0 - total_error
      
      # Assert the solution has good fitness (it doesn't need to be perfect for a regression test)
      assert fitness > 3.0, "XOR solution fitness (#{fitness}) is too low"
    end
    
    test "network structure contains expected elements" do
      # Create a simple XOR network directly using the code from the example
      genotype = create_seed_genotype()
      genotype = add_random_connections(genotype)
      
      # Convert to neural network
      nn = Cortex.from_genotype(genotype)
      
      # Check structure
      assert is_map(nn.neurons)
      assert is_map(nn.connections)
      
      # Get neuron counts by layer
      input_neurons = 
        nn.neurons
        |> Map.values()
        |> Enum.filter(&(&1.layer == :input))
        |> length()
        
      bias_neurons = 
        nn.neurons
        |> Map.values()
        |> Enum.filter(&(&1.layer == :bias))
        |> length()
        
      output_neurons = 
        nn.neurons
        |> Map.values()
        |> Enum.filter(&(&1.layer == :output))
        |> length()
        
      # The XOR network should have 2 inputs, 1 bias, and 1 output
      assert input_neurons == 2, "XOR network should have 2 input neurons"
      assert bias_neurons == 1, "XOR network should have 1 bias neuron"
      assert output_neurons == 1, "XOR network should have 1 output neuron"
    end
    
    test "network activation produces expected outputs" do
      # Create a manually-crafted XOR solution for testing
      nn = %{
        neurons: %{
          "input_1" => %{layer: :input, activation_function: :sigmoid},
          "input_2" => %{layer: :input, activation_function: :sigmoid},
          "bias" => %{layer: :bias, activation_function: :sigmoid},
          "hidden_1" => %{layer: :hidden, activation_function: :tanh},
          "hidden_2" => %{layer: :hidden, activation_function: :tanh},
          "output" => %{layer: :output, activation_function: :sigmoid}
        },
        connections: %{
          "conn_1" => %{from_id: "input_1", to_id: "hidden_1", weight: 1.0},
          "conn_2" => %{from_id: "input_2", to_id: "hidden_1", weight: 1.0},
          "conn_3" => %{from_id: "bias", to_id: "hidden_1", weight: -1.5},
          "conn_4" => %{from_id: "input_1", to_id: "hidden_2", weight: 1.0},
          "conn_5" => %{from_id: "input_2", to_id: "hidden_2", weight: 1.0},
          "conn_6" => %{from_id: "bias", to_id: "hidden_2", weight: -0.5},
          "conn_7" => %{from_id: "hidden_1", to_id: "output", weight: -2.0},
          "conn_8" => %{from_id: "hidden_2", to_id: "output", weight: 1.0}
        },
        type: :feed_forward,
        state: :ready
      }
      
      # Test on XOR inputs
      outputs_00 = Cortex.activate(nn, [0.0, 0.0])
      outputs_01 = Cortex.activate(nn, [0.0, 1.0])
      outputs_10 = Cortex.activate(nn, [1.0, 0.0])
      outputs_11 = Cortex.activate(nn, [1.0, 1.0])
      
      # Check that the XOR outputs provide a pattern where:
      # - outputs_01 and outputs_10 are higher than outputs_00 and outputs_11
      # This is a simplified assertion that allows for implementation differences
      assert hd(outputs_01) > hd(outputs_00), "Output for [0,1] should be higher than [0,0]"
      assert hd(outputs_10) > hd(outputs_00), "Output for [1,0] should be higher than [0,0]"
      assert hd(outputs_01) > hd(outputs_11), "Output for [0,1] should be higher than [1,1]"
      assert hd(outputs_10) > hd(outputs_11), "Output for [1,0] should be higher than [1,1]"
    end
  end
  
  # Helper functions from the XOR example for testing
  
  defp create_seed_genotype do
    # Create a new genotype
    genotype = Bardo.PopulationManager.Genotype.new()
    
    # Add input neurons for the two inputs
    genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :input, %{id: "input_1"})
    genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :input, %{id: "input_2"})
    
    # Add bias neuron
    genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add output neuron
    genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :output, %{id: "output"})
    
    # Return the base genotype
    genotype
  end
  
  defp add_random_connections(genotype) do
    # Add 1-3 hidden neurons
    genotype = Enum.reduce(1..Enum.random(1..3), genotype, fn i, g ->
      Bardo.PopulationManager.Genotype.add_neuron(g, :hidden, %{id: "hidden_#{i}"})
    end)
    
    # Get lists of inputs, hidden, and outputs
    input_ids = Bardo.PopulationManager.Genotype.get_layer_neuron_ids(genotype, :input)
    bias_ids = Bardo.PopulationManager.Genotype.get_layer_neuron_ids(genotype, :bias)
    hidden_ids = Bardo.PopulationManager.Genotype.get_layer_neuron_ids(genotype, :hidden)
    output_ids = Bardo.PopulationManager.Genotype.get_layer_neuron_ids(genotype, :output)
    
    # Connect inputs to hidden
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(hidden_ids, g, fn hidden_id, g2 ->
        weight = (Enum.random(-10..10) / 10)
        Bardo.PopulationManager.Genotype.add_connection(g2, input_id, hidden_id, weight)
      end)
    end)
    
    # Connect hidden to outputs
    genotype = Enum.reduce(hidden_ids, genotype, fn hidden_id, g ->
      Enum.reduce(output_ids, g, fn output_id, g2 ->
        weight = (Enum.random(-10..10) / 10)
        Bardo.PopulationManager.Genotype.add_connection(g2, hidden_id, output_id, weight)
      end)
    end)
    
    # Some direct input to output connections
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(output_ids, g, fn output_id, g2 ->
        if Enum.random(0..1) == 1 do
          weight = (Enum.random(-10..10) / 10)
          Bardo.PopulationManager.Genotype.add_connection(g2, input_id, output_id, weight)
        else
          g2
        end
      end)
    end)
    
    genotype
  end
end