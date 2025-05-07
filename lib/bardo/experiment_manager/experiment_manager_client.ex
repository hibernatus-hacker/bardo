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
  
  @doc """
  Start the experiment with the given ID.
  
  For compatibility with older code.
  """
  @spec start(Bardo.Models.experiment_id()) :: :ok | {:error, term()}
  def start(experiment_id) do
    Bardo.ExperimentManager.ExperimentManager.start(experiment_id)
    :ok
  end
  
  @doc """
  Create a new experiment.
  """
  @spec new_experiment(String.t()) :: {:ok, Bardo.Models.experiment_id()} | {:error, term()}
  def new_experiment(name) do
    Bardo.ExperimentManager.ExperimentManager.new_experiment(name)
  end
  
  @doc """
  Configure an existing experiment.
  """
  @spec configure(Bardo.Models.experiment_id(), map()) :: :ok | {:error, term()}
  def configure(experiment_id, config) do
    Bardo.ExperimentManager.ExperimentManager.configure(experiment_id, config)
  end
  
  @doc """
  Start evaluation with a fitness function.
  """
  @spec start_evaluation(Bardo.Models.experiment_id(), function()) :: :ok | {:error, term()}
  def start_evaluation(experiment_id, fitness_function) do
    Bardo.ExperimentManager.ExperimentManager.start_evaluation(experiment_id, fitness_function)
  end
  
  @doc """
  Get the status of an experiment.
  """
  @spec status(Bardo.Models.experiment_id()) :: 
    {:in_progress, map()} | {:completed, map()} | {:error, term()}
  def status(experiment_id) do
    Bardo.ExperimentManager.ExperimentManager.status(experiment_id)
  end
  
  @doc """
  Get the best solution from an experiment.
  """
  @spec get_best_solution(Bardo.Models.experiment_id()) :: 
    {:ok, term()} | {:error, term()}
  def get_best_solution(experiment_id) do
    Bardo.ExperimentManager.ExperimentManager.get_best_solution(experiment_id)
  end
  
  @doc """
  Stop an experiment.
  """
  @spec stop(Bardo.Models.experiment_id()) :: :ok | {:error, term()}
  def stop(experiment_id) do
    Bardo.ExperimentManager.ExperimentManager.stop(experiment_id)
    :ok
  end
end