defmodule Bardo.AgentManager.AgentWorker do
  @moduledoc """
  The AgentWorker is responsible for spawning the Exoself process
  (genotype) which in turn spawns the Cortex, Sensors, Neurons, Actuator
  (phenotype) and maybe the private scape.
  """
  
  use GenServer
  require Logger
  
  alias Bardo.AgentManager.Exoself
  alias Bardo.ScapeManager.ScapeManagerClient
  
  # Client API
  
  @doc """
  The start_link function spawns the AgentWorker server.
  """
  @spec start_link(tuple(), atom()) :: {:ok, pid()}
  def start_link(agent_id, op_mode) do
    GenServer.start_link(__MODULE__, {agent_id, op_mode}, [])
  end
  
  # Server Callbacks
  
  @impl true
  def init({agent_id, op_mode}) do
    Process.flag(:trap_exit, true)
    Logger.debug("[agent_worker] init: #{inspect(agent_id)}")
    GenServer.cast(self(), :init_phase2)
    
    state = %{
      exoself_pid: nil,
      agent_id: agent_id,
      op_mode: op_mode
    }
    
    {:ok, state}
  end
  
  @impl true
  def handle_call(_request, _from, state) do
    Logger.warning("[agent_worker] unexpected handle_call")
    {:reply, :ok, state}
  end
  
  @impl true
  def handle_cast(:init_phase2, state) do
    new_state = start_exoself(state)
    {:noreply, new_state}
  end
  
  @impl true
  def handle_info(info, state) do
    case info do
      {:EXIT, _pid, :normal} ->
        {:noreply, state}
        
      {:EXIT, pid, :shutdown} ->
        Logger.debug("[agent_worker] shutdown message from #{inspect(pid)}")
        {:stop, :shutdown, state}
        
      {:EXIT, pid, :terminate_agent} ->
        Logger.debug("[agent_worker] terminate_agent message from #{inspect(pid)}")
        {:stop, :normal, state}
        
      {:EXIT, pid, reason} ->
        Logger.warning("[agent_worker] exit message from #{inspect(pid)}: #{inspect(reason)}")
        {:stop, reason, state}
        
      unexpected_msg ->
        Logger.warning("[agent_worker] unexpected info message: #{inspect(unexpected_msg)}")
        {:noreply, state}
    end
  end
  
  @impl true
  def terminate(reason, state) do
    agent_id = state.agent_id
    
    case :ets.whereis(:agent_ids_pids) do
      :undefined ->
        :ok
        
      _tid ->
        Logger.debug("[agent_worker] terminate: #{inspect(reason)}")
        
        case :ets.member(:agent_ids_pids, agent_id) do
          true ->
            :ets.delete(:agent_ids_pids, agent_id)
          false ->
            :ok
        end
        
        ScapeManagerClient.leave(agent_id, [])
    end
  end
  
  # Internal functions
  
  defp start_exoself(state) do
    pid = Exoself.start(node())
    :ok = Exoself.init_phase2(pid, state.agent_id, state.op_mode)
    %{state | exoself_pid: pid}
  end
end