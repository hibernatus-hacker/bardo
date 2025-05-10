#!/usr/bin/env elixir

# Very basic test to verify our DB module fixes

IO.puts("\n=== Basic DB Test ===")

# Compile the DB module
Code.compile_file("lib/bardo/db.ex")
require Logger

# Start the DB server
{:ok, pid} = Bardo.DB.start_link()
IO.puts("Started DB server with PID: #{inspect(pid)}")

# Create a test record
test_id = "test_#{System.os_time()}"
test_record = %{data: %{id: test_id, value: "Hello, world!"}}

# Store the record
IO.puts("\n=== Storing test record ===")
Bardo.DB.store(:test, test_id, test_record)

# Fetch the record
IO.puts("\n=== Fetching test record ===")
fetch_result = Bardo.DB.fetch(:test, test_id)
IO.puts("Fetch result: #{inspect(fetch_result)}")

# Look at the raw ETS contents
IO.puts("\n=== Raw ETS contents ===")
ets_contents = :ets.tab2list(:bardo_db)
IO.puts("ETS contents: #{inspect(ets_contents)}")

IO.puts("\n=== Test completed successfully ===")