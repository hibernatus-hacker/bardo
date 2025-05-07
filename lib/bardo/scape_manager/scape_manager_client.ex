defmodule Bardo.ScapeManager.ScapeManagerClient do
  @moduledoc """
  Client module for interacting with the ScapeManager and Scape processes.
  """

  alias Bardo.ScapeManager.{ScapeManager, Scape}
  alias Bardo.Models

  @doc """
  Starts a new scape with the given dimensions and module name.
  """
  @spec start_scape(float(), float(), float(), float(), atom()) :: :ok
  def start_scape(x, y, width, height, mod_name) do
    ScapeManager.start_scape(x, y, width, height, mod_name)
    :ok
  end

  @doc """
  Stops a scape with the given module name.
  """
  @spec stop_scape(atom()) :: :ok
  def stop_scape(mod_name) do
    ScapeManager.stop_scape(mod_name)
    :ok
  end

  @doc """
  Agent enters the scape with the given parameters.
  """
  @spec enter(Models.agent_id(), [any()]) :: :ok
  def enter(agent_id, params) do
    Scape.enter(agent_id, params)
    :ok
  end

  @doc """
  Agent senses the scape through the given sensor.
  """
  @spec sense(Models.agent_id(), pid(), any()) :: :ok
  def sense(agent_id, sensor_pid, params) do
    Scape.sense(agent_id, sensor_pid, params)
    :ok
  end

  @doc """
  Agent actuates in the scape with the given function and parameters.
  """
  @spec actuate(Models.agent_id(), pid(), atom(), any()) :: :ok
  def actuate(agent_id, actuator_pid, function, params) do
    Scape.actuate(agent_id, actuator_pid, function, params)
    :ok
  end

  @doc """
  Agent leaves the scape with the given parameters.
  """
  @spec leave(Models.agent_id(), [any()]) :: :ok
  def leave(agent_id, params) do
    Scape.leave(agent_id, params)
    :ok
  end
end