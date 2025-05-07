defmodule Bardo.PopulationManager.PopulationManagerSupervisor do
  @moduledoc """
  Dynamic supervisor for population manager workers.
  
  This module provides helper functions for starting, stopping and managing
  population workers, which handle the evolutionary process for populations
  of neural networks.
  """
  
  use DynamicSupervisor
  alias Bardo.PopulationManager.PopulationManagerWorker
  
  @doc """
  Starts the supervisor.
  
  ## Parameters
    * `args` - Optional arguments for the supervisor
    
  ## Returns
    * `{:ok, pid}` - PID of the started supervisor process
  """
  def start_link(args \\ []) do
    DynamicSupervisor.start_link(__MODULE__, args, name: __MODULE__)
  end
  
  @impl DynamicSupervisor
  def init(_args) do
    # Initialize ETS tables
    create_ets_tables()
    
    # Configure supervisor
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 10,
      max_seconds: 60
    )
  end
  
  @doc """
  Start a new population worker under the dynamic supervisor.
  
  ## Parameters
    * `population_id` - Unique identifier for the population
    * `params` - Parameters for the population, including experiment ID, size, etc.
    
  ## Returns
    * `{:ok, pid}` - If the worker was started successfully
    * `{:error, reason}` - If there was an error starting the worker
  """
  @spec start_population(binary() | atom(), map()) :: DynamicSupervisor.on_start_child()
  def start_population(population_id, params) do
    # Ensure population ID is valid
    population_id = if is_atom(population_id) do
      population_id
    else
      String.to_atom("population_#{population_id}")
    end
    
    # Start the population worker
    child_spec = %{
      id: population_id,
      start: {PopulationManagerWorker, :start_link, [population_id, params]},
      restart: :transient,  # Don't restart if population terminates normally
      shutdown: 30_000,
      type: :worker
    }
    
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end
  
  @doc """
  Stop a population worker.
  
  ## Parameters
    * `population_id` - Unique identifier for the population
    
  ## Returns
    * `:ok` - If the worker was stopped successfully
    * `{:error, :not_found}` - If the worker was not found
  """
  @spec stop_population(binary() | atom()) :: :ok | {:error, :not_found}
  def stop_population(population_id) do
    population_id = if is_atom(population_id) do
      population_id
    else
      String.to_atom("population_#{population_id}")
    end
    
    # Find the population worker's PID
    case find_population_pid(population_id) do
      nil -> {:error, :not_found}
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
  
  @doc """
  Get the count of running populations.
  
  ## Returns
    * `{:ok, count}` - The number of running population workers
  """
  @spec count_populations() :: {:ok, non_neg_integer()}
  def count_populations() do
    {:ok, DynamicSupervisor.count_children(__MODULE__).active}
  end
  
  @doc """
  List all running population IDs.
  
  ## Returns
    * `{:ok, [atom()]}` - List of running population IDs
  """
  @spec list_populations() :: {:ok, [atom()]}
  def list_populations() do
    children = DynamicSupervisor.which_children(__MODULE__)
    
    population_ids = Enum.map(children, fn {_, pid, _, _} ->
      case Process.info(pid, :registered_name) do
        {:registered_name, name} -> name
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    
    {:ok, population_ids}
  end
  
  # Private helpers
  
  # Create the ETS tables used for population management
  defp create_ets_tables() do
    # Make sure tables don't already exist before creating them
    table_names = [:population_status, :evaluations, :active_agents, :inactive_agents]
    
    Enum.each(table_names, fn table_name ->
      if :ets.whereis(table_name) == :undefined do
        :ets.new(table_name, [:set, :public, :named_table,
          {:write_concurrency, true}, {:read_concurrency, true}])
      end
    end)
  end
  
  # Find the PID of a population by its ID
  defp find_population_pid(population_id) do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.find_value(fn {_, pid, _, _} ->
      case Process.info(pid, :registered_name) do
        {:registered_name, ^population_id} -> pid
        _ -> nil
      end
    end)
  end
end