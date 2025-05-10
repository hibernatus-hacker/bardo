defmodule Bardo.Examples.Applications.AlgoTrading.TradingAPI do
  @moduledoc """
  Simplified API for algorithmic trading with Bardo.
  
  This module provides a streamlined interface for:
  - Downloading historical market data
  - Training trading agents
  - Managing and deploying agents
  - Backtesting and evaluating performance
  
  It is focused on 15-minute timeframes and makes it easy to work with
  OANDA and Gemini brokers in sandbox mode.
  """
  
  require Logger
  
  alias Bardo.Examples.Applications.AlgoTrading.DataUtils
  alias Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding
  alias Bardo.Examples.Applications.AlgoTrading.AgentLoader
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini
  
  # Default timeframe (15-minute candles)
  @default_timeframe "M15"
  
  # Default directory for storing agents
  @agent_storage_dir "priv/market_data/agent_repository"
  
  @doc """
  Initialize a broker connection (OANDA or Gemini).
  
  ## Parameters
  
  - broker_type: Type of broker (`:oanda` or `:gemini`)
  - api_key: API key for broker authentication
  - options: Additional options
    - `:api_secret` - API secret (required for Gemini)
    - `:account_id` - Account ID (required for OANDA)
    - `:live` - Whether to use live or sandbox mode (default: false)
  
  ## Returns
  
  - `{:ok, broker_state}` - Broker state for API calls
  - `{:error, reason}` - If initialization fails
  """
  def init_broker(broker_type, api_key, options \\ %{}) do
    # Set default to sandbox/practice mode
    options = Map.put_new(options, :live, false)
    
    case broker_type do
      :oanda ->
        account_id = Map.get(options, :account_id)
        
        if is_nil(account_id) do
          {:error, "account_id is required for OANDA"}
        else
          broker_config = %{
            api_key: api_key,
            account_id: account_id,
            live: options.live
          }
          
          Oanda.init(broker_config)
        end
        
      :gemini ->
        api_secret = Map.get(options, :api_secret)
        
        if is_nil(api_secret) do
          {:error, "api_secret is required for Gemini"}
        else
          broker_config = %{
            api_key: api_key,
            api_secret: api_secret,
            live: options.live
          }
          
          Gemini.init(broker_config)
        end
        
      _ ->
        {:error, "Unsupported broker type: #{broker_type}. Supported types: :oanda, :gemini"}
    end
  end
  
  @doc """
  Download historical data for a specific instrument.
  
  ## Parameters
  
  - broker_type: Type of broker (`:oanda` or `:gemini`)
  - broker_state: Broker state from `init_broker/3`
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  - options: Additional options
    - `:timeframe` - Candle timeframe (default: "M15")
    - `:start_date` - Start date in ISO8601 format (default: 1 year ago)
    - `:end_date` - End date in ISO8601 format (default: now)
    - `:save_dir` - Directory to save data (default: type-specific directory)
  
  ## Returns
  
  - `{:ok, filepath}` - Path to the downloaded data file
  - `{:error, reason}` - If download fails
  """
  def download_historical_data(broker_type, broker_state, instrument, options \\ %{}) do
    # Set defaults
    timeframe = Map.get(options, :timeframe, @default_timeframe)
    now = DateTime.utc_now()
    one_year_ago = DateTime.add(now, -365 * 24 * 60 * 60, :second)
    
    start_date = Map.get(options, :start_date, DateTime.to_iso8601(one_year_ago))
    end_date = Map.get(options, :end_date, DateTime.to_iso8601(now))
    
    broker_module = case broker_type do
      :oanda -> Oanda
      :gemini -> Gemini
      _ -> nil
    end
    
    if is_nil(broker_module) do
      {:error, "Unsupported broker type: #{broker_type}"}
    else
      DataUtils.download_historical_data(
        broker_module,
        broker_state,
        instrument,
        timeframe,
        %{
          start_date: start_date,
          end_date: end_date,
          format: "csv",
          broker_type: broker_type,
          save_path: Map.get(options, :save_dir)
        }
      )
    end
  end
  
  @doc """
  Train a trading agent for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD") 
  - data_file: Path to historical data file
  - options: Additional options
    - `:population_size` - Size of population for evolution (default: 50)
    - `:generations` - Number of generations to evolve (default: 100)
    - `:substrate_config` - Neural network configuration (default: standard config)
  
  ## Returns
  
  - `{:ok, agent_info}` - Information about the trained agent
  - `{:error, reason}` - If training fails
  """
  def train_agent(instrument, data_file, options \\ %{}) do
    # Set defaults
    population_size = Map.get(options, :population_size, 50)
    generations = Map.get(options, :generations, 100)
    
    # Default substrate configuration
    substrate_config = Map.get(options, :substrate_config, %{
      input_time_points: 60,      # 60 time points (15-minute candles)
      input_price_levels: 20,     # 20 price levels
      input_data_types: 10,       # 10 data types (OHLC, volume, indicators)
      hidden_layers: 2,           # 2 hidden layers
      hidden_neurons_per_layer: 20, # 20 neurons per hidden layer
      output_neurons: 3           # 3 outputs (direction, size, risk)
    })
    
    # Load historical data
    case DataUtils.load_historical_data(data_file) do
      {:ok, candles} ->
        # Create experiment ID
        _experiment_id = "#{instrument}_#{DateTime.utc_now() |> DateTime.to_unix()}"
        
        # Create initial population
        initial_population = create_initial_population(population_size, substrate_config)
        
        # Run simulation to evolve population
        {:ok, best_agent} = run_evolution_simulation(initial_population, candles, generations)
        
        # Save the best agent
        agent_dir = get_agent_dir(instrument)
        File.mkdir_p!(agent_dir)
        
        agent_filename = "#{instrument}_#{timestring()}.json"
        agent_path = Path.join(agent_dir, agent_filename)
        
        metadata = %{
          "instrument" => instrument,
          "trained_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "data_file" => data_file,
          "population_size" => population_size,
          "generations" => generations,
          "performance" => best_agent.fitness
        }
        
        case AgentSerializer.save_agent(best_agent.genotype, agent_path, metadata) do
          :ok ->
            {:ok, %{
              agent_id: Path.basename(agent_path, ".json"),
              agent_path: agent_path,
              fitness: best_agent.fitness,
              metadata: metadata
            }}
            
          {:error, reason} ->
            {:error, "Failed to save agent: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load historical data: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Deploy a trading agent for live or paper trading.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - broker_type: Type of broker (`:oanda` or `:gemini`)
  - broker_state: Broker state from `init_broker/3`
  - options: Additional options
    - `:instrument` - Instrument to trade (override agent's default)
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:max_drawdown` - Maximum drawdown percentage (default: 10.0)
    - `:continuous_learning` - Enable continuous learning (default: true)
  
  ## Returns
  
  - `{:ok, agent_id}` - ID of the deployed agent
  - `{:error, reason}` - If deployment fails
  """
  def deploy_agent(agent_path, broker_type, broker_state, options \\ %{}) do
    # Set defaults
    risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    max_drawdown = Map.get(options, :max_drawdown, 10.0)
    continuous_learning = Map.get(options, :continuous_learning, true)
    
    # Determine broker module
    broker_module = case broker_type do
      :oanda -> Oanda
      :gemini -> Gemini
      _ -> nil
    end
    
    if is_nil(broker_module) do
      {:error, "Unsupported broker type: #{broker_type}"}
    else
      # Get instrument from agent if not provided
      instrument = case Map.get(options, :instrument) do
        nil ->
          # Try to load agent to get instrument from metadata
          case AgentSerializer.load_agent(agent_path) do
            {:ok, {_genotype, metadata}} ->
              Map.get(metadata, "instrument")
              
            _ ->
              nil
          end
          
        instrument ->
          instrument
      end
      
      if is_nil(instrument) do
        {:error, "Instrument not specified and could not be determined from agent metadata"}
      else
        # Configure continuous learning
        continuous_learning_options = %{
          learning_rate: 0.01,
          mutation_probability: 0.1,
          update_frequency: 10,
          max_memory_size: 1000
        }
        
        # Deploy the agent
        AgentLoader.deploy_agent_from_file(
          agent_path,
          broker_module,
          broker_state,
          %{
            agent_id: "#{Path.basename(agent_path, ".json")}_#{UUID.uuid4(:hex) |> String.slice(0, 8)}",
            instrument: instrument,
            risk_per_trade: risk_per_trade,
            max_drawdown: max_drawdown,
            continuous_learning: continuous_learning,
            continuous_learning_options: continuous_learning_options
          }
        )
      end
    end
  end
  
  @doc """
  Backtest an agent against historical data.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - data_file: Path to historical data file
  - options: Additional options
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:initial_balance` - Initial account balance (default: 10000.0)
  
  ## Returns
  
  - `{:ok, results}` - Backtest results
  - `{:error, reason}` - If backtesting fails
  """
  def backtest_agent(agent_path, data_file, options \\ %{}) do
    # Set defaults
    risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    initial_balance = Map.get(options, :initial_balance, 10000.0)
    
    # Load agent
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Load historical data
        case DataUtils.load_historical_data(data_file) do
          {:ok, candles} ->
            # Run backtest simulation
            results = run_backtest_simulation(genotype, candles, %{
              risk_per_trade: risk_per_trade,
              initial_balance: initial_balance
            })
            
            {:ok, results}
            
          {:error, reason} ->
            {:error, "Failed to load historical data: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load agent: #{inspect(reason)}"}
    end
  end
  
  @doc """
  List all trained agents for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  - options: Additional options
    - `:sort_by` - Sort criterion (`:date`, `:performance`, default: `:date`)
    - `:limit` - Maximum number of agents to return (default: all)
  
  ## Returns
  
  - `{:ok, agents}` - List of agent information
  - `{:error, reason}` - If listing fails
  """
  def list_agents(instrument, options \\ %{}) do
    sort_by = Map.get(options, :sort_by, :date)
    limit = Map.get(options, :limit)
    
    # Get agent directory
    agent_dir = get_agent_dir(instrument)
    
    # Check if directory exists
    if File.exists?(agent_dir) do
      # List all JSON files
      agents = 
        File.ls!(agent_dir)
        |> Enum.filter(&String.ends_with?(&1, ".json"))
        |> Enum.map(fn filename ->
          file_path = Path.join(agent_dir, filename)
          
          # Try to load metadata
          metadata = case AgentSerializer.load_agent(file_path) do
            {:ok, {_genotype, metadata}} -> metadata
            _ -> %{}
          end
          
          # Extract performance if available
          performance = case Map.get(metadata, "performance") do
            [profit | _] -> profit
            _ -> 0.0
          end
          
          # Extract training date
          trained_at = Map.get(metadata, "trained_at", "")
          {_trained_date, _} = DateTime.from_iso8601(trained_at)
          
          # Create agent info
          %{
            id: Path.basename(filename, ".json"),
            path: file_path,
            trained_at: trained_at,
            performance: performance,
            metadata: metadata
          }
        end)
        
      # Sort agents
      sorted_agents = case sort_by do
        :performance ->
          Enum.sort_by(agents, fn agent -> agent.performance end, :desc)
          
        _ -> # :date
          Enum.sort_by(agents, fn agent -> agent.trained_at end, :desc)
      end
      
      # Apply limit if specified
      limited_agents = if is_nil(limit) do
        sorted_agents
      else
        Enum.take(sorted_agents, limit)
      end
      
      {:ok, limited_agents}
    else
      {:ok, []}
    end
  end
  
  @doc """
  Get the best agent for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  
  ## Returns
  
  - `{:ok, agent_info}` - Information about the best agent
  - `{:error, reason}` - If no agents are found
  """
  def get_best_agent(instrument) do
    case list_agents(instrument, %{sort_by: :performance, limit: 1}) do
      {:ok, [best_agent | _]} ->
        {:ok, best_agent}
        
      {:ok, []} ->
        {:error, "No agents found for instrument: #{instrument}"}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private helper functions
  
  # Create a directory path for storing agents by instrument
  defp get_agent_dir(instrument) do
    # Ensure base directory exists
    File.mkdir_p!(@agent_storage_dir)
    
    # Normalize instrument name for directory
    instrument_normalized = String.replace(instrument, "/", "_")
    instrument_normalized = String.replace(instrument_normalized, "-", "_")
    
    Path.join(@agent_storage_dir, instrument_normalized)
  end
  
  # Generate a timestamp string for filenames
  defp timestring do
    DateTime.utc_now()
    |> DateTime.to_date()
    |> Date.to_string()
    |> String.replace("-", "")
  end
  
  # Create initial population of agents with substrate encoding
  defp create_initial_population(population_size, substrate_config) do
    Enum.map(1..population_size, fn _ ->
      genotype = SubstrateEncoding.create_substrate_genotype(substrate_config)
      %{genotype: genotype, fitness: [0.0, 0.0, 0.0]}
    end)
  end
  
  # Run evolution simulation
  defp run_evolution_simulation(population, _candles, _generations) do
    # Implementation details would be added here
    # This is a placeholder for actual evolution algorithm
    
    # For demonstration, return the first agent (would be replaced with actual evolution)
    {:ok, List.first(population)}
  end
  
  # Run backtest simulation
  defp run_backtest_simulation(_genotype, _candles, _options) do
    # Implementation details would be added here
    # This is a placeholder for actual backtest simulation
    
    # For demonstration, return sample results
    %{
      total_trades: 0,
      win_rate: 0.0,
      profit_loss: 0.0,
      max_drawdown: 0.0,
      trades: []
    }
  end
end