defmodule TestActuatorMod do
  @moduledoc """
  Mock implementation of an actuator for testing
  """
  
  def init(_params), do: {:ok, %{}}
  
  def actuate(_actuator_type, {_agent_id, output, _params, _vl, _scape, _actuator_id, _mod_state}) do
    %{}
  end
end