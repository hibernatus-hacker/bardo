# Script to set up the PostgreSQL database for Bardo
# Run with: DATABASE_URL="postgres://postgres:postgres@localhost:5432/bardo" mix run scripts/setup_postgres.exs

require Logger

# Start Ecto
Logger.info("Starting Ecto...")
Application.ensure_all_started(:ecto_sql)

# Configure repo
if System.get_env("DATABASE_URL") do
  Logger.info("Configuring Repo with: #{System.get_env("DATABASE_URL")}")
  
  config = [
    url: System.get_env("DATABASE_URL"),
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    ssl: String.to_existing_atom(System.get_env("DB_SSL") || "false"),
    queue_target: 5000,
    queue_interval: 1000
  ]
  
  # Set repo config
  Application.put_env(:bardo, Bardo.Repo, config)
else
  Logger.error("DATABASE_URL environment variable is not set!")
  Logger.error("Usage: DATABASE_URL=\"postgres://postgres:postgres@localhost:5432/bardo\" mix run scripts/setup_postgres.exs")
  System.halt(1)
end

# Start the repo
Logger.info("Starting Repo...")
{:ok, _} = Bardo.Repo.start_link()

# Create the database
Logger.info("Checking database...")
try do
  # Check if database exists and can be queried
  Bardo.Repo.query!("SELECT 1")
  Logger.info("Database connection successful")
rescue
  e ->
    Logger.error("Database error: #{inspect(e)}")
    System.halt(1)
end

# Run migrations
Logger.info("Running migrations...")
try do
  Ecto.Migrator.run(Bardo.Repo, Application.app_dir(:bardo, "priv/repo/migrations"), :up, all: true)
  Logger.info("Migrations completed successfully")
rescue
  e ->
    Logger.error("Migration error: #{inspect(e)}")
    System.halt(1)
end

# Create some initial data
Logger.info("Creating initial data...")

# Create a test experiment
experiment_id = "test_experiment"
experiment = %Bardo.Schemas.Experiment{
  id: experiment_id,
  name: "Test Experiment",
  description: "A test experiment created during initialization",
  config: %{
    population_size: 20,
    generations: 10,
    mutation_rate: 0.3
  },
  status: "completed"
}

{:ok, _} = Bardo.Repo.insert(experiment, on_conflict: :replace_all, conflict_target: :id)

# Register the current node
current_node = Node.self()
if current_node != :nonode@nohost do
  node_info = %{
    hostname: :inet.gethostname() |> elem(1) |> to_string(),
    system_info: %{
      os_type: :os.type(),
      system_architecture: :erlang.system_info(:system_architecture),
      otp_release: :erlang.system_info(:otp_release) |> to_string()
    }
  }
  
  node = %Bardo.Schemas.DistributedNode{
    node_name: to_string(current_node),
    info: node_info,
    status: "online",
    last_heartbeat: DateTime.truncate(DateTime.utc_now(), :second)
  }
  
  {:ok, _} = Bardo.Repo.insert(node, on_conflict: :replace_all, conflict_target: :node_name)
  Logger.info("Registered node: #{current_node}")
else
  Logger.warning("Not running in distributed mode, skipping node registration")
end

Logger.info("Setup completed successfully!")