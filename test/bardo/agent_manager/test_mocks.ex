# Create standalone modules for testing
defmodule TestSensorMod do
  @moduledoc """
  Mock implementation of a sensor for testing
  """
  
  def init(_params), do: {:ok, %{}}
  
  def sense(_sensor_type, _params), do: :ok
  
  def percept(_sensor_type, {percept, _agent_id, _vl, _params, _mod_state}), do: {percept, %{}}
end

defmodule TestPscapeMod do
  @moduledoc """
  Mock implementation of a private scape for testing
  """
  
  def init(_params), do: {:ok, %{}}
  
  def sense(_params, state), do: {[0.5], state}
  
  def actuate(_function, _params, _agent_id, state), do: {{[1.0], :ok}, state}
end

defmodule TestActuatorMod do
  @moduledoc """
  Mock implementation of an actuator for testing
  """
  
  def init(_params), do: {:ok, %{}}
  
  def actuate(_actuator_type, {_agent_id, output, _params, _vl, _scape, _actuator_id, _mod_state}) do
    {{output, 0}, %{}}
  end
end