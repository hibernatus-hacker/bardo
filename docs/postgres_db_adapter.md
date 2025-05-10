# PostgreSQL Database Adapter

This guide explains how to use the PostgreSQL database adapter for persistent storage with Bardo.

## Overview

Bardo can store its data in either:

1. **ETS (Erlang Term Storage)**: The default in-memory storage, which is fast but non-persistent
2. **PostgreSQL**: A persistent database that allows for distributed operation and data persistence

The PostgreSQL adapter is recommended for:
- Production deployments
- Distributed training across multiple nodes
- Long-running experiments where persistence is important
- Cases where you need to analyze results after the process ends

## Configuration

### 1. Set up a PostgreSQL Database

First, ensure you have a PostgreSQL database available. You can run PostgreSQL locally or use a cloud service.

```bash
# Example for setting up a local PostgreSQL database
createdb bardo
```

### 2. Configure Bardo

Update your configuration to use PostgreSQL:

**config/dev.exs**:
```elixir
import Config

# Import PostgreSQL configuration
import_config "postgres.exs"
```

**config/postgres.exs**:
```elixir
import Config

# Configuration for Ecto repo
config :bardo, Bardo.Repo,
  url: System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/bardo",
  ssl: String.to_existing_atom(System.get_env("DB_SSL") || "false"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  queue_target: 5000,
  queue_interval: 1000

# Configuration for Postgres-backed database for Bardo
config :bardo, :db,
  adapter: Bardo.DBPostgres,
  auto_migrate: true,
  auto_backup: true,
  auto_register: true
```

### 3. Run Migrations

Initialize the database schema:

```bash
# Set the database URL
export DATABASE_URL="postgres://postgres:postgres@localhost:5432/bardo"

# Run the setup script
mix run scripts/setup_postgres.exs
```

## Usage

Once configured, Bardo will automatically use PostgreSQL for storage. All core functions will work the same way, but data will be persistent across restarts.

### Using the DB Interface

In your code, use the `Bardo.DBInterface` module which automatically routes calls to the configured adapter:

```elixir
# Read a value
value = Bardo.DBInterface.read(id, :experiment)

# Write a value
:ok = Bardo.DBInterface.write(value, :experiment)

# List all experiments
experiments = Bardo.DBInterface.list(:experiment)
```

### Distributed Setup

For distributed setup (multiple nodes):

1. Ensure all nodes point to the same PostgreSQL database
2. Set the same Erlang cookie on all nodes
3. Each node will automatically register itself with the database

Example for running with distributed nodes:

```bash
# Node 1
elixir --name node1@127.0.0.1 --cookie bardo_secret -S mix run --no-halt

# Node 2
elixir --name node2@127.0.0.1 --cookie bardo_secret -S mix run --no-halt
```

## Working with Database Records

You can directly work with the Ecto schemas when needed:

```elixir
alias Bardo.Repo
alias Bardo.Schemas.{Experiment, Population, Genotype, Result}

# Querying experiments
experiments = Repo.all(Experiment)

# Get a specific experiment
experiment = Repo.get(Experiment, "my_experiment_id")

# Query based on status
running_experiments = Repo.all(from e in Experiment, where: e.status == "running")
```

## Backups

The PostgreSQL adapter includes automatic backup functionality:

```elixir
# Create a manual backup
{:ok, backup_file} = Bardo.DBInterface.backup("backups")
```

Backups are also created automatically every 30 minutes if `auto_backup: true` is set in the configuration.

## Troubleshooting

### Connection Issues

If you're having trouble connecting to the database:

1. Verify the `DATABASE_URL` is correct
2. Ensure PostgreSQL is running and accepts connections
3. Check if the database exists
4. Verify that the Postgres user has appropriate permissions

### Migration Issues

If migrations fail:

1. Check that the database exists and is accessible
2. Verify that the user has permissions to create tables
3. Look at the detailed error messages in the logs

## Advanced Usage

### Custom Queries

For advanced usage, you can directly use Ecto queries:

```elixir
import Ecto.Query

# Get the best genotype for an experiment
query = from g in Genotype,
  join: p in Population, on: g.population_id == p.id,
  where: p.experiment_id == ^experiment_id,
  order_by: [desc: g.fitness],
  limit: 1

best_genotype = Repo.one(query)
```

### Node Management

You can monitor and manage distributed nodes:

```elixir
alias Bardo.DBPostgres

# List all nodes
{:ok, nodes} = DBPostgres.list_nodes()

# List only online nodes
{:ok, online_nodes} = DBPostgres.list_nodes("online")

# Update a node's status
:ok = DBPostgres.update_node_status("node@hostname", "busy")
```

### Job Distribution

For distributed training:

```elixir
# Create a job
:ok = DBPostgres.create_job("job_123", %{task: "train", parameters: %{...}})

# Assign to a node
:ok = DBPostgres.assign_job("job_123", "node@hostname")

# Update job status with results
:ok = DBPostgres.update_job_status("job_123", "completed", %{fitness: 0.95})
```

## Performance Considerations

- For very intensive training with many small mutations, the ETS adapter may be faster
- For distributed scenarios with multiple machines, PostgreSQL is required
- Consider increasing the `pool_size` for high-concurrency scenarios
EOF < /dev/null
