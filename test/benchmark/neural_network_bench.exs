defmodule Bardo.Benchmark.NeuralNetworkBench do
  @moduledoc """
  Benchmarks for neural network operations in the Bardo library.
  
  This module provides benchmarks for various neural network operations,
  including forward propagation, network creation, and fitness evaluation.
  
  Run with:
  ```
  mix run test/benchmark/neural_network_bench.exs
  ```
  """
  
  alias Bardo.AgentManager.Cortex
  alias Bardo.PopulationManager.Genotype
  
  # Function to run the benchmarks
  def run do
    IO.puts("Running Neural Network Performance Benchmarks")
    IO.puts("--------------------------------------------\n")
    
    # Run all benchmarks
    benchmark_network_creation()
    benchmark_forward_propagation()
    benchmark_xor_fitness()
    
    # Report completion
    IO.puts("\nBenchmark runs completed successfully.")
  end
  
  # Benchmark network creation
  defp benchmark_network_creation do
    IO.puts("Benchmark: Network Creation")
    IO.puts("---------------------------")
    
    # Define network sizes to test
    network_sizes = [
      {"Small (5 neurons)", 2, 2, 1},
      {"Medium (20 neurons)", 5, 10, 5},
      {"Large (50 neurons)", 10, 30, 10},
      {"X-Large (100 neurons)", 20, 60, 20}
    ]
    
    # Run for each network size
    Enum.each(network_sizes, fn {name, inputs, hidden, outputs} ->
      IO.write("#{name}: ")
      
      # Measure time to create network
      {time_us, _genotype} = :timer.tc(fn -> 
        create_test_network(inputs, hidden, outputs)
      end)
      
      # Report results
      time_ms = time_us / 1000
      IO.puts("#{format_float(time_ms)} ms")
    end)
    
    IO.puts("")
  end
  
  # Benchmark forward propagation
  defp benchmark_forward_propagation do
    IO.puts("Benchmark: Forward Propagation")
    IO.puts("------------------------------")
    
    # Define network sizes to test
    network_specs = [
      {"Small (5 neurons)", 2, 2, 1, 1_000},
      {"Medium (20 neurons)", 5, 10, 5, 500},
      {"Large (50 neurons)", 10, 30, 10, 100},
      {"X-Large (100 neurons)", 20, 60, 20, 50}
    ]
    
    # Run for each network size
    Enum.each(network_specs, fn {name, inputs, hidden, outputs, iterations} ->
      IO.write("#{name} (#{iterations} iterations): ")
      
      # Create test network
      genotype = create_test_network(inputs, hidden, outputs)
      nn = Cortex.from_genotype(genotype)
      
      # Create random input
      input_vector = for _ <- 1..inputs, do: :rand.uniform() * 2 - 1
      
      # Measure time for forward propagation
      {time_us, _results} = :timer.tc(fn -> 
        for _ <- 1..iterations do
          Cortex.activate(nn, input_vector)
        end
      end)
      
      # Calculate average time per iteration
      avg_time_us = time_us / iterations
      avg_time_ms = avg_time_us / 1000
      
      # Report results
      IO.puts("#{format_float(avg_time_ms)} ms per activation")
    end)
    
    IO.puts("")
  end
  
  # Benchmark XOR fitness evaluation
  defp benchmark_xor_fitness do
    IO.puts("Benchmark: XOR Fitness Evaluation")
    IO.puts("--------------------------------")
    
    # Define parameters
    population_sizes = [10, 100, 1_000]
    
    # Define XOR test cases
    xor_test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Run for each population size
    Enum.each(population_sizes, fn pop_size ->
      IO.write("Population size #{pop_size}: ")
      
      # Create population of networks
      population = for _ <- 1..pop_size do
        create_xor_network()
      end
      
      # Measure time to evaluate entire population
      {time_us, _results} = :timer.tc(fn -> 
        Enum.map(population, fn genotype ->
          fitness_function(genotype, xor_test_cases)
        end)
      end)
      
      # Calculate average time per network
      time_ms = time_us / 1000
      avg_time_ms = time_ms / pop_size
      
      # Report results
      IO.puts("Total: #{format_float(time_ms)} ms, Avg per network: #{format_float(avg_time_ms)} ms")
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
  
  # Create a network for XOR problem
  defp create_xor_network do
    # Create a new genotype
    genotype = Genotype.new()
    
    # Add input neurons
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_1"})
    genotype = Genotype.add_neuron(genotype, :input, %{id: "input_2"})
    
    # Add bias neuron
    genotype = Genotype.add_neuron(genotype, :bias, %{id: "bias"})
    
    # Add hidden neurons (1-3 random)
    hidden_count = Enum.random(1..3)
    genotype = Enum.reduce(1..hidden_count, genotype, fn i, g ->
      Genotype.add_neuron(g, :hidden, %{id: "hidden_#{i}"})
    end)
    
    # Add output neuron
    genotype = Genotype.add_neuron(genotype, :output, %{id: "output"})
    
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
    
    # Connect each input to each hidden neuron
    genotype = Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
      Enum.reduce(hidden_ids, g, fn hidden_id, g2 ->
        weight = :rand.uniform() * 2 - 1  # Random weight between -1 and 1
        Genotype.add_connection(g2, input_id, hidden_id, weight)
      end)
    end)
    
    # If there are no hidden neurons, connect inputs directly to outputs
    genotype = 
      if Enum.empty?(hidden_ids) do
        Enum.reduce(input_ids ++ bias_ids, genotype, fn input_id, g ->
          Enum.reduce(output_ids, g, fn output_id, g2 ->
            weight = :rand.uniform() * 2 - 1
            Genotype.add_connection(g2, input_id, output_id, weight)
          end)
        end)
      else
        # Otherwise, connect each hidden neuron to each output
        Enum.reduce(hidden_ids, genotype, fn hidden_id, g ->
          Enum.reduce(output_ids, g, fn output_id, g2 ->
            weight = :rand.uniform() * 2 - 1
            Genotype.add_connection(g2, hidden_id, output_id, weight)
          end)
        end)
      end
      
    genotype
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
    4.0 - total_error
  end
  
  # Format a float to 2 decimal places
  defp format_float(value) do
    :erlang.float_to_binary(value, [decimals: 2])
  end
end

# Run the benchmarks when this file is executed directly
Bardo.Benchmark.NeuralNetworkBench.run()