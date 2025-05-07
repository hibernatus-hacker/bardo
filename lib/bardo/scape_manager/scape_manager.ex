defmodule Bardo.ScapeManager.ScapeManager do
  @moduledoc """
  The ScapeManager is responsible for starting and stopping scapes.
  
  Scapes represent environments where agents can interact and operate.
  """

  use GenServer
  
  alias Bardo.{Utils, LogR}
  alias Bardo.ScapeManager.ScapeSupervisor

  defmodule State do
    @moduledoc false
    defstruct []
  end

  @doc """
  Starts the ScapeManager GenServer with the given parameters and options.
  """
  @spec start_link() :: {:error, String.t()} | {:ok, pid()}
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  # For compatibility with supervisor
  def start_link(_) do
    start_link()
  end

  @doc """
  Starts a new scape with the given dimensions and module name.
  """
  @spec start_scape(float(), float(), float(), float(), atom()) :: :ok
  def start_scape(x, y, width, height, mod_name) do
    GenServer.cast(__MODULE__, {:start_scape, x, y, width, height, mod_name})
  end

  @doc """
  Stops a scape with the given module name.
  """
  @spec stop_scape(atom()) :: :ok
  def stop_scape(mod_name) do
    GenServer.cast(__MODULE__, {:stop_scape, mod_name})
  end

  @impl GenServer
  def init([]) do
    # Ensure Shards or equivalent is started
    Application.ensure_all_started(:shards)
    Utils.random_seed()
    LogR.debug({:scape_mgr, :init, :ok, nil, []})
    
    {:ok, %State{}}
  end

  @impl GenServer
  def handle_call(request, from, state) do
    LogR.warning({:scape_mgr, :msg, :error, "unexpected handle_call", [request, from]})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:start_scape, x, y, width, height, mod_name}, state) when is_atom(mod_name) do
    # Create shared tables for the scape
    :shards.new(:t1, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t2, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t3, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t4, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t5, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t6, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t7, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t8, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t9, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    :shards.new(:t10, [:set, :public, :named_table, {:write_concurrency, true}, {:read_concurrency, true}])
    
    # Start the scape
    {:ok, scape_pid} = ScapeSupervisor.start_scape(x, y, width, height, mod_name)
    
    # Store scape reference
    :ets.insert(:scape_names_pids, {mod_name, scape_pid})
    
    {:noreply, state}
  end

  @impl GenServer
  def handle_cast({:stop_scape, mod_name}, state) when is_atom(mod_name) do
    [{^mod_name, scape_pid}] = :ets.lookup(:scape_names_pids, mod_name)
    :ok = ScapeSupervisor.stop_scape(scape_pid)
    
    {:noreply, state}
  end
end