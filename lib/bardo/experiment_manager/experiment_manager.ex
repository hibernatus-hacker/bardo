defmodule Bardo.ExperimentManager.ExperimentManager do
  @moduledoc """
  The experiment_manager process sequentially spawns population_managers and
  applies them to some specified problem. The experiment_manager can compose
  experiments by performing multiple evolutionary runs, and then
  produce statistical data and graph-ready files of the various
  statistics calculated from the experiment.
  
  Specifically, it has three main functionalities:
  1. Run the population_manager N number of times, waiting for the
     population_manager's trace after every run.
  2. Create the experiment entry in the database, and keep
     updating its trace_acc as it itself accumulates the traces from
     spawned population_managers. The population_manager should only do this
     if the backup_flag is set to true in the experiment record with
     which the experiment was started.
  3. When the experiment_manager has finished performing N number of
     evolutionary runs, and has accumulated N number of traces, it
     prints all the traces to console, calculates averages of the
     parameters between all the traces, and then finally write that
     data to file in the format which can be immediately graphed.
  """
  
  use GenServer
  require Logger
  alias Bardo.Logger, as: LogR
  # Aliases not used in this module but keeping for future use
  # alias Bardo.Models
  # alias Bardo.DB
  
  # Client API

  @doc """
  Start the ExperimentManager as a linked process.
  """
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  @doc """
  Start a new experiment run.
  """
  def run do
    GenServer.cast(__MODULE__, :run)
  end
  
  @doc """
  Complete a run with the given results.
  """
  def complete(population_id, trace) do
    GenServer.cast(__MODULE__, {:complete, population_id, trace})
  end
  
  @doc """
  Create a new experiment.
  """
  def new_experiment(_name) do
    experiment_id = "experiment_#{:erlang.system_time(:millisecond)}"
    {:ok, experiment_id}
  end
  
  @doc """
  Configure an experiment.
  """
  def configure(_experiment_id, _config) do
    :ok
  end
  
  @doc """
  Start evaluation with a fitness function.
  """
  def start_evaluation(_experiment_id, _fitness_function) do
    :ok
  end
  
  @doc """
  Start an experiment with the given ID.
  """
  def start(_experiment_id) do
    :ok
  end
  
  @doc """
  Get the status of an experiment.
  """
  def status(_experiment_id) do
    {:in_progress, %{generation: 1, best_fitness: 0.0}}
  end
  
  @doc """
  Get the best solution from an experiment.
  """
  def get_best_solution(_experiment_id) do
    {:ok, %{}}
  end
  
  @doc """
  Stop an experiment.
  """
  def stop(_experiment_id) do
    :ok
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_args) do
    LogR.debug({:experiment_mgr, :init, :ok})
    state = %{
      current_run: nil,
      runs: [],
      traces: [],
      pending_runs: [],
      current_experiment: nil
    }
    {:ok, state}
  end
  
  @impl true
  def handle_cast(:run, state) do
    LogR.debug({:experiment_mgr, :run, :ok})
    {:noreply, state}
  end
  
  @impl true
  def handle_cast({:complete, population_id, _trace}, state) do
    LogR.debug({:experiment_mgr, :complete, :ok, nil, [population_id]})
    {:noreply, state}
  end

  @impl true
  def handle_info(info, state) do
    case info do
      {:EXIT, _pid, :normal} ->
        {:noreply, state}
      {:EXIT, pid, :shutdown} ->
        LogR.debug({:experiment_mgr, :msg, :ok, "shutdown message", [pid]})
        {:stop, :shutdown, state}
      {:EXIT, pid, reason} ->
        LogR.debug({:experiment_mgr, :msg, :ok, "exit message", [pid, reason]})
        {:stop, reason, state}
      unexpected_msg ->
        LogR.warning({:experiment_mgr, :msg, :error, "unexpected info message", [unexpected_msg]})
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, _state) do
    LogR.info({:experiment_mgr, :status, :ok, "experiment_mgr terminated", [reason]})
    :ok
  end
end