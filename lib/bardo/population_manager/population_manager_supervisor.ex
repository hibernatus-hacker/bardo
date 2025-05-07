defmodule Bardo.PopulationManager.PopulationManagerSupervisor do
  @moduledoc """
  PopulationManager top supervisor.
  """

  use Supervisor
  alias Bardo.PopulationManager.PopulationManagerWorker

  @doc """
  Starts the supervisor.
  """
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Spawns population_manager worker.
  """
  @spec start_population_manager() :: {:ok, pid()}
  def start_population_manager do
    child_spec = %{
      id: :population_manager_worker,
      start: {PopulationManagerWorker, :start_link, []},
      restart: :transient,
      shutdown: 30_000,
      type: :worker,
      modules: [PopulationManagerWorker]
    }
    
    Supervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Restarts population_manager worker.
  """
  @spec restart_population_manager() :: {:ok, pid()}
  def restart_population_manager do
    Supervisor.restart_child(__MODULE__, :population_manager_worker)
  end

  @impl Supervisor
  @doc false
  def init([]) do
    # Initialize ETS tables
    :ets.new(:population_status, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    :ets.new(:evaluations, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    :ets.new(:active_agents, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    :ets.new(:inactive_agents, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    
    # Configure supervisor
    sup_flags = %{
      strategy: :rest_for_one,
      intensity: 4,
      period: 20
    }
    
    # No initial children
    children = []
    
    {:ok, {sup_flags, children}}
  end
end