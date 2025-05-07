defmodule DummyPscapeMod do
  def init(_), do: {:ok, %{}}
  def sense(_, state), do: {[0.5], state}
  def actuate(_, _, _, state), do: {{[1.0], 1}, state}
end

defmodule Bardo.AgentManager.PrivateScapeTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.PrivateScape
  
  # Constants
  @agent_id {:agent, 5.92352455}
  
  setup do
    # Set build_tool to elixir for get_module
    Application.put_env(:bardo, :build_tool, :elixir)
    # Force module to be available in Elixir namespace
    Application.put_env(:bardo, :elixir_pscape_module, DummyPscapeMod)
    :ok
  end
  
  test "private scape functionality" do
    assert {:ok, pid} = PrivateScape.start_link(@agent_id, DummyPscapeMod)
    
    # Test sense
    assert :ok = PrivateScape.sense(pid, @agent_id, self(), [])
    assert_receive {:handle, {:percept, _}}
    
    # Test actuate
    assert :ok = PrivateScape.actuate(pid, @agent_id, self(), :some_fun, [])
    assert_receive {:handle, {:fitness, _}}
  end
end