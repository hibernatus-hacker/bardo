defmodule Bardo.ExperimentManager.ExperimentManagerClient do
  @moduledoc """
  Client module for interacting with the ExperimentManager.
  """

  alias Bardo.Models

  @doc """
  Sends a message to start a new experiment run.
  """
  @spec start_run() :: :ok
  def start_run do
    Bardo.ExperimentManager.ExperimentManager.run()
    :ok
  end

  @doc """
  Notifies the experiment manager that a run has completed with the given results.
  """
  @spec run_complete(Models.population_id(), Models.trace()) :: :ok
  def run_complete(population_id, trace) do
    Bardo.ExperimentManager.ExperimentManager.complete(population_id, trace)
    :ok
  end
end