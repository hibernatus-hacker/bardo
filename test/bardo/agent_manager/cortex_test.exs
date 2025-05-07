defmodule Bardo.AgentManager.CortexTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.Cortex
  
  setup do
    # Create the cortex process
    exoself_pid = self()
    cortex_pid = Cortex.start(node(), exoself_pid)
    
    # Set up test components
    cortex_id = {:cortex, {:origin, 123.45}}
    
    # Create PIDs for sensors, neurons, and actuators
    s_pids = [spawn_sensor("Sensor1"), spawn_sensor("Sensor2")]
    n_pids = [spawn_link(fn -> Process.sleep(:infinity) end)]
    a_pids = [spawn_actuator("Actuator1"), spawn_actuator("Actuator2")]
    
    # Define operation mode
    op_mode = :gt
    
    # Initialize the cortex
    Cortex.init_phase2(cortex_pid, exoself_pid, cortex_id, s_pids, n_pids, a_pids, op_mode)
    
    # Wait for the sensors to receive sync messages
    Process.sleep(100)
    
    # Return the test context
    {:ok, %{
      cortex_pid: cortex_pid,
      exoself_pid: exoself_pid,
      cortex_id: cortex_id,
      s_pids: s_pids,
      n_pids: n_pids,
      a_pids: a_pids
    }}
  end
  
  test "cortex sync process works correctly", %{cortex_pid: cortex_pid, a_pids: a_pids} do
    # Send sync messages from actuators
    [a_pid1, a_pid2] = a_pids
    
    # First actuator sync
    Cortex.sync(cortex_pid, a_pid1, [0.5], 0)
    
    # Second actuator sync
    Cortex.sync(cortex_pid, a_pid2, [0.8], 0)
    
    # The cortex should trigger the sensors to sync again
    # We expect sync messages to be sent to our sensor processes
    assert_received {:sync, ^cortex_pid}
    
    # Try another cycle with a goal reached
    Cortex.sync(cortex_pid, a_pid1, [0.6], 0)
    Cortex.sync(cortex_pid, a_pid2, [0.9], :goal_reached)
    
    # This should trigger an evaluation complete message and switch to inactive
    assert_received {:evaluation_complete, ^cortex_pid, [1.5], 1, _time_dif, true}
  end
  
  test "cortex can be reactivated", %{cortex_pid: cortex_pid, exoself_pid: exoself_pid} do
    # First complete a cycle with a goal reached to make it inactive
    [a_pid1, a_pid2] = [hd(Process.info(self())[:links]), hd(tl(Process.info(self())[:links]))]
    
    Cortex.sync(cortex_pid, a_pid1, [0.5], 0)
    Cortex.sync(cortex_pid, a_pid2, [0.8], :goal_reached)
    
    # Should receive evaluation complete
    assert_received {:evaluation_complete, ^cortex_pid, _fitness, _cycles, _time, _goal_reached}
    
    # Now reactivate the cortex
    Cortex.reactivate(cortex_pid, exoself_pid)
    
    # Should send sync messages to sensors again
    assert_received {:sync, ^cortex_pid}
  end
  
  test "cortex can be stopped", %{cortex_pid: cortex_pid, exoself_pid: exoself_pid} do
    ref = Process.monitor(cortex_pid)
    
    # Stop the cortex
    Cortex.stop(cortex_pid, exoself_pid)
    
    # Verify the cortex has stopped
    assert_receive {:DOWN, ^ref, :process, ^cortex_pid, :normal}, 1000
  end
  
  # Helper function to spawn a mock sensor process
  defp spawn_sensor(name) do
    test_pid = self()
    
    spawn_link(fn ->
      sensor_loop(name, test_pid)
    end)
  end
  
  defp sensor_loop(name, test_pid) do
    receive do
      {:sync, cortex_pid} ->
        # Forward the sync message to the test process
        send(test_pid, {:sync, cortex_pid})
        sensor_loop(name, test_pid)
        
      msg ->
        IO.puts("#{name} received: #{inspect(msg)}")
        sensor_loop(name, test_pid)
    end
  end
  
  # Helper function to spawn a mock actuator process
  defp spawn_actuator(name) do
    spawn_link(fn ->
      actuator_loop(name)
    end)
  end
  
  defp actuator_loop(name) do
    receive do
      msg ->
        IO.puts("#{name} received: #{inspect(msg)}")
        actuator_loop(name)
    end
  end
end