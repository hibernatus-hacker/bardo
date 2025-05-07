defmodule Bardo.AgentManager.Supervisor do
  @moduledoc """
  Supervisor for the AgentManager subsystem.
  
  This supervisor manages the various components of the AgentManager subsystem,
  including the AgentManager itself and the dynamic supervisor for agent workers.
  """
  
  use Supervisor
  
  alias Bardo.AgentManager
  alias Bardo.AgentManager.AgentWorkerSupervisor
  
  @doc """
  Starts the supervisor.
  """
  @spec start_link(any()) :: {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  @impl true
  def init(_args) do
    children = [
      # Dynamic supervisor for agent workers
      {DynamicSupervisor, strategy: :one_for_one, name: AgentWorkerSupervisor},
      
      # AgentManager - core process that coordinates agent creation and evaluation
      {AgentManager, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end