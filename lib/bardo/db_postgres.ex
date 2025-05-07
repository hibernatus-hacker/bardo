defmodule Bardo.DBPostgres do
  @moduledoc """
  PostgreSQL database adapter for Bardo using Ecto.
  
  This module provides a PostgreSQL-backed implementation of the Bardo.DB behavior,
  allowing for persistent storage of experiments, populations, agents, and results
  across distributed nodes in environments like fly.io.
  
  ## Configuration
  
  Add to your config.exs:
  
  ```elixir
  config :bardo, Bardo.Repo,
    url: System.get_env("DATABASE_URL"),
    ssl: true,  # Enable SSL for secure connections (recommended for fly.io)
    pool_size: 10
    
  config :bardo, :db,
    adapter: Bardo.DBPostgres
  ```
  
  ## Table Structure
  
  The following tables are managed automatically:
  
  - experiments: Stores experiment data
  - populations: Stores population data
  - genotypes: Stores individual genotypes
  - results: Stores evaluation results
  - distributed_nodes: Tracks distributed nodes and their status
  - distributed_jobs: Manages distributed training jobs
  
  ## Distributed Setup with fly.io
  
  When running on fly.io, you'll want to configure this adapter to connect
  to a Postgres database. Here's a sample fly.toml configuration:
  
  ```toml
  [env]
    DATABASE_URL = "postgres://postgres:postgres@bardo-db.internal:5432/bardo"
    NODE_COOKIE = "your-erlang-cookie-here"
    
  [metrics]
    port = 9091
    path = "/metrics"
  ```
  
  Each fly.io instance will automatically register itself with the database,
  allowing for coordination between nodes and distributed training.
  """
  
  use GenServer
  require Logger
  
  import Ecto.Query
  
  alias Bardo.Repo
  alias Bardo.Schemas.{
    Experiment,
    Population,
    Genotype,
    Result,
    DistributedNode,
    DistributedJob
  }
  
  # Time between automatic DB backups (30 minutes)
  @backup_interval 30 * 60 * 1000
  
  # Time between node heartbeats (1 minute)
  @heartbeat_interval 60 * 1000
  
  # Time between stale node cleanup (5 minutes)
  @node_cleanup_interval 5 * 60 * 1000
  
  # Stale node threshold (3 minutes)
  @node_stale_threshold 3 * 60
  
  @doc """
  Start the Postgres DB service.
  
  ## Parameters
  
  - opts: Options for configuring the database connection
    - :auto_migrate - Whether to run migrations automatically (default: true)
    - :auto_backup - Whether to run automatic backups (default: true)
    - :auto_register - Whether to register this node (default: true)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Store a value in the database.
  
  ## Parameters
  
  - type: Type of data being stored (e.g., :experiment, :population, :genotype)
  - id: Unique identifier for the data
  - value: The data to store
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def store(type, id, value) do
    case do_store(type, id, value) do
      {:ok, _} -> :ok
      error -> error
    end
  end
  
  @doc """
  Read a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to read (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  The value if found, nil otherwise.
  """
  @spec read(term(), atom()) :: term() | nil
  def read(id, type) do
    case do_read(id, type) do
      {:ok, value} -> value
      _ -> nil
    end
  end
  
  @doc """
  Fetch a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to read (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  {:ok, value} on success, {:error, reason} on failure.
  """
  def fetch(id, type) do
    do_read(id, type)
  end
  
  @doc """
  Delete a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to delete (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def delete(id, type) do
    case do_delete(id, type) do
      {:ok, _} -> :ok
      error -> error
    end
  end
  
  @doc """
  Write a value to the database. This is a compatibility function for the Bardo.DB behavior.
  
  ## Parameters
  
  - value: The value to store (must have an :id field in its data map)
  - table: The table/type to write to
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  @spec write(term(), atom()) :: :ok | {:error, term()}
  def write(value, table) do
    id = Map.get(value.data, :id)
    store(table, id, value)
  end
  
  @doc """
  List all values of a given type.
  
  ## Parameters
  
  - type: Type of data to list (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  {:ok, [values]} on success, {:error, reason} on failure.
  """
  def list(type) do
    try do
      values = case type do
        :experiment ->
          Repo.all(Experiment)
          |> Enum.map(fn e -> {String.to_atom(e.id), e} end)
          
        :population ->
          Repo.all(Population)
          |> Enum.map(fn p -> {String.to_atom(p.id), p} end)
          
        :genotype ->
          Repo.all(Genotype)
          |> Enum.map(fn g -> {String.to_atom(g.id), g} end)
          
        :result ->
          Repo.all(Result)
          |> Enum.map(fn r -> {String.to_atom(r.id), r} end)
          
        _ ->
          []
      end
      
      {:ok, values}
    rescue
      e ->
        Logger.error("Error listing #{type}: #{inspect(e)}")
        {:error, "Database error listing #{type}: #{inspect(e)}"}
    end
  end
  
  @doc """
  Register a node in the distributed system.
  
  ## Parameters
  
  - node_name: Name of the node
  - node_info: Additional node information
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def register_node(node_name, node_info) do
    try do
      changeset = DistributedNode.changeset(%DistributedNode{}, %{
        node_name: to_string(node_name),
        info: node_info,
        status: "online",
        last_heartbeat: DateTime.truncate(DateTime.utc_now(), :second)
      })
      
      case Repo.insert(changeset, on_conflict: {:replace, [:info, :status, :last_heartbeat]}, conflict_target: :node_name) do
        {:ok, _node} -> :ok
        {:error, changeset} -> {:error, "Failed to register node: #{inspect(changeset.errors)}"}
      end
    rescue
      e ->
        Logger.error("Error registering node #{node_name}: #{inspect(e)}")
        {:error, "Database error registering node: #{inspect(e)}"}
    end
  end
  
  @doc """
  Update a node's heartbeat to indicate it's still active.
  
  ## Parameters
  
  - node_name: Name of the node
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def heartbeat(node_name) do
    try do
      node = Repo.get(DistributedNode, to_string(node_name))
      
      if node do
        changeset = DistributedNode.changeset(node, %{
          last_heartbeat: DateTime.truncate(DateTime.utc_now(), :second)
        })
        
        case Repo.update(changeset) do
          {:ok, _node} -> :ok
          {:error, changeset} -> {:error, "Failed to update heartbeat: #{inspect(changeset.errors)}"}
        end
      else
        {:error, "Node not found"}
      end
    rescue
      e ->
        Logger.error("Error updating heartbeat for node #{node_name}: #{inspect(e)}")
        {:error, "Database error updating heartbeat: #{inspect(e)}"}
    end
  end
  
  @doc """
  Update a node's status.
  
  ## Parameters
  
  - node_name: Name of the node
  - status: New status ("online", "offline", "busy", etc.)
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def update_node_status(node_name, status) do
    try do
      node = Repo.get(DistributedNode, to_string(node_name))
      
      if node do
        changeset = DistributedNode.changeset(node, %{
          status: to_string(status),
          last_heartbeat: DateTime.truncate(DateTime.utc_now(), :second)
        })
        
        case Repo.update(changeset) do
          {:ok, _node} -> :ok
          {:error, changeset} -> {:error, "Failed to update node status: #{inspect(changeset.errors)}"}
        end
      else
        {:error, "Node not found"}
      end
    rescue
      e ->
        Logger.error("Error updating status for node #{node_name}: #{inspect(e)}")
        {:error, "Database error updating node status: #{inspect(e)}"}
    end
  end
  
  @doc """
  List all registered nodes.
  
  ## Parameters
  
  - status: Filter by status (optional)
  
  ## Returns
  
  {:ok, [nodes]} on success, {:error, reason} on failure.
  """
  def list_nodes(status \\ nil) do
    try do
      query = if status do
        from n in DistributedNode, where: n.status == ^to_string(status)
      else
        DistributedNode
      end
      
      nodes = Repo.all(query)
      
      {:ok, nodes}
    rescue
      e ->
        Logger.error("Error listing nodes: #{inspect(e)}")
        {:error, "Database error listing nodes: #{inspect(e)}"}
    end
  end
  
  @doc """
  Create a distributed training job.
  
  ## Parameters
  
  - job_id: Unique job identifier
  - job_config: Job configuration
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def create_job(job_id, job_config) do
    try do
      changeset = DistributedJob.changeset(%DistributedJob{}, %{
        id: to_string(job_id),
        config: job_config,
        status: "pending"
      })
      
      case Repo.insert(changeset) do
        {:ok, _job} -> :ok
        {:error, changeset} -> {:error, "Failed to create job: #{inspect(changeset.errors)}"}
      end
    rescue
      e ->
        Logger.error("Error creating job #{job_id}: #{inspect(e)}")
        {:error, "Database error creating job: #{inspect(e)}"}
    end
  end
  
  @doc """
  Update a job's status.
  
  ## Parameters
  
  - job_id: Job identifier
  - status: New status ("pending", "running", "completed", "failed")
  - results: Job results (if status is "completed")
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def update_job_status(job_id, status, results \\ nil) do
    try do
      job = Repo.get(DistributedJob, to_string(job_id))
      
      if job do
        attrs = %{status: to_string(status)}
        attrs = if results, do: Map.put(attrs, :results, results), else: attrs
        
        changeset = DistributedJob.changeset(job, attrs)
        
        case Repo.update(changeset) do
          {:ok, _job} -> :ok
          {:error, changeset} -> {:error, "Failed to update job status: #{inspect(changeset.errors)}"}
        end
      else
        {:error, "Job not found"}
      end
    rescue
      e ->
        Logger.error("Error updating job #{job_id} status: #{inspect(e)}")
        {:error, "Database error updating job status: #{inspect(e)}"}
    end
  end
  
  @doc """
  Assign a job to a node.
  
  ## Parameters
  
  - job_id: Job identifier
  - node_name: Name of the node to assign
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def assign_job(job_id, node_name) do
    try do
      job = Repo.get(DistributedJob, to_string(job_id))
      
      if job do
        changeset = DistributedJob.changeset(job, %{
          assigned_node_name: to_string(node_name),
          status: "running"
        })
        
        case Repo.update(changeset) do
          {:ok, _job} -> :ok
          {:error, changeset} -> {:error, "Failed to assign job: #{inspect(changeset.errors)}"}
        end
      else
        {:error, "Job not found"}
      end
    rescue
      e ->
        Logger.error("Error assigning job #{job_id} to node #{node_name}: #{inspect(e)}")
        {:error, "Database error assigning job: #{inspect(e)}"}
    end
  end
  
  @doc """
  Get job information.
  
  ## Parameters
  
  - job_id: Job identifier
  
  ## Returns
  
  {:ok, job_info} on success, {:error, reason} on failure.
  """
  def get_job_info(job_id) do
    try do
      case Repo.get(DistributedJob, to_string(job_id)) do
        nil -> {:error, "Job not found"}
        job -> {:ok, job}
      end
    rescue
      e ->
        Logger.error("Error getting job #{job_id} info: #{inspect(e)}")
        {:error, "Database error getting job info: #{inspect(e)}"}
    end
  end
  
  @doc """
  List all jobs with a given status.
  
  ## Parameters
  
  - status: Job status to filter by (optional)
  
  ## Returns
  
  {:ok, [jobs]} on success, {:error, reason} on failure.
  """
  def list_jobs(status \\ nil) do
    try do
      query = if status do
        from j in DistributedJob, where: j.status == ^to_string(status)
      else
        DistributedJob
      end
      
      jobs = Repo.all(query)
      
      {:ok, jobs}
    rescue
      e ->
        Logger.error("Error listing jobs: #{inspect(e)}")
        {:error, "Database error listing jobs: #{inspect(e)}"}
    end
  end
  
  @doc """
  Create a backup of the database.
  
  ## Parameters
  
  - backup_path: Directory to store the backup (default: "backups")
  
  ## Returns
  
  {:ok, backup_file} on success, {:error, reason} on failure.
  """
  def backup(backup_path \\ "backups") do
    GenServer.call(__MODULE__, {:backup, backup_path})
  end
  
  @doc """
  Restore from a backup.
  
  ## Parameters
  
  - backup_file: Path to the backup file
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def restore(backup_file) do
    GenServer.call(__MODULE__, {:restore, backup_file})
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init(opts) do
    # Get configuration
    auto_migrate = Keyword.get(opts, :auto_migrate, true)
    auto_backup = Keyword.get(opts, :auto_backup, true)
    auto_register = Keyword.get(opts, :auto_register, true)
    
    # Run migrations if configured to do so
    if auto_migrate do
      case run_migrations() do
        :ok -> :ok
        {:error, error} -> Logger.error("Error running migrations: #{inspect(error)}")
      end
    end
    
    # Register this node if configured to do so
    if auto_register do
      node_name = Node.self()
      
      # Only register if we have a distributed node
      if node_name != :nonode@nohost do
        node_info = %{
          hostname: :inet.gethostname() |> elem(1) |> to_string(),
          system_info: %{
            os_type: :os.type(),
            system_architecture: :erlang.system_info(:system_architecture),
            otp_release: :erlang.system_info(:otp_release) |> to_string()
          }
        }
        
        case register_node(node_name, node_info) do
          :ok -> 
            # Start heartbeat process
            schedule_heartbeat()
            # Start stale node cleanup process
            schedule_node_cleanup()
          {:error, error} -> 
            Logger.error("Error registering node: #{inspect(error)}")
        end
      end
    end
    
    # Schedule automatic backups if enabled
    if auto_backup do
      schedule_backup()
    end
    
    {:ok, %{
      auto_migrate: auto_migrate,
      auto_backup: auto_backup,
      auto_register: auto_register
    }}
  end
  
  @impl GenServer
  def handle_call({:backup, backup_path}, _from, state) do
    # Create backup_path directory if it doesn't exist
    File.mkdir_p!(backup_path)
    
    # Generate backup filename with timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    backup_file = Path.join(backup_path, "bardo_backup_#{timestamp}.sql")
    
    # Get database URL from config
    db_url = Application.get_env(:bardo, Bardo.Repo)[:url]
    
    # Execute pg_dump to create backup
    case System.cmd("pg_dump", ["--clean", "-f", backup_file, db_url]) do
      {_, 0} ->
        Logger.info("Database backup created at #{backup_file}")
        {:reply, {:ok, backup_file}, state}
        
      {error, _} ->
        Logger.error("Database backup failed: #{error}")
        {:reply, {:error, "Backup failed: #{error}"}, state}
    end
  end
  
  @impl GenServer
  def handle_call({:restore, backup_file}, _from, state) do
    # Get database URL from config
    db_url = Application.get_env(:bardo, Bardo.Repo)[:url]
    
    # Execute psql to restore from backup
    case System.cmd("psql", ["-f", backup_file, db_url]) do
      {_, 0} ->
        Logger.info("Database restored from #{backup_file}")
        {:reply, :ok, state}
        
      {error, _} ->
        Logger.error("Database restore failed: #{error}")
        {:reply, {:error, "Restore failed: #{error}"}, state}
    end
  end
  
  @impl GenServer
  def handle_info(:backup, state) do
    # Create backup
    backup_path = Path.join([Application.app_dir(:bardo), "backups"])
    {:ok, _} = backup(backup_path)
    
    # Schedule next backup
    schedule_backup()
    
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info(:heartbeat, state) do
    if state.auto_register do
      node_name = Node.self()
      
      # Only send heartbeat if we have a distributed node
      if node_name != :nonode@nohost do
        case heartbeat(node_name) do
          :ok -> :ok
          {:error, error} -> Logger.error("Error sending heartbeat: #{inspect(error)}")
        end
      end
    end
    
    # Schedule next heartbeat
    schedule_heartbeat()
    
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info(:node_cleanup, state) do
    # Cleanup stale nodes
    cleanup_stale_nodes()
    
    # Schedule next cleanup
    schedule_node_cleanup()
    
    {:noreply, state}
  end
  
  # Private functions
  
  # Run database migrations
  defp run_migrations do
    Logger.info("Running PostgreSQL migrations for Bardo")
    
    try do
      Ecto.Migrator.run(Bardo.Repo, Application.app_dir(:bardo, "priv/repo/migrations"), :up, all: true)
      Logger.info("PostgreSQL migrations completed")
      :ok
    rescue
      e ->
        Logger.error("Migration failed: #{inspect(e)}")
        {:error, e}
    end
  end
  
  # Store a value in the database based on its type
  defp do_store(type, id, value) do
    try do
      case type do
        :experiment ->
          attrs = Map.merge(value, %{id: to_string(id)})
          changeset = Experiment.changeset(%Experiment{}, attrs)
          Repo.insert(changeset, on_conflict: {:replace, [:name, :description, :config, :status]}, conflict_target: :id)
          
        :population ->
          attrs = Map.merge(value, %{id: to_string(id)})
          changeset = Population.changeset(%Population{}, attrs)
          Repo.insert(changeset, on_conflict: {:replace, [:name, :generation, :config, :status]}, conflict_target: :id)
          
        :genotype ->
          attrs = Map.merge(value, %{id: to_string(id)})
          changeset = Genotype.changeset(%Genotype{}, attrs)
          Repo.insert(changeset, on_conflict: {:replace, [:data, :fitness, :fitness_details, :metadata]}, conflict_target: :id)
          
        :result ->
          attrs = Map.merge(value, %{id: to_string(id)})
          changeset = Result.changeset(%Result{}, attrs)
          Repo.insert(changeset, on_conflict: {:replace, [:data, :result_type]}, conflict_target: :id)
          
        _ ->
          # Generic storage as an experiment with type prefix
          attrs = %{
            id: "#{type}_#{id}",
            name: "#{type}_#{id}",
            description: "Generic storage for #{type}",
            config: value
          }
          
          changeset = Experiment.changeset(%Experiment{}, attrs)
          Repo.insert(changeset, on_conflict: {:replace, [:config]}, conflict_target: :id)
      end
    rescue
      e ->
        Logger.error("Error storing #{type}:#{id}: #{inspect(e)}")
        {:error, "Database error: #{inspect(e)}"}
    end
  end
  
  # Read a value from the database based on its type
  defp do_read(id, type) do
    try do
      result = case type do
        :experiment ->
          Repo.get(Experiment, to_string(id))
          
        :population ->
          Repo.get(Population, to_string(id))
          
        :genotype ->
          Repo.get(Genotype, to_string(id))
          
        :result ->
          Repo.get(Result, to_string(id))
          
        _ ->
          # Generic storage as an experiment with type prefix
          Repo.get(Experiment, "#{type}_#{id}")
      end
      
      if result do
        {:ok, result}
      else
        {:error, :not_found}
      end
    rescue
      e ->
        Logger.error("Error reading #{type}:#{id}: #{inspect(e)}")
        {:error, "Database error: #{inspect(e)}"}
    end
  end
  
  # Delete a value from the database based on its type
  defp do_delete(id, type) do
    try do
      result = case type do
        :experiment ->
          Repo.get(Experiment, to_string(id))
          |> Repo.delete()
          
        :population ->
          Repo.get(Population, to_string(id))
          |> Repo.delete()
          
        :genotype ->
          Repo.get(Genotype, to_string(id))
          |> Repo.delete()
          
        :result ->
          Repo.get(Result, to_string(id))
          |> Repo.delete()
          
        _ ->
          # Generic storage as an experiment with type prefix
          Repo.get(Experiment, "#{type}_#{id}")
          |> Repo.delete()
      end
      
      case result do
        {:ok, _} = success -> success
        {:error, _} = error -> error
        nil -> {:error, :not_found}
      end
    rescue
      e ->
        Logger.error("Error deleting #{type}:#{id}: #{inspect(e)}")
        {:error, "Database error: #{inspect(e)}"}
    end
  end
  
  # Schedule automatic backup
  defp schedule_backup do
    Process.send_after(self(), :backup, @backup_interval)
  end
  
  # Schedule node heartbeat
  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end
  
  # Schedule stale node cleanup
  defp schedule_node_cleanup do
    Process.send_after(self(), :node_cleanup, @node_cleanup_interval)
  end
  
  # Cleanup stale nodes
  defp cleanup_stale_nodes do
    try do
      # Find stale nodes (no heartbeat for more than @node_stale_threshold seconds)
      query = DistributedNode.stale(DistributedNode, @node_stale_threshold)
      stale_nodes = Repo.all(query)
      
      # Mark them as offline
      Enum.each(stale_nodes, fn node ->
        changeset = DistributedNode.changeset(node, %{status: "offline"})
        Repo.update(changeset)
        
        Logger.info("Marked node #{node.node_name} as offline due to stale heartbeat")
      end)
      
      # Find failed jobs on offline nodes
      offline_nodes = Repo.all(from n in DistributedNode, where: n.status == "offline", select: n.node_name)
      
      if offline_nodes != [] do
        query = from j in DistributedJob,
                where: j.assigned_node_name in ^offline_nodes and j.status == "running"
                
        stalled_jobs = Repo.all(query)
        
        # Mark them as failed
        Enum.each(stalled_jobs, fn job ->
          changeset = DistributedJob.changeset(job, %{
            status: "failed",
            results: %{
              error: "Node went offline during job execution",
              failed_at: DateTime.utc_now() |> DateTime.to_iso8601()
            }
          })
          
          Repo.update(changeset)
          
          Logger.info("Marked job #{job.id} as failed due to offline node #{job.assigned_node_name}")
        end)
      end
      
      :ok
    rescue
      e ->
        Logger.error("Error during stale node cleanup: #{inspect(e)}")
        {:error, "Stale node cleanup error: #{inspect(e)}"}
    end
  end
end