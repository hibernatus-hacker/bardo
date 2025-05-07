import Config

# Configuration for test environment
config :logger, :console,
  format: "[$level] $message\n",
  metadata: [:module],
  level: :warning

# Don't start the full application in test mode
config :bardo, start_application: false

# Default values for AppConfig
config :bardo, ro_signal: [0.0]
config :bardo, output_sat_limit: 1.0
