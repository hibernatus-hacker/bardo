defmodule Bardo.ScapeManager.ScapeSupervisor do
  @moduledoc """
  Supervisor for Scape processes.
  
  This supervisor manages individual Scape processes, which represent environments 
  where agents can interact.
  """
  
  use Supervisor
  
  alias Bardo.ScapeManager.Scape

  @doc """
  Starts the supervisor.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Starts a new scape process with the given parameters.
  """
  @spec start_scape(float(), float(), float(), float(), atom()) :: {:ok, pid()}
  def start_scape(x, y, width, height, mod_name) do
    Supervisor.start_child(__MODULE__, [x, y, width, height, mod_name])
  end

  @doc """
  Stops a scape process with the given PID.
  """
  @spec stop_scape(pid()) :: :ok
  def stop_scape(pid) do
    Supervisor.terminate_child(__MODULE__, pid)
  end

  @impl Supervisor
  def init([]) do
    # Create shared ETS tables for the scape
    :ets.new(:ids_sids_loc, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    :ets.new(:xy_pts, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    :ets.new(:qt, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    sup_flags = %{
      strategy: :simple_one_for_one,
      intensity: 6,
      period: 30
    }
    
    scape = %{
      id: Scape,
      start: {Scape, :start_link, []},
      restart: :transient,
      shutdown: 5000,
      type: :worker,
      modules: [Scape]
    }
    
    children = [scape]
    
    {:ok, {sup_flags, children}}
  end
end