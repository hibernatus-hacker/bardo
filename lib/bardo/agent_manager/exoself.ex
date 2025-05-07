defmodule Bardo.AgentManager.Exoself do
  @moduledoc """
  The Exoself is responsible for reading a genotype, spawning the corresponding phenotype,
  and then shutting itself down. The phenotype consists of a Cortex, Sensors, Actuators and Neurons.
  """
  
  require Logger
  
  @doc """
  Starts an Exoself process on the specified node.
  """
  @spec start(node()) :: pid()
  def start(node) do
    # For testing purposes, this can return self() or a mock pid
    # In real implementation, this would spawn a process
    if node == Node.self() do
      spawn_link(fn -> __MODULE__.init() end)
    else
      Node.spawn_link(node, fn -> __MODULE__.init() end)
    end
  end
  
  @doc """
  Initializes the exoself process with the given agent ID and operation mode.
  """
  @spec init_phase2(pid(), tuple(), atom()) :: :ok
  def init_phase2(pid, agent_id, op_mode) do
    send(pid, {:init_phase2, agent_id, op_mode})
    :ok
  end
  
  @doc """
  Initialization function for the spawned process.
  """
  def init do
    Process.flag(:trap_exit, true)
    Logger.debug("[exoself] init")
    
    # This is a stub implementation that will be expanded when working on the exoself module
    receive do
      {:init_phase2, _agent_id, _op_mode} ->
        :ok
    end
  end
end