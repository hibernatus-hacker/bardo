defmodule Bardo.PopulationManager.PopulationManagerClient do
  @moduledoc """
  Client module for interacting with the PopulationManager.
  """

  alias Bardo.PopulationManager.PopulationManagerSupervisor
  alias Bardo.PopulationManager.PopulationManager
  alias Bardo.Models

  @doc """
  Sends a message to start a new population manager run.
  """
  @spec new_run() :: :ok
  def new_run do
    PopulationManagerSupervisor.start_population_manager()
    :ok
  end

  @doc """
  Sends a message to restart a population manager run.
  """
  @spec restart_run() :: :ok
  def restart_run do
    PopulationManagerSupervisor.restart_population_manager()
    :ok
  end

  @doc """
  Notifies the population manager that an agent has terminated.
  """
  @spec agent_terminated(Models.agent_id()) :: :ok
  def agent_terminated(agent_id) do
    PopulationManager.agent_terminated(agent_id)
    :ok
  end

  @doc """
  Notifies the population manager that a goal has been reached.
  """
  @spec set_goal_reached() :: :ok
  def set_goal_reached do
    PopulationManager.set_goal_reached()
    :ok
  end

  @doc """
  Sends evaluation data to the population manager.
  """
  @spec set_evaluations(Models.specie_id(), integer(), integer(), integer()) :: :ok
  def set_evaluations(specie_id, aea, cycle_acc, time_acc) do
    PopulationManager.set_evaluations(specie_id, aea, cycle_acc, time_acc)
    :ok
  end

  @doc """
  Notifies the population manager that validation is complete with the given fitness.
  """
  @spec validation_complete(Models.agent_id(), float()) :: :ok
  def validation_complete(agent_id, fitness) do
    PopulationManager.validation_complete(agent_id, fitness)
    :ok
  end

  @doc """
  Sets the operation tag for the population manager.
  """
  @spec set_op_tag(:pause | :continue) :: :ok
  def set_op_tag(op_tag) do
    PopulationManager.set_op_tag(op_tag)
    :ok
  end
end