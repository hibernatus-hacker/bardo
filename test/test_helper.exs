# Don't start the application to avoid dependency issues
Application.put_env(:bardo, :start_application, false)
Application.put_env(:bardo, :env, :test)

# Create test/support directory if it doesn't exist
test_support_dir = Path.join(__DIR__, "support")
File.mkdir_p!(test_support_dir)

# Load support files
support_files = Path.wildcard(Path.join(test_support_dir, "*.ex"))
Enum.each(support_files, &Code.require_file/1)

# Ensure helper modules are compiled first
Code.require_file("test_helper/mocks.ex", __DIR__)
Code.require_file("test_helper/model_helper.ex", __DIR__)
Code.require_file("test_helper/db_setup.ex", __DIR__)

# Configure ExUnit
ExUnit.start(
  capture_log: true, 
  trace: false, 
  exclude: [:skip, :pending], 
  include: []
)