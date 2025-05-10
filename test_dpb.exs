# This script demonstrates the fix for the DPB example and tests it in one go
# Run with: mix run test_dpb.exs

# Make sure DPB module is loaded
alias Bardo.Examples.Benchmarks.Dpb
alias Bardo.Examples.Benchmarks.Dpb.{DpbWDamping, DpbWoDamping}
alias Bardo.DB
alias Bardo.Models

# Create a direct test of running and checking the experiment in a single process
defmodule DpbTest do
  def run() do
    # Setup experiment info
    experiment_id = "dpb_test"
    population_size = 10
    generations = 5
    max_steps = 1000
    
    # Create direct population record
    population_id = "#{experiment_id}_population"
    population_record = %{
      data: %{
        id: population_id,
        population: [
          %{
            fitness: 0.95,
            generation: generations,
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
    
    # Create direct experiment record
    experiment_record = %{
      data: %{
        id: experiment_id,
        status: "completed",
        iterations: generations,
        backup_frequency: 5,
        populations: [
          %{
            id: population_id,
            size: population_size,
            morphology: DpbWDamping,
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
            module: Bardo.ScapeManager.Scape,
            name: "#{experiment_id}_scape",
            type: :private,
            sector_module: DpbWDamping,
            module_parameters: %{
              max_steps: max_steps,
              visualize: false
            }
          }
        ]
      }
    }
    
    # Store the data directly
    IO.puts("\n=== Storing experiment and population data ===")
    DB.store(:experiment, experiment_id, experiment_record)
    DB.store(:population, population_id, population_record)
    
    # Verify the experiment was stored
    exp_check = DB.fetch(:experiment, experiment_id)
    IO.puts("Experiment check: #{inspect(exp_check != nil)}")
    
    # Verify the population was stored
    pop_check = DB.fetch(:population, population_id)
    IO.puts("Population check: #{inspect(pop_check != nil)}")
    
    # Try reading with Models.read
    exp_read = Models.read(experiment_id, :experiment)
    IO.puts("Models.read experiment check: #{inspect(exp_read)}")
    
    # Now test the solution with the fixed key encoding
    IO.puts("\n=== Testing best solution ===")
    results = Dpb.test_best_solution(experiment_id)
    
    # Print summary
    IO.puts("Test completed with results: #{inspect(results)}")
  end
end

# Run the test
DpbTest.run()