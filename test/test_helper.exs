# Don't start the application to avoid dependency issues
Application.put_env(:bardo, :start_application, false)
Application.put_env(:bardo, :env, :test)

# Ensure helper modules are compiled first
Code.require_file("test_helper/mocks.ex", __DIR__)
Code.require_file("test_helper/model_helper.ex", __DIR__)

# Configure ExUnit
ExUnit.start(
  capture_log: true, 
  trace: false, 
  exclude: [:skip, :pending], 
  include: []
)