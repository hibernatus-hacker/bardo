import Config

# Configuration for development environment
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:module]
