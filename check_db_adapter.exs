# Script to check database adapter functionality
# Run with: mix run check_db_adapter.exs

# Start the application
Application.ensure_all_started(:bardo)

IO.puts("=========================================")
IO.puts("Database Adapter Functionality Check")
IO.puts("=========================================")

# Test database operations with the currently configured adapter
IO.puts("\nTesting database operations...")

# Store a test value
experiment_id = "test_experiment_#{:rand.uniform(1000)}"
experiment_data = %{
  name: "Test Experiment",
  description: "A test experiment for adapter functionality check",
  config: %{
    population_size: 10,
    generations: 5
  },
  status: "pending"
}

IO.puts("- Storing test experiment with ID: #{experiment_id}")
result = Bardo.DBInterface.store(:experiment, experiment_id, experiment_data)
IO.puts("  Result: #{inspect(result)}")

# Read the stored value
IO.puts("- Reading test experiment")
read_result = Bardo.DBInterface.read(experiment_id, :experiment)
IO.puts("  Result: #{inspect(read_result)}")

# List all experiments
IO.puts("- Listing all experiments")
list_result = Bardo.DBInterface.list(:experiment)
IO.puts("  Count: #{Enum.count(list_result)}")

# Delete the test value
IO.puts("- Deleting test experiment")
delete_result = Bardo.DBInterface.delete(experiment_id, :experiment)
IO.puts("  Result: #{inspect(delete_result)}")

# Create a backup
IO.puts("\nTesting backup functionality...")
backup_result = Bardo.DBInterface.backup("test_backups")
IO.puts("- Backup result: #{inspect(backup_result)}")

IO.puts("\nDatabase adapter check completed!")