#!/usr/bin/env elixir

# Simple example of creating and using a neural network with Bardo
# This is a proof-of-concept to demonstrate how Bardo can be used

# Start the Bardo application
Application.ensure_all_started(:bardo)

# Set up minimal configuration
Application.put_env(:bardo, :ro_signal, [0.0])
Application.put_env(:bardo, :output_sat_limit, 1.0)

defmodule SimpleNeuroevolution do
  alias Bardo.AgentManager.Neuron
  
  def run do
    IO.puts("===== Bardo Simple Neural Network Example =====")
    
    # Create network components
    exoself_pid = self()
    neuron_pid = Neuron.start(node(), exoself_pid)
    
    neuron_id = {:neuron, {123.45, 678.90}}
    cx_pid = spawn(fn -> receive _ -> :ok end end)
    
    # Create input/output connections
    input_pid1 = spawn_receiver("Input 1")
    input_pid2 = spawn_receiver("Input 2")
    output_pid = spawn_receiver("Output")
    
    # Neural network configuration
    af = :tanh
    pf = {:none, []}
    aggr_f = :dot_product
    heredity_type = :darwinian
    
    # Create the connection weights
    si_pidps = [{input_pid1, [{0.5, []}]}, {input_pid2, [{0.3, []}]}, {:bias, [{0.1, []}]}]
    mi_pidps = []
    output_pids = [output_pid]
    ro_pids = []
    
    # Initialize the neuron
    IO.puts("Initializing neuron...")
    Neuron.init_phase2(neuron_pid, exoself_pid, neuron_id, cx_pid, af, pf, aggr_f, 
                     heredity_type, si_pidps, mi_pidps, output_pids, ro_pids)
    
    # Process inputs
    IO.puts("\\nSending inputs to neuron...")
    inputs = [0.8, -0.3, 0.6, -0.1, 0.9]
    
    Enum.each(inputs, fn input_value ->
      IO.puts("Input values: #{input_value} and #{input_value / 2}")
      
      # Send input signals to the neuron
      Neuron.forward(neuron_pid, input_pid1, [input_value])
      Neuron.forward(neuron_pid, input_pid2, [input_value / 2])
      
      # Give the network time to process
      :timer.sleep(100)
    end)
    
    IO.puts("\\nNeural processing complete!\\n")
    
    # Cleanup
    Neuron.stop(neuron_pid, exoself_pid)
    
    IO.puts("===== Example Completed =====")
  end
  
  # Helper to create a process that will display received messages
  defp spawn_receiver(name) do
    spawn(fn -> receiver_loop(name) end)
  end
  
  defp receiver_loop(name) do
    receive do
      {:forward, from_pid, output} ->
        IO.puts("#{name} received: #{inspect(output)} from #{inspect(from_pid)}")
        receiver_loop(name)
      msg ->
        IO.puts("#{name} received unexpected: #{inspect(msg)}")
        receiver_loop(name)
    after
      10000 -> :timeout
    end
  end
end

# Run the example
SimpleNeuroevolution.run()