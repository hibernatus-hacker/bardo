defmodule Bardo.ScapeManager.Supervisor do
  @moduledoc """
  Top-level supervisor for the ScapeManager subsystem.
  
  This supervisor manages the ScapeManager, ScapeSupervisor, and SectorSupervisor.
  """
  
  use Supervisor
  
  alias Bardo.ScapeManager.{ScapeManager, ScapeSupervisor, SectorSupervisor}

  @doc """
  Starts the supervisor.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  # For compatibility with supervisor
  def start_link(_) do
    start_link()
  end

  @impl Supervisor
  def init([]) do
    # Create a shared ETS table for tracking scapes
    :ets.new(:scape_names_pids, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    sup_flags = %{
      strategy: :one_for_all,
      intensity: 4,
      period: 20
    }
    
    sector_sup = %{
      id: SectorSupervisor,
      start: {SectorSupervisor, :start_link, []},
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor,
      modules: [SectorSupervisor]
    }
    
    scape_sup = %{
      id: ScapeSupervisor,
      start: {ScapeSupervisor, :start_link, []},
      restart: :permanent,
      shutdown: :infinity,
      type: :supervisor,
      modules: [ScapeSupervisor]
    }
    
    scape_mgr = %{
      id: ScapeManager,
      start: {ScapeManager, :start_link, []},
      restart: :permanent,
      shutdown: 5000,
      type: :worker,
      modules: [ScapeManager]
    }
    
    children = [sector_sup, scape_sup, scape_mgr]
    
    {:ok, {sup_flags, children}}
  end
end