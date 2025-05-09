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
    # Start a new population with default parameters
    PopulationManagerSupervisor.start_population("default_population", %{
      experiment_id: "default_experiment",
      run_number: 1,
      population_size: 50,
      morphology: :default
    })
    :ok
  end

  @doc """
  Sends a message to restart a population manager run.
  """
  @spec restart_run() :: :ok
  def restart_run do
    # First stop any existing populations
    case PopulationManagerSupervisor.list_populations() do
      {:ok, populations} ->
        Enum.each(populations, fn pop_id ->
          PopulationManagerSupervisor.stop_population(pop_id)
        end)
      _ -> :ok
    end

    # Then start a new population
    new_run()
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
  @spec set_op_tag(:pause | :continue | :stop) :: :ok
  def set_op_tag(op_tag) do
    PopulationManager.set_op_tag(op_tag)
    :ok
  end

  @doc """
  Stops a population manager run with the specified ID.

  ## Parameters
    * `population_id` - ID of the population to stop

  ## Returns
    * `:ok` - If the population was stopped successfully
    * `{:error, :not_found}` - If the population was not found
  """
  @spec stop(atom() | binary()) :: :ok | {:error, :not_found}
  def stop(population_id) do
    # Use the supervisor to stop the population
    PopulationManagerSupervisor.stop_population(population_id)
  end
end