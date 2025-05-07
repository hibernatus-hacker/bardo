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

# Node configuration for distributed setup
config :bardo, :distributed,
  heartbeat_interval: 60_000,  # 60 seconds
  node_cleanup_interval: 300_000,  # 5 minutes
  node_stale_threshold: 180  # 3 minutes - nodes inactive longer than this are marked offline