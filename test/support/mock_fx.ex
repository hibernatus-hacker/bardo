defmodule Bardo.TestSupport.MockFx do
  @moduledoc """
  Mock implementation of the Fx module for testing.
  """
  
  @doc """
  Run the FX example with default parameters.
  """
  def run(experiment_id, population_size \\ 50, window_size \\ 5000, iterations \\ 50) do
    # Create a configuration using the parameters
    config = configure(experiment_id, population_size, window_size, iterations)
    
    # Print experiment information
    IO.puts("\n=== Forex (FX) Trading Experiment ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Population size: #{population_size}")
    IO.puts("Data window size: #{window_size}")
    IO.puts("Generations: #{iterations}")
    IO.puts("Starting experiment...\n")
    
    # Set up the experiment
    Bardo.PolisMgr.setup(experiment_id, config)
    
    # Start the experiment
    Bardo.PolisMgr.start(experiment_id)
    
    # Return the experiment ID
    experiment_id
  end
  
  @doc """
  Test the best agent from an experiment.
  """
  def test_best_agent(experiment_id, window_start \\ 5000, window_size \\ 1000) do
    # Print test information
    IO.puts("\n=== Testing Best FX Trading Agent ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Test window start: #{window_start}")
    IO.puts("Test window size: #{window_size}")
    IO.puts("Loading best agent from experiment...\n")
    
    # Get the best agent
    IO.puts("⚠️ Using mock genotype for demonstration")
    IO.puts("Running backtesting on out-of-sample data...\n")
    
    # Return mocked test results
    %{
      fitness: [2200.5],
      details: %{
        trades: [
          %{entry_price: 1.2050, exit_price: 1.2150, profit: 100},
          %{entry_price: 1.2200, exit_price: 1.2100, profit: -100},
          %{entry_price: 1.2150, exit_price: 1.2350, profit: 200}
        ],
        balance_history: [10000, 10100, 10000, 10200],
        win_rate: 0.66,
        profit_factor: 3.0,
        drawdown: 100
      }
    }
  end
  
  @doc """
  Configure an FX trading experiment.
  """
  def configure(experiment_id, population_size, window_size, iterations) do
    %{
      id: experiment_id,
      iterations: iterations,
      backup_frequency: 5,
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :fx_scape,
          type: :private,
          module_parameters: %{window_size: window_size},
          sector_module: Bardo.Examples.Applications.Fx.Fx
        }
      ],
      populations: [
        %{
          id: :fx_population,
          size: population_size,
          mutation_rate: 0.1,
          morphology: Bardo.Examples.Applications.Fx.FxMorphology,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.3},
            {:add_neuron, 0.05},
            {:add_connection, 0.1},
            {:remove_connection, 0.05},
            {:remove_neuron, 0.02}
          ],
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 5,
          elite_fraction: 0.1,
          evaluations_per_generation: 1,
          population_to_evaluate: 1.0,
          scape_list: [:fx_scape]
        }
      ]
    }
  end
end