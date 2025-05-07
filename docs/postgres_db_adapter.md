# PostgreSQL Database Adapter for Bardo with Ecto

This document describes how to set up and use the PostgreSQL database adapter for Bardo, which provides persistent storage for experiments, populations, genotypes, and enables distributed training across multiple nodes using Ecto.

## Overview

The `Bardo.DBPostgres` module is a PostgreSQL-backed implementation of the `Bardo.DB` behavior using Ecto, designed for:

1. Persistent storage of neuroevolution experiments
2. Coordination between distributed nodes
3. Tracking and managing distributed training jobs
4. Automatic backups and migrations

This adapter is particularly useful when deploying Bardo on platforms like fly.io, where distributed training across multiple nodes can be leveraged effectively.

## Configuration

### Basic Configuration

Add the following to your configuration:

```elixir
# config/postgres.exs
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

### Loading the Configuration

Include the postgres.exs file in your config.exs:

```elixir
# config/config.exs
import_config "postgres.exs"
```

Or, for environment-specific configuration:

```elixir
# config/prod.exs
import_config "postgres.exs"
```

## Database Schema

The PostgreSQL adapter uses the following Ecto schemas:

1. `Bardo.Schemas.Experiment` - Stores experiment configurations and metadata
2. `Bardo.Schemas.Population` - Stores population data for each experiment
3. `Bardo.Schemas.Genotype` - Stores individual genotypes with their fitness values
4. `Bardo.Schemas.Result` - Stores evaluation results from experiments
5. `Bardo.Schemas.DistributedNode` - Tracks connected nodes and their status
6. `Bardo.Schemas.DistributedJob` - Manages distributed training jobs

## Migrations

The migrations are automatically run when the application starts (controlled by the `auto_migrate` config option). All necessary tables and indexes are created automatically.

## Distributed Training with fly.io

### Setting Up flyctl

1. Create a fly.toml file:

```toml
app = "bardo"
kill_signal = "SIGTERM"
kill_timeout = 60
processes = []

[env]
  # Adjust these for your deployment
  DATABASE_URL = "postgres://postgres:postgres@bardo-db.internal:5432/bardo"
  NODE_COOKIE = "your-secure-cookie-here"
  POOL_SIZE = "10"
  DB_SSL = "true"
  MIX_ENV = "prod"

# Connect to fly.io's private networking
[mounts]
  source = "bardo_data"
  destination = "/data"

[deploy]
  strategy = "canary"
```

2. Launch a PostgreSQL database on fly.io:

```bash
flyctl postgres create --name bardo-db
```

3. Deploy your Bardo application:

```bash
flyctl deploy
```

4. Scale to multiple instances for distributed training:

```bash
flyctl scale count 3
```

### Node Registration

Each Bardo node will automatically register itself with the database upon startup, allowing for coordination between nodes. You can check registered nodes with:

```elixir
{:ok, nodes} = Bardo.DBPostgres.list_nodes()
```

### Creating Distributed Jobs

To create a distributed training job:

```elixir
job_id = "training_job_#{:os.system_time(:millisecond)}"
job_config = %{
  experiment_id: "forex_trading_experiment",
  population_size: 100,
  generations: 500,
  fitness_function: :sharpe_ratio,
  substrate_encoding: :time_price_indicator
}

:ok = Bardo.DBPostgres.create_job(job_id, job_config)
```

### Monitoring Jobs

You can monitor job status:

```elixir
{:ok, jobs} = Bardo.DBPostgres.list_jobs(:running)
```

Or get details of a specific job:

```elixir
{:ok, job_info} = Bardo.DBPostgres.get_job_info("job_123")
```

## Example: Using the PostgreSQL Adapter

Here's a complete example of how to use the PostgreSQL adapter:

```elixir
# Configure the application to use PostgreSQL
Application.put_env(:bardo, Bardo.Repo, [
  url: "postgres://postgres:postgres@localhost:5432/bardo",
  pool_size: 10
])

Application.put_env(:bardo, :db, [
  adapter: Bardo.DBPostgres
])

# Start the application
{:ok, _} = Application.ensure_all_started(:bardo)

# Create an experiment
experiment = %{
  id: "experiment_1",
  name: "Forex Trading Experiment",
  description: "Testing NEAT algorithm on forex data",
  config: %{
    population_size: 100,
    generations: 50,
    fitness_function: :sharpe_ratio
  }
}

:ok = Bardo.DBPostgres.store(:experiment, "experiment_1", experiment)

# Create a population
population = %{
  id: "population_1",
  experiment_id: "experiment_1",
  name: "Initial Population",
  generation: 0,
  config: %{
    selection_algorithm: :tournament,
    tournament_size: 3
  }
}

:ok = Bardo.DBPostgres.store(:population, "population_1", population)

# Create a genotype
genotype = %{
  id: "genotype_1",
  population_id: "population_1",
  data: %{
    neurons: [...],
    connections: [...]
  },
  fitness: 0.75,
  fitness_details: %{
    sharpe_ratio: 0.75,
    max_drawdown: 0.15,
    total_return: 0.25
  }
}

:ok = Bardo.DBPostgres.store(:genotype, "genotype_1", genotype)

# Create a distributed job
:ok = Bardo.DBPostgres.create_job("job_1", %{
  experiment_id: "experiment_1",
  population_size: 100,
  generations: 50
})

# List all experiments
{:ok, experiments} = Bardo.DBPostgres.list(:experiment)

# Get a specific experiment
experiment = Bardo.DBPostgres.read("experiment_1", :experiment)
```

## Backups and Migrations

### Manual Backups

```elixir
{:ok, backup_file} = Bardo.DBPostgres.backup("/path/to/backups")
```

### Restoring from Backup

```elixir
:ok = Bardo.DBPostgres.restore("/path/to/backups/bardo_backup_2023-01-01.sql")
```

## Error Handling

The adapter includes comprehensive error handling for database operations:

- Connection errors are logged and returned as `{:error, reason}`
- Failed queries are caught and logged with detailed error information
- Automatic reconnection is attempted for temporary connection issues

## Advantages of Using Ecto

1. **Schema Validation**: Ecto changesets validate data before insertion
2. **Query Composability**: Ecto queries can be composed and reused
3. **Migrations**: Automatic database migrations for schema changes
4. **Associations**: Easily navigate between related records
5. **Type Safety**: Ecto provides type conversion and validation
6. **Transactions**: Wrap multiple operations in a transaction

## Performance Considerations

- Use appropriate `pool_size` based on your workload (default: 10)
- For write-heavy workloads, increase `pool_size` and consider sharding
- For large datasets, use pagination when reading results
- Monitor performance with:
  - Postgres metrics (connection count, query times)
  - Application metrics (queue times, request throughput)