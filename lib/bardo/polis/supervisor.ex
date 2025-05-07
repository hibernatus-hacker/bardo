defmodule Bardo.Polis.Supervisor do
  @moduledoc """
  Supervisor for the Polis systems.
  
  The Polis manages the core subsystems of Bardo:
  
  - AgentManager: Handles individual neural network agents
  - PopulationManager: Manages populations of evolving agents
  - ExperimentManager: Coordinates experiments across populations
  - ScapeManager: Provides evaluation environments for agents
  
  Each subsystem has its own supervisor hierarchy to ensure proper fault
  tolerance and lifecycle management.
  """
  
  use Supervisor
  
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
      # Start the ScapeManager supervisor
      # This needs to start first, as other components depend on scapes
      {Bardo.ScapeManager.Supervisor, []},
      
      # Start the AgentManager supervisor
      # Individual agents are managed by this supervisor
      {Bardo.AgentManager.Supervisor, []},
      
      # Start the PopulationManager supervisor
      # Populations of agents are managed by this supervisor
      {Bardo.PopulationManager.Supervisor, []},
      
      # Start the ExperimentManager supervisor
      # Experiments coordinate populations and their evaluation
      {Bardo.ExperimentManager.Supervisor, []}
    ]
    
    # Use one_for_one strategy so that if one subsystem fails,
    # it doesn't bring down the others
    Supervisor.init(children, strategy: :one_for_one)
  end
end