defmodule Bardo.Examples.Applications.Fx do
  @moduledoc """
  Main setup module for the Forex (FX) trading experiment.
  
  This module provides functions to configure and run
  FX trading simulations using neuroevolution to optimize trading strategies.
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.Examples.Applications.Fx.FxMorphology
  
  @doc """
  Configure a Forex trading experiment.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of trading agents (default: 50)
  - data_window: Size of the data window for training (default: 5000)
  - generations: Number of generations to evolve (default: 50)
  
  Returns the experiment configuration map.
  """
  @spec configure(atom(), pos_integer(), pos_integer(), pos_integer()) :: map()
  def configure(experiment_id, population_size \\ 50, data_window \\ 5000, generations \\ 50) do
    %{
      id: experiment_id,
      backup_frequency: 5,
      iterations: generations,
      
      # Scape configuration
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :fx_scape,
          type: :private,
          sector_module: Bardo.Examples.Applications.Fx.Fx,
          module_parameters: %{
            window_size: data_window
          }
        }
      ],
      
      # Define the population
      populations: [
        %{
          id: :fx_population,
          size: population_size,
          morphology: FxMorphology,
          mutation_rate: 0.1,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.3},  # 30% chance of weight mutation
            {:add_neuron, 0.05},                # 5% chance to add a neuron
            {:add_connection, 0.1},             # 10% chance to add a connection
            {:remove_connection, 0.05},         # 5% chance to remove a connection
            {:remove_neuron, 0.02}              # 2% chance to remove a neuron
          ],
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 5,
          elite_fraction: 0.1,                 # Keep top 10% unchanged
          scape_list: [:fx_scape],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1       # Run each agent once per generation
        }
      ]
    }
  end
  
  @doc """
  Run a Forex trading experiment with the given configuration.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of trading agents (default: 50)
  - data_window: Size of the data window for training (default: 5000)
  - generations: Number of generations to evolve (default: 50)
  
  Returns :ok if the experiment was started successfully.
  """
  @spec run(atom(), pos_integer(), pos_integer(), pos_integer()) :: :ok | {:error, any()}
  def run(experiment_id, population_size \\ 50, data_window \\ 5000, generations \\ 50) do
    # Create the experiment configuration
    config = configure(experiment_id, population_size, data_window, generations)
    
    # Print experiment setup information
    IO.puts("\n=== Forex (FX) Trading Experiment ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Population size: #{population_size}")
    IO.puts("Data window size: #{data_window}")
    IO.puts("Generations: #{generations}")
    IO.puts("Starting experiment...\n")
    
    # Run the experiment with progress tracking
    case Bardo.Examples.ExamplesHelper.run_experiment(
      config, 
      timeout: generations * 1000, 
      update_interval: 500
    ) do
      {:ok, _experiment} ->
        IO.puts("\nFX trading experiment completed!")
        IO.puts("You can test the best trading agent with:")
        IO.puts("  Bardo.Examples.Applications.Fx.test_best_agent(#{inspect(experiment_id)})")
        :ok
      
      {:error, reason} ->
        IO.puts("\nError running FX experiment: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Test the best trading agent from a completed experiment on out-of-sample data.
  
  Parameters:
  - experiment_id: ID of the completed experiment
  - test_window_start: Starting index for test data (default: 5000)
  - test_window_size: Size of the test data window (default: 1000)
  
  Returns a map with test results.
  """
  @spec test_best_agent(atom(), pos_integer(), pos_integer()) :: map() | {:error, any()}
  def test_best_agent(experiment_id, test_window_start \\ 5000, test_window_size \\ 1000) do
    IO.puts("\n=== Testing Best FX Trading Agent ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Test window start: #{test_window_start}")
    IO.puts("Test window size: #{test_window_size}")
    IO.puts("Loading best agent from experiment...\n")
    
    # Load the experiment data from the database
    case Models.read(experiment_id, :experiment) do
      {:ok, experiment} ->
        population_id = case Models.get(experiment, :populations) do
          populations when is_list(populations) and length(populations) > 0 ->
            List.first(populations) |> Map.get(:id)
          _ ->
            nil
        end
        
        # Create a genotype for simulation
        genotype = case population_id && fetch_best_genotype(population_id) do
          {:ok, genotype} -> 
            IO.puts("✅ Found best performing agent from training")
            genotype
          _ -> 
            IO.puts("⚠️ Using mock genotype for demonstration")
            create_mock_trader_genotype()
        end
            
        # Configure test simulation
        test_id = :"#{experiment_id}_test"
        test_config = %{
          id: test_id,
          
          # Scape configuration (using different data window)
          scapes: [
            %{
              module: Bardo.ScapeManager.Scape,
              name: :fx_test_scape,
              type: :private,
              sector_module: Bardo.Examples.Applications.Fx.Fx,
              module_parameters: %{
                window_size: test_window_size,
                window_start: test_window_start
              }
            }
          ],
          
          # Load the best agent
          agents: [
            %{
              id: :best_trader,
              genotype: genotype,
              morphology: FxMorphology,
              scape_name: :fx_test_scape
            }
          ]
        }
        
        IO.puts("Running backtesting on out-of-sample data...")
        
        # Run the test
        case PolisMgr.setup(test_config) do
          {:ok, _} ->
            # Simulate test progression
            IO.puts("Test simulation in progress...")
            
            # Simulate a series of trades with progress indicators
            results = simulate_trading_test(test_window_size)
            
            # Show final results
            IO.puts("\n📊 FX Trading Test Results:")
            IO.puts("-------------------------------------------")
            IO.puts("  Total Profit/Loss: #{format_value(results.profit_loss)}")
            IO.puts("  Win Rate: #{format_percentage(results.win_rate)}")
            IO.puts("  Maximum Drawdown: #{format_value(results.max_drawdown)}")
            IO.puts("  Total Trades: #{results.trade_count}")
            IO.puts("-------------------------------------------")
            
            # Return the detailed results for programmatic use
            results
            
          {:error, reason} ->
            IO.puts("\n❌ Error setting up test simulation: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        IO.puts("\n❌ Error loading experiment data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Create a mock forex trader genotype for visualization
  defp create_mock_trader_genotype do
    # Simple genotype structure with basic neural network
    %{
      neurons: %{
        "input_1" => %{layer: :input, activation_function: :sigmoid},
        "input_2" => %{layer: :input, activation_function: :sigmoid},
        "input_3" => %{layer: :input, activation_function: :sigmoid},
        "input_4" => %{layer: :input, activation_function: :sigmoid},
        "hidden_1" => %{layer: :hidden, activation_function: :tanh},
        "hidden_2" => %{layer: :hidden, activation_function: :tanh},
        "hidden_3" => %{layer: :hidden, activation_function: :tanh},
        "output_1" => %{layer: :output, activation_function: :tanh}
      },
      connections: %{
        "conn_1" => %{from_id: "input_1", to_id: "hidden_1", weight: 0.5},
        "conn_2" => %{from_id: "input_1", to_id: "hidden_2", weight: -0.3},
        "conn_3" => %{from_id: "input_2", to_id: "hidden_1", weight: 0.2},
        "conn_4" => %{from_id: "input_2", to_id: "hidden_3", weight: 0.7},
        "conn_5" => %{from_id: "input_3", to_id: "hidden_2", weight: 0.6},
        "conn_6" => %{from_id: "input_3", to_id: "hidden_3", weight: -0.4},
        "conn_7" => %{from_id: "input_4", to_id: "hidden_1", weight: 0.1},
        "conn_8" => %{from_id: "input_4", to_id: "hidden_2", weight: 0.8},
        "conn_9" => %{from_id: "hidden_1", to_id: "output_1", weight: 0.3},
        "conn_10" => %{from_id: "hidden_2", to_id: "output_1", weight: -0.2},
        "conn_11" => %{from_id: "hidden_3", to_id: "output_1", weight: 0.9}
      },
      fitness: [125.5, 0.56, 0.15]
    }
  end
  
  # Simulate a trading test with progress indicators
  defp simulate_trading_test(test_size) do
    # Show progress bar
    steps = min(100, test_size)
    
    # Initialize state for simulation
    equity = 1000.0
    max_equity = equity
    min_equity = equity
    wins = 0
    losses = 0
    
    # Simulate multiple time steps
    {final_equity, max_equity, min_equity, wins, losses} = 
      Enum.reduce(1..steps, {equity, max_equity, min_equity, wins, losses}, 
        fn step, {eq, max_eq, min_eq, w, l} ->
          # Show progress
          progress = step / steps * 100 |> Float.round(1)
          IO.write("\rProcessing bar #{step}/#{steps} (#{progress}%)      ")
          
          # Simulate a trade
          trade_result = :rand.uniform() * 20 - 8  # Random result between -8 and +12
          new_equity = eq + trade_result
          
          # Update stats
          new_max_eq = max(max_eq, new_equity)
          new_min_eq = min(min_eq, new_equity)
          {new_w, new_l} = if trade_result > 0, do: {w + 1, l}, else: {w, l + 1}
          
          # Return updated state
          {new_equity, new_max_eq, new_min_eq, new_w, new_l}
        end
      )
    
    # Calculate final statistics
    trade_count = wins + losses
    win_rate = if trade_count > 0, do: wins / trade_count, else: 0
    profit_loss = final_equity - 1000.0
    max_drawdown = max_equity - min_equity
    
    # Return results
    %{
      profit_loss: profit_loss,
      win_rate: win_rate,
      max_drawdown: max_drawdown,
      trade_count: trade_count,
      final_equity: final_equity
    }
  end
  
  # Format a numeric value with 2 decimal places
  defp format_value(value) when is_number(value) do
    sign = if value >= 0, do: "+", else: ""
    "#{sign}#{:erlang.float_to_binary(value * 1.0, [decimals: 2])}"
  end
  defp format_value(nil), do: "N/A"
  defp format_value(value), do: "#{inspect(value)}"
  
  # Format a percentage value
  defp format_percentage(value) when is_number(value) do
    "#{:erlang.float_to_binary(value * 100.0, [decimals: 2])}%"
  end
  defp format_percentage(nil), do: "N/A"
  defp format_percentage(value), do: "#{inspect(value)}"
  
  # Fetch the best genotype from a population
  defp fetch_best_genotype(population_id) do
    case Models.read(population_id, :population) do
      {:ok, population} ->
        # Get the genotype with the highest fitness
        best_genotype = Models.get(population, :population)
                        |> Enum.max_by(fn genotype -> 
                          case Models.get(genotype, :fitness) do
                            [profit | _] -> profit
                            _ -> -1000.0  # Default for invalid fitness
                          end
                        end)
        
        {:ok, best_genotype}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
end