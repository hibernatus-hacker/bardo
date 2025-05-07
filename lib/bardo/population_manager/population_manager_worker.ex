defmodule Bardo.PopulationManager.PopulationManagerWorker do
  @moduledoc """
  The PopulationManagerWorker is responsible for spawning the population_manager
  process.
  """

  use GenServer
  alias Bardo.{LogR}
  alias Bardo.PopulationManager.PopulationManager

  @doc """
  The start_link function spawns the PopulationManagerWorker server.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    GenServer.start_link(__MODULE__, [])
  end

  @impl GenServer
  @doc false
  @spec init([]) :: {:ok, %{population_manager_pid: pid() | nil}}
  def init([]) do
    Process.flag(:trap_exit, true)
    LogR.debug({:population_mgr_worker, :init, :ok, nil, []})
    
    pid = PopulationManager.start(Node.self())
    state = %{population_manager_pid: pid}
    
    {:ok, state}
  end

  @impl GenServer
  @doc false
  def handle_call(_request, _from, state) do
    LogR.warning({:population_mgr_worker, :msg, :error, "unexpected handle_call", []})
    {:reply, :ok, state}
  end

  @impl GenServer
  @doc false
  def handle_cast(_request, state) do
    LogR.warning({:population_mgr_worker, :msg, :error, "unexpected handle_cast", []})
    {:noreply, state}
  end

  @impl GenServer
  @doc false
  def handle_info(info, state) do
    case info do
      {:EXIT, _pid, :normal} ->
        {:stop, :normal, state}
        
      {:EXIT, _pid, :shutdown} ->
        {:stop, :shutdown, state}
        
      {:EXIT, _pid, reason} ->
        {:stop, reason, state}
        
      unexpected_msg ->
        LogR.warning({:population_mgr_worker, :msg, :error, "unexpected info message", [unexpected_msg]})
        {:noreply, state}
    end
  end

  @impl GenServer
  @doc false
  def terminate(reason, state) do
    LogR.info({:population_mgr_worker, :status, :ok, "population_mgr_worker terminated", [reason]})
    
    if pid = state.population_manager_pid do
      send(pid, :stop)
    end
    
    :ok
  end
end