import Config

# Configuration for production environment
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:module],
  level: :info
