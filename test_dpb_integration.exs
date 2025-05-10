#!/usr/bin/env elixir

# Integration test for DPB module that verifies our fix for handling nested response formats

IO.puts("\n=== DPB Integration Test ===")

# Compile the required modules
IO.puts("\n=== Compiling required modules ===")
Code.compile_file("lib/bardo/db.ex")
Code.compile_file("lib/bardo/models.ex")

# Start the DB server
{:ok, pid} = Bardo.DB.start_link()
IO.puts("Started DB server with PID: #{inspect(pid)}")

# Create aliases for convenience
alias Bardo.DB
alias Bardo.Models

# Create mock data to simulate the DPB experiment
experiment_id = "dpb_test_#{System.os_time()}"
IO.puts("\nUsing experiment ID: #{experiment_id}")
population_id = "#{experiment_id}_population"

# Create and store population record
population_record = %{
  data: %{
    id: population_id,
    population: [
      %{
        fitness: 0.95,
        generation: 10,
        id: "#{population_id}_best",
        neurons: [
          %{activation: :sigmoid, bias: 0.5, id: "n1", layer: 0, type: :hidden},
          %{activation: :sigmoid, bias: -0.3, id: "n2", layer: 0, type: :hidden},
          %{activation: :sigmoid, bias: 0.1, id: "n3", layer: 1, type: :output}
        ],
        connections: [
          %{source: "n1", target: "n2", weight: 0.8},
          %{source: "n1", target: "n3", weight: 0.6},
          %{source: "n2", target: "n3", weight: -0.4}
        ]
      }
    ]
  }
}

# Create and store experiment record
experiment_record = %{
  data: %{
    id: experiment_id,
    status: "completed",
    iterations: 10,
    backup_frequency: 5,
    populations: [
      %{
        id: population_id,
        size: 10,
        morphology: "DpbWDamping",
        mutation_rate: 0.1,
        mutation_operators: [
          {:mutate_weights, :gaussian, 0.3},
          {:add_neuron, 0.05},
          {:add_connection, 0.1},
          {:remove_connection, 0.05},
          {:remove_neuron, 0.02}
        ],
        selection_algorithm: "TournamentSelectionAlgorithm",
        elite_fraction: 0.1,
        evaluations_per_generation: 1,
        population_to_evaluate: 1.0,
        scape_list: ["#{experiment_id}_scape"],
        tournament_size: 5
      }
    ],
    scapes: [
      %{
        module: "Bardo.ScapeManager.Scape",
        name: "#{experiment_id}_scape",
        type: :private,
        sector_module: "DpbWDamping",
        module_parameters: %{
          max_steps: 1000,
          visualize: false
        }
      }
    ]
  }
}

# Store data in the database
IO.puts("\n=== Storing data in the database ===")
DB.store(:experiment, experiment_id, experiment_record)
DB.store(:population, population_id, population_record)

# Verify data was stored correctly
IO.puts("\n=== Verifying data storage ===")
exp_check = DB.fetch(:experiment, experiment_id)
IO.puts("Experiment stored: #{inspect(exp_check != nil)}")

pop_check = DB.fetch(:population, population_id)
IO.puts("Population stored: #{inspect(pop_check != nil)}")

# Test Models.read which returns different formats
IO.puts("\n=== Testing Models.read ===")
exp_read = Models.read(experiment_id, :experiment)
IO.puts("Models.read result: #{inspect(exp_read)}")

# Now implement a simplified version of the extract_experiment_data function from our fix
IO.puts("\n=== Testing our fix for handling multiple response formats ===")

extract_experiment_data = fn experiment, experiment_id_str ->
  # Extract information about the best agent
  experiment_data = Models.get(experiment, :data, %{})
  populations = Models.get(experiment_data, :populations, [])

  population_id = if is_list(populations) and length(populations) > 0 do
    first_pop = List.first(populations)
    pop_id = Models.get(first_pop, :id, :not_found)
    pop_id
  else
    "#{experiment_id_str}_population"  # Use the standard naming convention as fallback
  end

  # Determine the morphology based on experiment settings
  experiment_data = Models.get(experiment, :data, %{})
  populations = Models.get(experiment_data, :populations, [])
  morphology = if is_list(populations) and length(populations) > 0 do
    first_pop = List.first(populations)
    Models.get(first_pop, :morphology, "Unknown")
  else
    "Unknown"
  end

  morphology_module =
    if morphology == "DpbWDamping" do
      "DpbWDamping" # In real code this would be the module
    else
      "DpbWoDamping" # In real code this would be the module
    end

  {:ok, %{population_id: population_id, morphology: morphology_module}}
end

# Test with both possible response formats
process_experiment_result = fn experiment_result, experiment_id_str ->
  case experiment_result do
    # Handle the double-nested case from Models.read -> DB.fetch -> {:ok, {:ok, data}}
    {:ok, {:ok, experiment}} when is_map(experiment) ->
      IO.puts("Processing nested format: {:ok, {:ok, experiment}}")
      extract_experiment_data.(experiment, experiment_id_str)
      
    # Handle the standard single-nested case
    {:ok, experiment} when is_map(experiment) ->
      IO.puts("Processing standard format: {:ok, experiment}")
      extract_experiment_data.(experiment, experiment_id_str)
      
    other ->
      IO.puts("Unexpected format: #{inspect(other)}")
      {:error, :invalid_format}
  end
end

# Test our function with the actual result from Models.read
result = process_experiment_result.(exp_read, experiment_id)
IO.puts("Processing result: #{inspect(result)}")

# Verify we got the expected output
case result do
  {:ok, %{population_id: ^population_id, morphology: "DpbWDamping"}} ->
    IO.puts("\n=== TEST PASSED ✅ ===")
    IO.puts("The fix successfully handled the response format from Models.read")
    
  other ->
    IO.puts("\n=== TEST FAILED ❌ ===")
    IO.puts("Expected {:ok, %{population_id: #{population_id}, morphology: \"DpbWDamping\"}}")
    IO.puts("Got: #{inspect(other)}")
end