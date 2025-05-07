defmodule Bardo.ScapeManager.SectorSupervisor do
  @moduledoc """
  Supervisor for Sector processes.
  
  Sectors are subdivisions of a Scape that help manage agent interactions
  in a distributed and efficient manner.
  """
  
  use Supervisor
  
  alias Bardo.ScapeManager.Sector

  @doc """
  Starts the supervisor.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Starts a new sector process with the given module name and ID.
  """
  @spec start_sector(atom(), atom() | integer()) :: {:ok, pid()}
  def start_sector(mod_name, uid) do
    Supervisor.start_child(__MODULE__, [mod_name, uid])
  end

  @impl Supervisor
  def init([]) do
    sup_flags = %{
      strategy: :simple_one_for_one,
      intensity: 6,
      period: 30
    }
    
    sector = %{
      id: Sector,
      start: {Sector, :start_link, []},
      restart: :transient,
      shutdown: 5000,
      type: :worker,
      modules: [Sector]
    }
    
    children = [sector]
    
    {:ok, {sup_flags, children}}
  end
end