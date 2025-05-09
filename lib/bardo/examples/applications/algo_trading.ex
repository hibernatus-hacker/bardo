defmodule Bardo.Examples.Applications.AlgoTrading do
  @moduledoc """
  Algorithmic Trading example for the Bardo neuroevolution framework.
  
  This module provides tools for developing and testing algorithmic
  trading strategies using neuroevolution to optimize performance.
  
  Features:
  - Forex market simulation with historical data
  - External broker interfaces for live trading
  - Strategy backtesting and optimization
  - Advanced technical indicators
  - Position sizing and risk management
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.Examples.ExamplesHelper
  alias Bardo.Examples.Applications.AlgoTrading.Morphology
  
  @doc """
  Configure an algorithmic trading experiment.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - config_opts: Map of configuration options with the following keys:
    - :market - Market to trade (e.g., :forex, :crypto, :stocks)
    - :symbol - Symbol to trade (e.g., "EURUSD", "BTCUSD")
    - :timeframe - Trading timeframe in minutes (e.g., 15, 60, 240, 1440)
    - :population_size - Number of trading agents (default: 100)
    - :data_window - Size of the data window for training (default: 5000)
    - :generations - Number of generations to evolve (default: 100)
    - :mutation_rate - Base mutation rate (default: 0.1)
    - :elite_fraction - Fraction of top performers to keep unchanged (default: 0.1)
    - :tournament_size - Size of tournament for selection (default: 5)
    - :use_external_data - Whether to use external data sources (default: false)
    - :external_data_source - URL or path for external data (when use_external_data is true)
  
  Returns the experiment configuration map.
  """
  @spec configure(atom(), map()) :: map()
  def configure(experiment_id, config_opts \\ %{}) do
    # Extract configuration options with defaults
    market = Map.get(config_opts, :market, :forex)
    symbol = Map.get(config_opts, :symbol, "EURUSD")
    timeframe = Map.get(config_opts, :timeframe, 15)
    population_size = Map.get(config_opts, :population_size, 100)
    data_window = Map.get(config_opts, :data_window, 5000)
    generations = Map.get(config_opts, :generations, 100)
    mutation_rate = Map.get(config_opts, :mutation_rate, 0.1)
    elite_fraction = Map.get(config_opts, :elite_fraction, 0.1)
    tournament_size = Map.get(config_opts, :tournament_size, 5)
    use_external_data = Map.get(config_opts, :use_external_data, false)
    external_data_source = Map.get(config_opts, :external_data_source, nil)
    
    # Choose the appropriate simulator based on market type
    {simulator_module, simulator_params} = case market do
      :forex -> 
        {Bardo.Examples.Applications.AlgoTrading.Simulators.ForexSimulator, 
         %{
           symbol: symbol,
           timeframe: timeframe,
           window_size: data_window,
           use_external_data: use_external_data,
           external_data_source: external_data_source
         }}
      
      :crypto ->
        {Bardo.Examples.Applications.AlgoTrading.Simulators.CryptoSimulator,
         %{
           symbol: symbol,
           timeframe: timeframe,
           window_size: data_window,
           use_external_data: use_external_data,
           external_data_source: external_data_source
         }}
         
      _ ->
        # Default to forex if market type is unknown
        {Bardo.Examples.Applications.AlgoTrading.Simulators.ForexSimulator,
         %{
           symbol: symbol,
           timeframe: timeframe,
           window_size: data_window,
           use_external_data: use_external_data,
           external_data_source: external_data_source
         }}
    end
    
    %{
      id: experiment_id,
      backup_frequency: 10,
      iterations: generations,
      
      # Scape configuration
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :trading_scape,
          type: :private,
          sector_module: simulator_module,
          module_parameters: simulator_params
        }
      ],
      
      # Define the population
      populations: [
        %{
          id: :"#{experiment_id}_population",
          size: population_size,
          morphology: Morphology,
          mutation_rate: mutation_rate,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.4},  # 40% chance of weight mutation
            {:add_neuron, 0.1},                 # 10% chance to add a neuron
            {:add_connection, 0.2},             # 20% chance to add a connection
            {:remove_connection, 0.05},         # 5% chance to remove a connection
            {:remove_neuron, 0.03}              # 3% chance to remove a neuron
          ],
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: tournament_size,
          elite_fraction: elite_fraction,      # Keep top performers unchanged
          scape_list: [:trading_scape],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1        # Run each agent once per generation
        }
      ]
    }
  end
  
  @doc """
  Run an algorithmic trading experiment with the given configuration.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - config_opts: Map of configuration options (see configure/2 for details)
  
  Returns :ok if the experiment was started successfully, {:error, reason} otherwise.
  """
  @spec run(atom(), map()) :: :ok | {:error, any()}
  def run(experiment_id, config_opts \\ %{}) do
    # Create the experiment configuration
    config = configure(experiment_id, config_opts)
    
    # Extract key information for display
    market = get_in(config, [:scapes, Access.at(0), :module_parameters, :symbol]) || "EURUSD"
    timeframe = get_in(config, [:scapes, Access.at(0), :module_parameters, :timeframe]) || 15
    population_size = get_in(config, [:populations, Access.at(0), :size])
    generations = config.iterations
    
    # Print experiment setup information
    IO.puts("\n==================================================")
    IO.puts("     Algorithmic Trading Experiment")
    IO.puts("==================================================")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Market: #{market}")
    IO.puts("Timeframe: #{timeframe} minutes")
    IO.puts("Population size: #{population_size}")
    IO.puts("Generations: #{generations}")
    IO.puts("Starting experiment...\n")
    
    # Run the experiment with progress tracking
    case ExamplesHelper.run_experiment(
      config, 
      timeout: generations * 2000, 
      update_interval: 1000,
      visualize: true
    ) do
      {:ok, _experiment} ->
        IO.puts("\n✅ Algorithmic trading experiment completed!")
        IO.puts("\nYou can test the best trading agent with:")
        IO.puts("  Bardo.Examples.Applications.AlgoTrading.test_best_agent(#{inspect(experiment_id)})")
        IO.puts("\nYou can also connect to live trading with:")
        IO.puts("  Bardo.Examples.Applications.AlgoTrading.live_trading(#{inspect(experiment_id)}, :broker_name)")
        :ok
      
      {:error, reason} ->
        IO.puts("\n❌ Error running algorithmic trading experiment: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Test the best trading agent from a completed experiment on out-of-sample data.
  
  Parameters:
  - experiment_id: ID of the completed experiment
  - opts: Map of test options with the following keys:
    - :test_period - String describing test period (e.g., "last_month", "custom")
    - :start_date - Start date for custom test period (ISO format string)
    - :end_date - End date for custom test period (ISO format string)
    - :window_size - Size of the test data window (default: 2000)
    - :use_external_data - Whether to use external data sources for testing
    - :external_data_source - URL or path for external test data
  
  Returns a map with test results or {:error, reason} if testing fails.
  """
  @spec test_best_agent(atom(), map()) :: map() | {:error, any()}
  def test_best_agent(experiment_id, opts \\ %{}) do
    # Extract test options with defaults
    test_period = Map.get(opts, :test_period, "last_month")
    start_date = Map.get(opts, :start_date, nil)
    end_date = Map.get(opts, :end_date, nil)
    window_size = Map.get(opts, :window_size, 2000)
    use_external_data = Map.get(opts, :use_external_data, false)
    external_data_source = Map.get(opts, :external_data_source, nil)
    
    IO.puts("\n==================================================")
    IO.puts("     Testing Best Trading Agent")
    IO.puts("==================================================")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Test period: #{test_period}")
    if start_date && end_date do
      IO.puts("Date range: #{start_date} to #{end_date}")
    end
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
        
        # Get the original configuration
        original_config = case get_original_config(experiment) do
          {:ok, config} -> config
          _ -> %{}
        end
        
        # Determine simulator and parameters based on original experiment
        simulator_module = get_in(original_config, [:scapes, Access.at(0), :sector_module]) ||
                           Bardo.Examples.Applications.AlgoTrading.Simulators.ForexSimulator
                           
        symbol = get_in(original_config, [:scapes, Access.at(0), :module_parameters, :symbol]) || "EURUSD"
        timeframe = get_in(original_config, [:scapes, Access.at(0), :module_parameters, :timeframe]) || 15
        
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
              name: :test_trading_scape,
              type: :private,
              sector_module: simulator_module,
              module_parameters: %{
                symbol: symbol,
                timeframe: timeframe,
                window_size: window_size,
                test_period: test_period,
                start_date: start_date,
                end_date: end_date,
                use_external_data: use_external_data,
                external_data_source: external_data_source
              }
            }
          ],
          
          # Load the best agent
          agents: [
            %{
              id: :best_trader,
              genotype: genotype,
              morphology: Morphology,
              scape_name: :test_trading_scape
            }
          ]
        }
        
        IO.puts("Running backtesting on out-of-sample data...")
        
        # Run the test
        case PolisMgr.setup(test_config) do
          {:ok, _} ->
            # Simulate test progression
            IO.puts("\nTest simulation in progress...")
            
            # Run the test with progress tracking
            case ExamplesHelper.run_experiment(
              test_config,
              timeout: 60_000,
              update_interval: 500,
              visualize: true
            ) do
              {:ok, _} ->
                # Retrieve test results from the database
                case get_test_results(test_id) do
                  {:ok, results} ->
                    # Show final results
                    display_trading_results(results)
                    
                    # Return the detailed results for programmatic use
                    results
                    
                  {:error, reason} ->
                    IO.puts("\n❌ Error retrieving test results: #{inspect(reason)}")
                    {:error, reason}
                end
                
              {:error, reason} ->
                IO.puts("\n❌ Error running test simulation: #{inspect(reason)}")
                {:error, reason}
            end
            
          {:error, reason} ->
            IO.puts("\n❌ Error setting up test simulation: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        IO.puts("\n❌ Error loading experiment data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Connect a trained agent to live trading through a broker interface.
  
  Parameters:
  - experiment_id: ID of the completed experiment containing the agent to deploy
  - broker: Broker module or name (e.g., :metatrader, :oanda, :binance)
  - opts: Map of live trading options with the following keys:
    - :account_id - Broker account ID
    - :risk_per_trade - Percentage of account to risk per trade (default: 1.0)
    - :max_drawdown - Maximum drawdown percentage before stopping (default: 10.0)
    - :max_open_trades - Maximum number of simultaneous open trades (default: 1)
    - :symbol - Trading symbol (default: from original experiment)
    - :timeframe - Trading timeframe in minutes (default: from original experiment)
  
  Returns :ok if the agent was successfully connected, {:error, reason} otherwise.
  """
  @spec live_trading(atom(), atom() | module(), map()) :: :ok | {:error, any()}
  def live_trading(experiment_id, broker, opts \\ %{}) do
    # Extract live trading options with defaults
    account_id = Map.get(opts, :account_id, nil)
    risk_per_trade = Map.get(opts, :risk_per_trade, 1.0)
    max_drawdown = Map.get(opts, :max_drawdown, 10.0)
    max_open_trades = Map.get(opts, :max_open_trades, 1)
    
    # Resolve broker module
    broker_module = case broker do
      :metatrader -> Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader
      :oanda -> Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda
      :binance -> Bardo.Examples.Applications.AlgoTrading.Brokers.Binance
      module when is_atom(module) -> module
      _ -> {:error, "Unknown broker: #{inspect(broker)}"}
    end
    
    if account_id == nil do
      IO.puts("\n❌ Error: account_id is required for live trading")
      {:error, "account_id is required for live trading"}
    end
    
    if is_tuple(broker_module) and elem(broker_module, 0) == :error do
      broker_module
    end
    
    IO.puts("\n==================================================")
    IO.puts("     Live Trading Connection")
    IO.puts("==================================================")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Broker: #{inspect(broker)}")
    IO.puts("Account ID: #{account_id}")
    IO.puts("Risk per trade: #{risk_per_trade}%")
    IO.puts("Max drawdown: #{max_drawdown}%")
    IO.puts("Max open trades: #{max_open_trades}")
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
        
        # Get the original configuration
        original_config = case get_original_config(experiment) do
          {:ok, config} -> config
          _ -> %{}
        end
        
        # Extract symbol and timeframe from original experiment
        symbol = Map.get(opts, :symbol, 
                  get_in(original_config, [:scapes, Access.at(0), :module_parameters, :symbol]) || "EURUSD")
                  
        timeframe = Map.get(opts, :timeframe,
                     get_in(original_config, [:scapes, Access.at(0), :module_parameters, :timeframe]) || 15)
        
        # Create a genotype for simulation
        genotype = case population_id && fetch_best_genotype(population_id) do
          {:ok, genotype} -> 
            IO.puts("✅ Found best performing agent from training")
            genotype
          _ -> 
            IO.puts("⚠️ Using mock genotype for demonstration")
            create_mock_trader_genotype()
        end
        
        # Configure live trading
        live_id = :"#{experiment_id}_live"
        live_config = %{
          id: live_id,
          
          # Scape configuration using broker interface
          scapes: [
            %{
              module: Bardo.ScapeManager.Scape,
              name: :live_trading_scape,
              type: :private,
              sector_module: broker_module,
              module_parameters: %{
                account_id: account_id,
                symbol: symbol,
                timeframe: timeframe,
                risk_per_trade: risk_per_trade,
                max_drawdown: max_drawdown,
                max_open_trades: max_open_trades
              }
            }
          ],
          
          # Load the best agent
          agents: [
            %{
              id: :live_trader,
              genotype: genotype,
              morphology: Morphology,
              scape_name: :live_trading_scape
            }
          ]
        }
        
        IO.puts("Connecting to broker...")
        
        # Connect to live trading
        case PolisMgr.setup(live_config) do
          {:ok, _} ->
            IO.puts("\n✅ Successfully connected to live trading!")
            IO.puts("\nTrading agent is now active. Use the following commands to manage:")
            IO.puts("  - Monitor status: Bardo.Examples.Applications.AlgoTrading.monitor_live_trading(#{inspect(live_id)})")
            IO.puts("  - Stop trading: Bardo.Examples.Applications.AlgoTrading.stop_live_trading(#{inspect(live_id)})")
            :ok
            
          {:error, reason} ->
            IO.puts("\n❌ Error connecting to live trading: #{inspect(reason)}")
            {:error, reason}
        end
        
      {:error, reason} ->
        IO.puts("\n❌ Error loading experiment data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Monitor the status of a live trading session.
  
  Parameters:
  - live_id: ID of the live trading session to monitor
  
  Returns a map with current trading status or {:error, reason} if monitoring fails.
  """
  @spec monitor_live_trading(atom()) :: map() | {:error, any()}
  def monitor_live_trading(live_id) do
    IO.puts("\n==================================================")
    IO.puts("     Live Trading Monitor")
    IO.puts("==================================================")
    IO.puts("Live Trading ID: #{live_id}")
    
    # Retrieve live trading status from the database
    case Models.read(live_id, :live_trading) do
      {:ok, trading_status} ->
        # Display current status
        IO.puts("\n📊 Current Trading Status:")
        IO.puts("-------------------------------------------")
        IO.puts("  Account Balance: #{format_currency(trading_status.balance)}")
        IO.puts("  Equity: #{format_currency(trading_status.equity)}")
        IO.puts("  Open P/L: #{format_currency(trading_status.open_pl)}")
        IO.puts("  Open Positions: #{length(trading_status.open_positions)}")
        IO.puts("  Today's P/L: #{format_currency(trading_status.daily_pl)}")
        IO.puts("  Total P/L: #{format_currency(trading_status.total_pl)}")
        IO.puts("  Drawdown: #{format_percentage(trading_status.drawdown)}")
        IO.puts("  Connected Since: #{format_datetime(trading_status.connected_since)}")
        IO.puts("  Last Update: #{format_datetime(trading_status.last_update)}")
        IO.puts("-------------------------------------------")
        
        # Display open positions if any
        if length(trading_status.open_positions) > 0 do
          IO.puts("\nOpen Positions:")
          IO.puts("-------------------------------------------")
          
          Enum.each(trading_status.open_positions, fn position ->
            direction = if position.direction > 0, do: "LONG", else: "SHORT"
            IO.puts("  #{position.symbol} (#{direction})")
            IO.puts("    Opened: #{format_datetime(position.open_time)}")
            IO.puts("    Size: #{position.size}")
            IO.puts("    Entry: #{position.entry_price}")
            IO.puts("    Current: #{position.current_price}")
            IO.puts("    P/L: #{format_currency(position.profit_loss)}")
            IO.puts("-------------------------------------------")
          end)
        end
        
        # Return the status for programmatic use
        trading_status
        
      {:error, reason} ->
        IO.puts("\n❌ Error getting live trading status: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Stop a live trading session.
  
  Parameters:
  - live_id: ID of the live trading session to stop
  
  Returns :ok if the session was stopped successfully, {:error, reason} otherwise.
  """
  @spec stop_live_trading(atom()) :: :ok | {:error, any()}
  def stop_live_trading(live_id) do
    IO.puts("\nStopping live trading session #{live_id}...")
    
    # Send the stop command to the live trading session
    case Bardo.PolisMgr.send_command(live_id, :stop) do
      :ok ->
        IO.puts("\n✅ Live trading session stopped successfully.")
        IO.puts("Final trading summary:")
        
        # Display final status
        case monitor_live_trading(live_id) do
          {:error, _} -> :ok  # Ignore errors
          _ -> :ok
        end
        
        :ok
        
      {:error, reason} ->
        IO.puts("\n❌ Error stopping live trading session: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Private helper functions
  
  # Get the original experiment configuration
  defp get_original_config(experiment) do
    # Original configuration is stored in the experiment record
    case Models.get(experiment, :config) do
      nil -> {:error, "No configuration found in experiment"}
      config -> {:ok, config}
    end
  end
  
  # Get test results from the database
  defp get_test_results(test_id) do
    case Models.read(test_id, :trading_results) do
      {:ok, results} -> {:ok, results}
      {:error, reason} -> {:error, reason}
    end
  end
  
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
  
  # Display trading test results
  defp display_trading_results(results) do
    IO.puts("\n📊 Trading Results:")
    IO.puts("-------------------------------------------")
    IO.puts("  Total Profit/Loss: #{format_currency(results.profit_loss)}")
    IO.puts("  Win Rate: #{format_percentage(results.win_rate)}")
    IO.puts("  Profit Factor: #{format_number(results.profit_factor)}")
    IO.puts("  Maximum Drawdown: #{format_percentage(results.max_drawdown)}")
    IO.puts("  Total Trades: #{results.trade_count}")
    IO.puts("  Sharpe Ratio: #{format_number(results.sharpe_ratio)}")
    IO.puts("  Avg Profit per Trade: #{format_currency(results.avg_profit_per_trade)}")
    IO.puts("  Avg Win: #{format_currency(results.avg_win)}")
    IO.puts("  Avg Loss: #{format_currency(results.avg_loss)}")
    IO.puts("-------------------------------------------")
    
    # Optionally show detailed metrics if available
    if results[:detailed_metrics] do
      IO.puts("\nDetailed Metrics:")
      IO.puts("-------------------------------------------")
      Enum.each(results.detailed_metrics, fn {metric, value} ->
        IO.puts("  #{String.replace(to_string(metric), "_", " ") |> String.capitalize()}: #{format_value(value)}")
      end)
      IO.puts("-------------------------------------------")
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
        "input_5" => %{layer: :input, activation_function: :sigmoid},
        "input_6" => %{layer: :input, activation_function: :sigmoid},
        "hidden_1" => %{layer: :hidden, activation_function: :tanh},
        "hidden_2" => %{layer: :hidden, activation_function: :tanh},
        "hidden_3" => %{layer: :hidden, activation_function: :tanh},
        "hidden_4" => %{layer: :hidden, activation_function: :tanh},
        "hidden_5" => %{layer: :hidden, activation_function: :tanh},
        "output_1" => %{layer: :output, activation_function: :tanh},
        "output_2" => %{layer: :output, activation_function: :tanh}
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
        "conn_9" => %{from_id: "input_5", to_id: "hidden_4", weight: 0.3},
        "conn_10" => %{from_id: "input_5", to_id: "hidden_5", weight: -0.2},
        "conn_11" => %{from_id: "input_6", to_id: "hidden_4", weight: 0.9},
        "conn_12" => %{from_id: "input_6", to_id: "hidden_5", weight: 0.5},
        "conn_13" => %{from_id: "hidden_1", to_id: "hidden_4", weight: 0.2},
        "conn_14" => %{from_id: "hidden_2", to_id: "hidden_5", weight: 0.6},
        "conn_15" => %{from_id: "hidden_1", to_id: "output_1", weight: 0.3},
        "conn_16" => %{from_id: "hidden_2", to_id: "output_1", weight: -0.2},
        "conn_17" => %{from_id: "hidden_3", to_id: "output_1", weight: 0.9},
        "conn_18" => %{from_id: "hidden_4", to_id: "output_2", weight: 0.4},
        "conn_19" => %{from_id: "hidden_5", to_id: "output_2", weight: 0.7}
      },
      fitness: [125.5, 0.56, 0.15, 0.25]
    }
  end
  
  # Formatting helper functions
  
  # Format a currency value
  defp format_currency(value) when is_number(value) do
    sign = if value >= 0, do: "+", else: ""
    "#{sign}$#{:erlang.float_to_binary(abs(value) * 1.0, [decimals: 2])}"
  end
  defp format_currency(nil), do: "N/A"
  defp format_currency(value), do: "#{inspect(value)}"
  
  # Format a percentage value
  defp format_percentage(value) when is_number(value) do
    "#{:erlang.float_to_binary(value * 100.0, [decimals: 2])}%"
  end
  defp format_percentage(nil), do: "N/A"
  defp format_percentage(value), do: "#{inspect(value)}"
  
  # Format a numeric value
  defp format_number(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [decimals: 3])
  end
  defp format_number(nil), do: "N/A"
  defp format_number(value), do: "#{inspect(value)}"
  
  # Format a datetime value
  defp format_datetime(datetime) when is_binary(datetime), do: datetime
  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
  defp format_datetime(nil), do: "N/A"
  defp format_datetime(value), do: "#{inspect(value)}"
  
  # Format any value for display
  defp format_value(value) when is_number(value) do
    :erlang.float_to_binary(value * 1.0, [decimals: 3])
  end
  defp format_value(value) when is_binary(value), do: value
  defp format_value(true), do: "Yes"
  defp format_value(false), do: "No"
  defp format_value(nil), do: "N/A"
  defp format_value(value), do: "#{inspect(value)}"
end