defmodule DummySensorMod do
  def init(_), do: {:ok, %{}}
  def sense(_, _), do: :ok
  def percept(_, _), do: {[0.5], %{}}
end

defmodule Bardo.AgentManager.SensorTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.Sensor
  
  # Constants
  @agent_id {:agent, 345.55}
  @sensor_id {:sensor, 45.355}
  
  setup do
    # Set build_tool to elixir for get_module
    Application.put_env(:bardo, :build_tool, :elixir)
    # Force module to be available in Elixir namespace
    Application.put_env(:bardo, :elixir_sensor_module, DummySensorMod)
    :ok
  end
  
  test "sensor functionality" do
    # Start the sensor process
    exo_pid = self()
    pid = Sensor.start(node(), exo_pid)
    
    # Test init_phase2
    assert :ok = Sensor.init_phase2(
      pid, 
      exo_pid, 
      @sensor_id, 
      @agent_id,
      [], 
      :cortex_pid, 
      :scape_pid, 
      {DummySensorMod, :some_sensor}, 
      1, 
      [], 
      :gt
    )
    
    # Test sync
    assert :ok = Sensor.sync(pid, :cortex_pid)
    
    # Test percept
    assert :ok = Sensor.percept(pid, [9.8])
    
    # Test stop
    assert :ok = Sensor.stop(pid, exo_pid)
  end
end