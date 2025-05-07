defmodule Bardo.AgentManager.AgentWorkerSupervisor do
  @moduledoc """
  Dynamic supervisor for agent workers.
  
  This module is a simple alias for the DynamicSupervisor used to manage
  individual agent worker processes. It provides helper functions for
  starting, stopping, and managing agents.
  """
  
  alias Bardo.AgentManager.AgentWorker
  
  @doc """
  Start a new agent worker under the dynamic supervisor.
  
  ## Parameters
    * `agent_id` - Unique identifier for the agent
    * `params` - Parameters for the agent, including morphology, id, etc.
    
  ## Returns
    * `{:ok, pid}` - If the worker was started successfully
    * `{:error, reason}` - If there was an error starting the worker
  """
  @spec start_agent(binary(), map()) :: DynamicSupervisor.on_start_child()
  def start_agent(agent_id, params) do
    # Ensure agent ID is valid
    agent_id = if is_atom(agent_id), do: agent_id, else: String.to_atom("agent_#{agent_id}")
    
    # Start the agent worker
    child_spec = %{
      id: agent_id,
      start: {AgentWorker, :start_link, [agent_id, params]},
      restart: :transient,  # Don't restart if agent terminates normally
      shutdown: 5000,
      type: :worker
    }
    
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
  
  @doc """
  Stop an agent worker.
  
  ## Parameters
    * `agent_id` - Unique identifier for the agent
    
  ## Returns
    * `:ok` - If the worker was stopped successfully
    * `{:error, :not_found}` - If the worker was not found
  """
  @spec stop_agent(binary() | atom()) :: :ok | {:error, :not_found}
  def stop_agent(agent_id) do
    agent_id = if is_atom(agent_id), do: agent_id, else: String.to_atom("agent_#{agent_id}")
    
    # Find the agent worker's PID
    case find_agent_pid(agent_id) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
  
  @doc """
  Get the count of running agents.
  
  ## Returns
    * `{:ok, count}` - The number of running agent workers
  """
  @spec count_agents() :: {:ok, non_neg_integer()}
  def count_agents() do
    {:ok, DynamicSupervisor.count_children(__MODULE__).active}
  end
  
  @doc """
  List all running agent IDs.
  
  ## Returns
    * `{:ok, [atom()]}` - List of running agent IDs
  """
  @spec list_agents() :: {:ok, [atom()]}
  def list_agents() do
    children = DynamicSupervisor.which_children(__MODULE__)
    
    agent_ids = Enum.map(children, fn {_, pid, _, _} ->
      case Process.info(pid, :registered_name) do
        {:registered_name, name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    {:ok, agent_ids}
  end
  
  # Private helpers
  
  # Find the PID of an agent by its ID
  defp find_agent_pid(agent_id) do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.find_value(fn {_, pid, _, _} ->
      case Process.info(pid, :registered_name) do
        {:registered_name, ^agent_id} -> pid
        _ -> nil
      end
    end)
  end
end