import Config

# Configuration for test environment
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:module],
  level: :warning
