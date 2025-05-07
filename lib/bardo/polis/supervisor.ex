defmodule Bardo.Polis.Supervisor do
  @moduledoc """
  Supervisor for the Polis systems.
  
  The Polis manages Population, Experiment, and ScapeManager subsystems.
  """
  
  use Supervisor
  
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  @impl true
  def init(_args) do
    children = [
      # Start the ScapeManager supervisor
      {Bardo.ScapeManager.Supervisor, []},
      
      # Start the PopulationManager supervisor
      {Bardo.PopulationManager.Supervisor, []},
      
      # Start the ExperimentManager supervisor
      {Bardo.ExperimentManager.Supervisor, []}
    ]
    
    Supervisor.init(children, strategy: :one_for_one)
  end
end