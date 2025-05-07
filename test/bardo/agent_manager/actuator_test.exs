# Explicitly define the test actuator module in the Elixir namespace
defmodule Elixir.TestActuatorMod do
  @moduledoc """
  Mock implementation of an actuator for testing
  """
  
  def init(_params), do: {:ok, %{}}
  
  def actuate(_actuator_type, {_agent_id, _output, _params, _vl, _scape, _actuator_id, _mod_state}) do
    %{}
  end
end

defmodule Bardo.AgentManager.ActuatorTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.Actuator
  
  @agent_id {:agent, 345.55}
  @actuator_id {:actuator, 45.355}
  
  setup do
    # Use our helper for mocking the cortex module
    alias Bardo.TestHelper.Mocks
    Mocks.setup_erlang_mock(:cortex)
    
    # Set the application environment for testing
    Application.put_env(:bardo, :build_tool, :test)
    Application.put_env(:bardo, :env, :test)
    
    # Make sure our module is loaded and ready to use
    Code.ensure_loaded(TestActuatorMod)
    
    # Clean up after the test
    on_exit(fn ->
      Application.delete_env(:bardo, :build_tool)
      Application.delete_env(:bardo, :env)
    end)
    
    :ok
  end
  
  test "actuator functionality" do
    # Start a fake cortex process
    cortex_pid = spawn(fn -> 
      receive do
        _ -> :ok
      end
    end)
    
    # Start the actuator process
    exo_pid = self()
    pid = Actuator.start(node(), exo_pid)
    
    # Capture the actuator's messages to debug
    Process.flag(:trap_exit, true)
    
    # Initialize the actuator using the explicitly defined module
    :ok = Actuator.init_phase2(pid, exo_pid, @actuator_id, @agent_id,
      cortex_pid, self(), {TestActuatorMod, :some_actuator}, 1, [], [:from_pid], :gt)
    
    # Test the forward functionality  
    send(pid, {:forward, :from_pid, [3.14]})
    
    # Give time for the message to be processed
    Process.sleep(100)
    
    # Since we're now stuck waiting for a fitness message that won't come,
    # let's manually send a fitness message so the actuator can advance to the next state
    :ok = Actuator.fitness(pid, {[1.0], 0})
    
    # Give time for the message to be processed
    Process.sleep(100)
    
    # Now the actuator should be ready to stop
    assert :ok = Actuator.stop(pid, exo_pid)
    
    # Give more time for the message to be processed
    Process.sleep(200)
    
    # Verify the actuator has stopped
    refute Process.alive?(pid)
  end
end