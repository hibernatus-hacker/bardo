defmodule Bardo.PopulationManager.Supervisor do
  @moduledoc """
  Supervisor for the PopulationManager system.
  
  This supervisor manages the population manager and population worker processes,
  which are responsible for evolving populations of neural networks for various tasks.
  """
  
  use Supervisor
  
  alias Bardo.PopulationManager.PopulationManagerSupervisor
  
  @doc """
  Starts the supervisor.
  
  ## Parameters
    * `args` - Optional arguments for the supervisor
    
  ## Returns
    * `{:ok, pid}` - PID of the started supervisor process
  """
  @spec start_link(any()) :: {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  @impl true
  def init(_args) do
    children = [
      # Dynamic supervisor for population manager workers
      {DynamicSupervisor, strategy: :one_for_one, name: PopulationManagerSupervisor},
      
      # Regular population manager
      {Bardo.PopulationManager.PopulationManager, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end