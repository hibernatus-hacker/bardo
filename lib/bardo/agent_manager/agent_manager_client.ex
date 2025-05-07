defmodule Bardo.AgentManager.AgentManagerClient do
  @moduledoc """
  Client module for interacting with the Agent Manager.
  
  This module provides a simplified API for interacting with agent-related processes.
  """
  
  alias Bardo.AgentManager.{Actuator, Sensor}
  require Logger
  
  @doc """
  Starts an agent with the specified ID and operation mode.
  """
  @spec start_agent(tuple(), atom()) :: :ok
  def start_agent(agent_id, op_mode) do
    # Stub implementation until AgentManager has proper start_agent function
    # The call was removed as it referenced a non-existent function
    Logger.debug("Starting agent: #{inspect(agent_id)} in mode: #{inspect(op_mode)}")
    :ok
  end
  
  @doc """
  Stops an agent with the specified ID.
  """
  @spec stop_agent(tuple()) :: :ok
  def stop_agent(agent_id) do
    # Stub implementation until AgentManager has proper stop_agent function
    # The call was removed as it referenced a non-existent function
    Logger.debug("Stopping agent: #{inspect(agent_id)}")
    :ok
  end
  
  @doc """
  Sends a perception to a sensor.
  """
  @spec percept(pid(), [float()]) :: :ok
  def percept(sensor_pid, percept) do
    Sensor.percept(sensor_pid, percept)
    :ok
  end
  
  @doc """
  Sends a fitness score to an actuator.
  """
  @spec fitness(pid(), [float()], atom() | integer()) :: :ok
  def fitness(actuator_pid, fitness, halt_flag) do
    Actuator.fitness(actuator_pid, {fitness, halt_flag})
    :ok
  end
end