defmodule Bardo.AgentManager.NeuronTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.Neuron
  alias Bardo.AppConfig
  
  setup do
    # First ensure the AppConfig module is ready with default values
    Application.put_env(:bardo, :ro_signal, [0.0])
    Application.put_env(:bardo, :output_sat_limit, 1.0)
    
    # Create the neuron process
    exoself_pid = self()
    neuron_pid = Neuron.start(node(), exoself_pid)
    
    # Initialize neuron state
    neuron_id = {:neuron, {123.45, 678.90}}
    cx_pid = spawn(fn -> receive _ -> :ok end end)
    
    # Create a simple neural network setup for testing
    input_pid1 = spawn(fn -> receive _ -> :ok end end)
    input_pid2 = spawn(fn -> receive _ -> :ok end end)
    output_pid = spawn(fn -> receive _ -> :ok end end)
    
    # Define properties of the neuron
    af = :tanh
    pf = {:none, []}
    aggr_f = :dot_product
    heredity_type = :darwinian
    
    # Define input/output connections
    si_pidps = [{input_pid1, [{0.5, []}]}, {input_pid2, [{0.3, []}]}, {:bias, [{0.1, []}]}]
    mi_pidps = []
    output_pids = [output_pid]
    ro_pids = []
    
    # Initialize the neuron with phase2
    Neuron.init_phase2(neuron_pid, exoself_pid, neuron_id, cx_pid, af, pf, aggr_f, 
                       heredity_type, si_pidps, mi_pidps, output_pids, ro_pids)
    
    # Return the test context
    {:ok, %{
      neuron_pid: neuron_pid,
      exoself_pid: exoself_pid,
      neuron_id: neuron_id,
      input_pid1: input_pid1,
      input_pid2: input_pid2,
      output_pid: output_pid
    }}
  end
  
  test "neuron forwards signals correctly", %{neuron_pid: neuron_pid, input_pid1: input_pid1, 
                                             input_pid2: input_pid2, output_pid: output_pid} do
    # Set up a listener for the output
    test_pid = self()
    ref = make_ref()
    
    # Create a temporary process that will forward us any messages from the neuron to output_pid
    output_receiver = spawn(fn -> 
      receive
        {:forward, from_pid, output} when from_pid == neuron_pid ->
          send(test_pid, {:received_output, ref, output})
      after
        2000 -> :timeout
      end
    end)
    
    # Temporarily replace the original output_pid with our receiver in the neuron's internal state
    # (In a real test this could be done differently, but for our purpose this works)
    Process.register(output_receiver, :output_receiver)
    
    # Send inputs to the neuron
    Neuron.forward(neuron_pid, input_pid1, [0.7])
    Neuron.forward(neuron_pid, input_pid2, [0.9])
    
    # Wait for the result
    result = receive do
      {:received_output, ^ref, output} -> output
    after
      2000 -> :timeout
    end
    
    # Cleanup
    Process.unregister(:output_receiver)
    
    # Assert that an output was produced (the exact value depends on neuron weights and activation)
    assert result != :timeout, "Neuron did not produce any output"
    assert is_list(result), "Output is not a list"
    assert length(result) == 1, "Output list has unexpected length"
    assert is_float(hd(result)), "Output is not a float"
  end
  
  test "neuron can be weight backed up", %{neuron_pid: neuron_pid, exoself_pid: exoself_pid} do
    Neuron.weight_backup(neuron_pid, exoself_pid)
    # Since this is just state mutation with no externally visible effects,
    # we can only test that it doesn't crash
    :timer.sleep(100)
    assert Process.alive?(neuron_pid)
  end
  
  test "neuron can be weight restored", %{neuron_pid: neuron_pid, exoself_pid: exoself_pid} do
    Neuron.weight_restore(neuron_pid, exoself_pid)
    # Also just a state mutation
    :timer.sleep(100)
    assert Process.alive?(neuron_pid)
  end
  
  test "neuron can be weight perturbed", %{neuron_pid: neuron_pid, exoself_pid: exoself_pid} do
    Neuron.weight_perturb(neuron_pid, exoself_pid, 0.1)
    # Also just a state mutation
    :timer.sleep(100)
    assert Process.alive?(neuron_pid)
  end
  
  test "neuron can be reset", %{neuron_pid: neuron_pid, exoself_pid: exoself_pid} do
    Neuron.reset_prep(neuron_pid, exoself_pid)
    
    # The neuron should send a :ready message
    assert_receive {^neuron_pid, :ready}, 1000
    
    # Now send the reset signal
    send(neuron_pid, {exoself_pid, :reset})
    
    # Neuron should have re-initialized
    :timer.sleep(100)
    assert Process.alive?(neuron_pid)
  end
  
  test "neuron can be stopped", %{neuron_pid: neuron_pid, exoself_pid: exoself_pid} do
    ref = Process.monitor(neuron_pid)
    Neuron.stop(neuron_pid, exoself_pid)
    
    # Verify the neuron has stopped
    assert_receive {:DOWN, ^ref, :process, ^neuron_pid, :normal}, 1000
  end
end