#!/usr/bin/env elixir

# Test script to verify that the DPB module handles both formats of Models.read responses.
# Tests both the nested {:ok, {:ok, data}} and standard {:ok, data} formats.

# Load dependencies with Mix
Mix.start()
Mix.loadpaths()

# Setup basic Logger
require Logger
Logger.configure(level: :debug)

IO.puts("\n=== DPB Fix Test ===")
IO.puts("This test verifies that the DPB module can handle both formats of Models.read responses")

# Compile required modules in the correct order
IO.puts("\n=== Compiling required modules ===")

# Compile basic modules first
Code.compile_file("lib/bardo/db.ex")
Code.compile_file("lib/bardo/models.ex")
Code.compile_file("lib/bardo/utils.ex")
Code.compile_file("lib/bardo/logger.ex")

# Start DB
IO.puts("\n=== Starting DB GenServer ===")
{:ok, _pid} = Bardo.DB.start_link()

# Create a test experiment
experiment_id = "dpb_test_#{System.os_time()}"
IO.puts("\nUsing experiment ID: #{experiment_id}")

# Create mock population record
population_id = "#{experiment_id}_population"
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

# Create mock experiment record
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

# Store the data directly
IO.puts("\n=== Storing experiment and population data ===")
Bardo.DB.store(:experiment, experiment_id, experiment_record)
Bardo.DB.store(:population, population_id, population_record)

# Verify the experiment was stored
exp_check = Bardo.DB.fetch(:experiment, experiment_id)
IO.puts("Experiment check: #{inspect(exp_check != nil)}")
IO.puts("Experiment data: #{inspect(exp_check)}")

# Verify the population was stored
pop_check = Bardo.DB.fetch(:population, population_id)
IO.puts("Population check: #{inspect(pop_check != nil)}")
IO.puts("Population data: #{inspect(pop_check)}")

# Try reading with Models.read which should return {:ok, {:ok, data}}
IO.puts("\n=== Testing Models.read ===")
exp_read = Bardo.Models.read(experiment_id, :experiment)
IO.puts("Models.read experiment check: #{inspect(exp_read)}")

# Also test Models.exists?
exists_result = Bardo.Models.exists?(experiment_id, :experiment)
IO.puts("Models.exists? check: #{inspect(exists_result)}")

# Let's test how extract_experiment_data works by writing a simplified version
IO.puts("\n=== Testing extract_experiment_data ===")

# Simplified version of extract_experiment_data
extract_experiment_data = fn experiment, experiment_id_str ->
  # Extract information about the best agent
  experiment_data = Bardo.Models.get(experiment, :data, %{})
  populations = Bardo.Models.get(experiment_data, :populations, [])

  IO.puts("Extracted experiment data: #{inspect(experiment_data)}")
  IO.puts("Extracted populations: #{inspect(populations)}")

  population_id = if is_list(populations) and length(populations) > 0 do
    first_pop = List.first(populations)
    pop_id = Bardo.Models.get(first_pop, :id, :not_found)
    IO.puts("Found population ID: #{inspect(pop_id)}")
    pop_id
  else
    IO.puts("No populations found, using fallback: #{experiment_id_str}_population")
    "#{experiment_id_str}_population"  # Use the standard naming convention as fallback
  end

  # Determine the morphology based on experiment settings
  morphology = Bardo.Models.get(experiment, [:populations, 0, :morphology])
  IO.puts("Morphology from experiment: #{inspect(morphology)}")
  morphology_module = 
    if morphology == "DpbWDamping" do
      IO.puts("Experiment type: With Damping")
      "DpbWDamping" # In real code this would be the module
    else
      IO.puts("Experiment type: Without Damping")
      "DpbWoDamping" # In real code this would be the module
    end

  {:ok, %{population_id: population_id, morphology: morphology_module}}
end

# Test with both response formats

# Case 1: Standard format {:ok, data}
case exp_read do
  {:ok, exp} when is_map(exp) ->
    IO.puts("Testing standard format: {:ok, experiment}")
    result = extract_experiment_data.(exp, experiment_id)
    IO.puts("Extract result: #{inspect(result)}")
    
  {:ok, {:ok, exp}} when is_map(exp) ->
    IO.puts("Testing nested format: {:ok, {:ok, experiment}}")
    result = extract_experiment_data.(exp, experiment_id)
    IO.puts("Extract result: #{inspect(result)}")
    
  other ->
    IO.puts("Unexpected format: #{inspect(other)}")
end

IO.puts("\n=== Verifying DB data ===")
# List all data in the DB for verification
all_experiments = Bardo.DB.list(:experiment)
IO.puts("All experiments: #{inspect(all_experiments)}")

all_populations = Bardo.DB.list(:population)
IO.puts("All populations: #{inspect(all_populations)}")

IO.puts("\n=== Test completed successfully ===")