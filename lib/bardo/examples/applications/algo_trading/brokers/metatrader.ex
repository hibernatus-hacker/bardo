defmodule Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader do
  @moduledoc """
  MetaTrader broker implementation for algorithmic trading.
  
  This module implements the connection to MetaTrader platforms (MT4/MT5)
  for live and demo trading. It communicates with MT using a RESTful HTTP
  API provided by the MT REST API bridge.
  
  ## Configuration
  
  To use this module, you need to:
  
  1. Run the MT REST API bridge on your MetaTrader terminal
  2. Configure the connection URL and API key
  3. Provide account credentials
  
  ## API Reference
  
  This module uses the REST API provided by the MT bridge, which
  supports the following operations:
  
  - Account information retrieval
  - Market data (OHLCV) retrieval
  - Order placement, modification, and cancellation
  - Position management
  """
  
  alias Bardo.AgentManager.PrivateScape
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  require Logger
  
  @behaviour PrivateScape
  @behaviour BrokerInterface
  
  # Define constants
  @default_url "http://localhost:5000"
  @default_timeout 10000
  @default_timeframe 15
  @default_history_limit 100
  
  # Define nested modules for MetaTrader
  defmodule State do
    @moduledoc "MetaTrader connection state"
    defstruct [
      :account_id,        # MT account ID
      :api_key,           # API key for MT bridge
      :api_url,           # URL for MT bridge
      :symbol,            # Trading symbol
      :timeframe,         # Trading timeframe in minutes
      :risk_per_trade,    # Risk per trade as percentage
      :max_drawdown,      # Maximum drawdown percentage
      :max_open_trades,   # Maximum number of open trades
      :open_positions,    # Current open positions
      :last_tick,         # Latest price tick
      :last_bars,         # Latest price bars
      :account_info,      # Account information
      :balance,           # Account balance
      :equity,            # Current equity
      :connected_since,   # Time when connection was established
      :last_update,       # Time of last update
      :agent_states,      # State for each trading agent
      :scape_pid          # PID of the scape process
    ]
  end
  
  @doc """
  Initialize the PrivateScape for MetaTrader connectivity.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def init(params) do
    # Extract configuration parameters
    account_id = Map.get(params, :account_id)
    api_key = Map.get(params, :api_key)
    api_url = Map.get(params, :api_url, @default_url)
    symbol = Map.get(params, :symbol, "EURUSD")
    timeframe = Map.get(params, :timeframe, @default_timeframe)
    risk_per_trade = Map.get(params, :risk_per_trade, 1.0)
    max_drawdown = Map.get(params, :max_drawdown, 10.0)
    max_open_trades = Map.get(params, :max_open_trades, 1)
    
    # Validate required parameters
    if account_id == nil do
      {:error, "MT account ID is required"}
    else
      # Initialize state
      state = %State{
        account_id: account_id,
        api_key: api_key,
        api_url: api_url,
        symbol: symbol,
        timeframe: timeframe,
        risk_per_trade: risk_per_trade,
        max_drawdown: max_drawdown,
        max_open_trades: max_open_trades,
        open_positions: [],
        last_tick: nil,
        last_bars: [],
        account_info: nil,
        balance: 0.0,
        equity: 0.0,
        connected_since: DateTime.utc_now(),
        last_update: DateTime.utc_now(),
        agent_states: %{},
        scape_pid: self()
      }
      
      # Connect to MT
      case connect(%{
        account_id: account_id,
        api_key: api_key,
        api_url: api_url
      }) do
        {:ok, connection_info} ->
          # Update state with account info
          updated_state = %{state | 
            account_info: connection_info,
            balance: Map.get(connection_info, "balance", 0.0),
            equity: Map.get(connection_info, "equity", 0.0)
          }
          
          # Fetch initial market data
          {:ok, initial_bars} = get_market_data(
            %{api_url: api_url, api_key: api_key},
            symbol,
            timeframe,
            %{limit: @default_history_limit}
          )
          
          final_state = %{updated_state | last_bars: initial_bars}
          
          Logger.info("[MT] Connected to MetaTrader: Account ##{account_id}, Symbol: #{symbol}")
          {:ok, final_state}
          
        {:error, reason} ->
          Logger.error("[MT] Failed to connect to MetaTrader: #{reason}")
          {:error, reason}
      end
    end
  end
  
  @doc """
  Handle a sensor request from an agent.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def sense(params, state) do
    # Extract agent ID and sensor type from params
    agent_id = Map.get(params, :agent_id)
    sensor_type = Map.get(params, :sensor_type)
    sensor_params = Map.get(params, :params, %{})
    
    result = case sensor_type do
      :price_chart ->
        # Price Chart sensor - return price data
        _dimension = Map.get(sensor_params, :dimension, 10)
        timeframe = Map.get(sensor_params, :timeframe, 60)
        get_price_chart_data(state, timeframe)
        
      :ohlcv ->
        # OHLCV sensor - return price data
        periods = Map.get(sensor_params, :periods, 5)
        get_ohlcv_data(state, periods)
        
      :indicators ->
        # Indicators sensor - calculate indicators from price data
        calculate_indicators(state, sensor_params)
        
      :sentiment ->
        # Sentiment sensor - calculate market sentiment
        calculate_sentiment(state, sensor_params)
        
      :account ->
        # Account sensor - return account status
        get_account_data(agent_id, state)
        
      _ ->
        # Unknown sensor type
        []
    end
    
    Logger.debug("[MT] Sensor #{sensor_type} accessed by agent #{inspect(agent_id)}")
    {result, state}
  end
  
  @doc """
  Handle an actuator request from an agent.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def actuate(function, params, agent_id, state) do
    case function do
      :trade ->
        # Handle trading action
        handle_trade(params, agent_id, state)
        
      :risk_management ->
        # Handle risk management action
        handle_risk_management(params, agent_id, state)
        
      _ ->
        # Unknown function
        Logger.warning("[MT] Unknown function #{inspect(function)} called by agent #{inspect(agent_id)}")
        {[], state}
    end
  end
  
  @doc """
  Clean up resources when terminating the scape.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def terminate(reason, state) do
    Logger.info("[MT] Disconnecting from MetaTrader, reason: #{inspect(reason)}")
    
    # Disconnect from MT
    disconnect(%{
      api_url: state.api_url,
      api_key: state.api_key
    })
    
    :ok
  end
  
  @doc """
  Connect to the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def connect(params) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    account_id = Map.get(params, :account_id)
    
    # Build request URL
    url = "#{api_url}/api/account/#{account_id}/info"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:get, url, "", headers) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Disconnect from the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def disconnect(params) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    
    # Build request URL
    url = "#{api_url}/api/connection/close"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:post, url, "", headers) do
      {:ok, _} ->
        :ok
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get account information from the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def get_account_info(params) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    account_id = Map.get(params, :account_id)
    
    # Build request URL
    url = "#{api_url}/api/account/#{account_id}/info"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:get, url, "", headers) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get market data from the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def get_market_data(params, symbol, timeframe, options) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    
    # Convert timeframe to MT format
    mt_timeframe = convert_timeframe(timeframe)
    
    # Extract options
    limit = Map.get(options, :limit, @default_history_limit)
    
    # Build request URL
    url = "#{api_url}/api/market/#{symbol}/bars?timeframe=#{mt_timeframe}&limit=#{limit}"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:get, url, "", headers) do
      {:ok, response} ->
        # Convert response to standard format
        standardized_data = BrokerInterface.standardize_price_data(response, :metatrader)
        {:ok, standardized_data}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Place a new order on the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def place_order(params, symbol, direction, size, options) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    
    # Extract order parameters
    price = Map.get(options, :price, 0.0)
    stop_loss = Map.get(options, :stop_loss)
    take_profit = Map.get(options, :take_profit)
    
    # Format order for MT
    order = BrokerInterface.format_order(symbol, direction, size, price, stop_loss, take_profit, :metatrader)
    
    # Convert order to JSON
    order_json = Jason.encode!(order)
    
    # Build request URL
    url = "#{api_url}/api/trade/order"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:post, url, order_json, headers) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Close an existing order on the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def close_order(params, order_id) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    
    # Build request URL
    url = "#{api_url}/api/trade/order/#{order_id}/close"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:post, url, "", headers) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Modify an existing order on the MetaTrader platform.
  
  Required by the BrokerInterface behavior.
  """
  @impl BrokerInterface
  def modify_order(params, order_id, options) do
    # Extract connection parameters
    api_url = Map.get(params, :api_url, @default_url)
    api_key = Map.get(params, :api_key)
    
    # Extract modification parameters
    stop_loss = Map.get(options, :stop_loss)
    take_profit = Map.get(options, :take_profit)
    
    # Build modification parameters
    modifications = %{}
    modifications = if stop_loss, do: Map.put(modifications, "sl", stop_loss), else: modifications
    modifications = if take_profit, do: Map.put(modifications, "tp", take_profit), else: modifications
    
    # Convert to JSON
    modifications_json = Jason.encode!(modifications)
    
    # Build request URL
    url = "#{api_url}/api/trade/order/#{order_id}/modify"
    
    # Add authorization header if API key is provided
    headers = if api_key do
      [{"Content-Type", "application/json"}, {"X-API-KEY", api_key}]
    else
      [{"Content-Type", "application/json"}]
    end
    
    # Make API request
    case make_request(:post, url, modifications_json, headers) do
      {:ok, response} ->
        {:ok, response}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private helper functions
  
  # Make an HTTP request
  defp make_request(method, url, body, headers) do
    # Use HTTPoison if available
    if Code.ensure_loaded?(HTTPoison) do
      case apply(HTTPoison, method, [url, body, headers, [timeout: @default_timeout]]) do
        {:ok, %{status_code: 200, body: response_body}} ->
          # Parse JSON response
          case Jason.decode(response_body) do
            {:ok, decoded} -> {:ok, decoded}
            {:error, reason} -> {:error, "JSON parse error: #{reason}"}
          end
          
        {:ok, %{status_code: status_code, body: response_body}} ->
          {:error, "HTTP #{status_code}: #{response_body}"}
          
        {:error, %{reason: reason}} ->
          {:error, "HTTP request failed: #{reason}"}
      end
    else
      # Fallback to simulated responses if HTTPoison is not available
      simulate_request(method, url, body)
    end
  end
  
  # Simulate an HTTP request (for development/testing)
  defp simulate_request(method, url, _body) do
    Logger.warning("[MT] Simulating MT API request: #{method} #{url}")
    
    # Extract endpoint from URL
    endpoint = 
      url
      |> String.replace(~r/^.*?\/api\//, "")
      |> String.replace(~r/\?.*$/, "")
    
    # Return simulated response based on endpoint
    cond do
      String.match?(endpoint, ~r/account\/.*\/info/) ->
        {:ok, %{
          "login" => 12345678,
          "server" => "Demo Server",
          "balance" => 10000.0,
          "equity" => 10050.0,
          "margin" => 100.0,
          "free_margin" => 9950.0,
          "leverage" => 100,
          "currency" => "USD"
        }}
        
      String.match?(endpoint, ~r/market\/.*\/bars/) ->
        {:ok, generate_mock_bars()}
        
      String.match?(endpoint, ~r/trade\/order$/) ->
        {:ok, %{
          "order_id" => 12345,
          "symbol" => "EURUSD",
          "volume" => 0.1,
          "open_price" => 1.1000,
          "sl" => 1.0950,
          "tp" => 1.1050,
          "comment" => "Opened by Bardo"
        }}
        
      String.match?(endpoint, ~r/trade\/order\/.*\/close/) ->
        {:ok, %{
          "order_id" => 12345,
          "closed_price" => 1.1025,
          "profit" => 25.0
        }}
        
      String.match?(endpoint, ~r/trade\/order\/.*\/modify/) ->
        {:ok, %{
          "order_id" => 12345,
          "modified" => true
        }}
        
      String.match?(endpoint, ~r/connection\/close/) ->
        {:ok, %{
          "closed" => true
        }}
        
      true ->
        {:error, "Unknown endpoint: #{endpoint}"}
    end
  end
  
  # Generate mock price bars for simulation
  defp generate_mock_bars do
    # Start with a base price
    base_price = 1.1000
    
    # Generate a series of candles
    Enum.map(1..100, fn i ->
      # Generate random price movement
      open = base_price + :rand.normal() * 0.0005
      high = open + abs(:rand.normal()) * 0.0003
      low = open - abs(:rand.normal()) * 0.0003
      close = (open + high + low) / 3 + :rand.normal() * 0.0002
      
      # Ensure high is highest and low is lowest
      high = max(high, max(open, close))
      low = min(low, min(open, close))
      
      # Generate time (going backward from now)
      time_offset = i * 60 * 15  # 15 minute bars
      time = DateTime.utc_now()
             |> DateTime.add(-time_offset, :second)
             |> DateTime.to_string()
      
      # Return candle data
      %{
        "time" => time,
        "open" => open,
        "high" => high,
        "low" => low,
        "close" => close,
        "volume" => trunc(1000 + :rand.normal() * 200)
      }
    end)
  end
  
  # Convert minutes timeframe to MT timeframe format
  defp convert_timeframe(minutes) do
    case minutes do
      1 -> "M1"
      5 -> "M5"
      15 -> "M15"
      30 -> "M30"
      60 -> "H1"
      240 -> "H4"
      1440 -> "D1"
      10080 -> "W1"
      43200 -> "MN1"
      _ -> "M15"  # Default to M15
    end
  end
  
  # Handle trade execution request
  defp handle_trade(params, agent_id, state) do
    # Get the values from params
    direction = Map.get(params, :direction, 0)
    size = Map.get(params, :size, 0.0)
    
    # Check if changing position
    current_position = get_agent_position(agent_id, state)
    
    if direction != current_position do
      # Close any existing position
      if current_position != 0 do
        # Find existing order
        order_id = get_agent_order_id(agent_id, state)
        
        if order_id do
          # Close the order
          close_params = %{
            api_url: state.api_url,
            api_key: state.api_key
          }
          
          case close_order(close_params, order_id) do
            {:ok, close_result} ->
              Logger.info("[MT] Closed position for agent #{agent_id}: #{inspect(close_result)}")
              
            {:error, reason} ->
              Logger.error("[MT] Failed to close position: #{reason}")
          end
        end
      end
      
      # Open new position if direction is not zero
      if direction != 0 do
        # Calculate position size based on risk
        calculated_size = calculate_position_size(direction, size, state)
        
        # Calculate stop loss and take profit
        {stop_loss, take_profit} = calculate_stop_take_levels(direction, state)
        
        # Place the order
        order_params = %{
          api_url: state.api_url,
          api_key: state.api_key
        }
        
        order_options = %{
          price: 0.0,  # Market order
          stop_loss: stop_loss,
          take_profit: take_profit
        }
        
        case place_order(order_params, state.symbol, direction, calculated_size, order_options) do
          {:ok, order_result} ->
            Logger.info("[MT] Opened position for agent #{agent_id}: #{inspect(order_result)}")
            order_id = Map.get(order_result, "order_id")
            
            # Store the order in agent state
            new_agent_states = Map.put(state.agent_states, agent_id, %{
              position: direction,
              order_id: order_id,
              entry_price: Map.get(order_result, "open_price", 0.0),
              size: calculated_size
            })
            
            new_state = %{state | agent_states: new_agent_states}
            {[], new_state}
            
          {:error, reason} ->
            Logger.error("[MT] Failed to open position: #{reason}")
            {[], state}
        end
      else
        # No new position
        new_agent_states = Map.put(state.agent_states, agent_id, %{
          position: 0,
          order_id: nil,
          entry_price: 0.0,
          size: 0.0
        })
        
        {[], %{state | agent_states: new_agent_states}}
      end
    else
      # No change in position
      {[], state}
    end
  end
  
  # Handle risk management request
  defp handle_risk_management(params, agent_id, state) do
    # Get the values from params
    stop_loss_percent = Map.get(params, :stop_loss, 0.0)
    take_profit_percent = Map.get(params, :take_profit, 0.0)
    
    # Check if agent has an open position
    order_id = get_agent_order_id(agent_id, state)
    
    if order_id do
      # Get agent's current position
      agent_state = Map.get(state.agent_states, agent_id, %{})
      direction = Map.get(agent_state, :position, 0)
      entry_price = Map.get(agent_state, :entry_price, 0.0)
      
      # Calculate new stop loss and take profit levels
      stop_price = calculate_stop_level(entry_price, direction, stop_loss_percent, state)
      take_price = calculate_target_level(entry_price, direction, take_profit_percent, state)
      
      # Modify the order
      modify_params = %{
        api_url: state.api_url,
        api_key: state.api_key
      }
      
      modify_options = %{
        stop_loss: stop_price,
        take_profit: take_price
      }
      
      case modify_order(modify_params, order_id, modify_options) do
        {:ok, _result} ->
          Logger.info("[MT] Modified risk levels for agent #{agent_id}: SL=#{stop_price}, TP=#{take_price}")
          {[], state}
          
        {:error, reason} ->
          Logger.error("[MT] Failed to modify risk levels: #{reason}")
          {[], state}
      end
    else
      # No open position, just remember settings for next trade
      new_agent_states = Map.put_new(state.agent_states, agent_id, %{
        stop_loss_percent: stop_loss_percent,
        take_profit_percent: take_profit_percent
      })
      
      {[], %{state | agent_states: new_agent_states}}
    end
  end
  
  # Calculate position size based on risk settings
  defp calculate_position_size(_direction, size_percent, state) do
    # Get current account equity
    equity = state.equity
    
    # Calculate risk amount
    risk_amount = equity * (state.risk_per_trade / 100.0)
    
    # Calculate pip value (approximate)
    pip_value = if String.contains?(state.symbol, "JPY"), do: 0.01, else: 0.0001
    
    # Scale size based on size_percent (0.0 - 1.0)
    adjusted_risk = risk_amount * size_percent
    
    # Get latest price
    _bid_ask = get_latest_bid_ask(state)
    
    # Calculate position size
    # For MT, volume is in lots (1.0 = 100,000 units)
    # This is a simplified calculation
    size_in_lots = (adjusted_risk / (50 * pip_value))
    
    # Round to standard lot sizes (0.01, 0.1, 1.0)
    round_lot_size(size_in_lots)
  end
  
  # Round lot size to standard MT lot sizes
  defp round_lot_size(size) do
    cond do
      size < 0.01 -> 0.01  # Minimum micro lot
      size < 0.1 -> Float.round(size, 2)  # Micro lot (2 decimals)
      size < 1.0 -> Float.round(size, 1)  # Mini lot (1 decimal)
      true -> Float.round(size, 0)  # Standard lot (whole number)
    end
  end
  
  # Calculate stop loss and take profit levels
  defp calculate_stop_take_levels(direction, state) do
    # Get latest price
    bid_ask = get_latest_bid_ask(state)
    entry_price = if direction > 0, do: bid_ask.ask, else: bid_ask.bid
    
    # Get pip value for this currency pair
    pip_value = if String.contains?(state.symbol, "JPY"), do: 0.01, else: 0.0001
    
    # Default stop loss (50 pips) and take profit (100 pips)
    stop_pips = 50
    take_pips = 100
    
    # Calculate levels
    stop_loss = if direction > 0 do
      # Long position: stop below entry
      entry_price - (stop_pips * pip_value)
    else
      # Short position: stop above entry
      entry_price + (stop_pips * pip_value)
    end
    
    take_profit = if direction > 0 do
      # Long position: target above entry
      entry_price + (take_pips * pip_value)
    else
      # Short position: target below entry
      entry_price - (take_pips * pip_value)
    end
    
    {stop_loss, take_profit}
  end
  
  # Calculate stop loss level based on percentage
  defp calculate_stop_level(entry_price, direction, stop_percent, state) do
    # Get pip value for this currency pair
    pip_value = if String.contains?(state.symbol, "JPY"), do: 0.01, else: 0.0001
    
    # Convert percentage to pips (higher percentage = wider stop)
    pips = stop_percent * 100  # Scale to reasonable pips range
    
    if direction > 0 do
      # Long position: stop below entry
      entry_price - (pips * pip_value)
    else
      # Short position: stop above entry
      entry_price + (pips * pip_value)
    end
  end
  
  # Calculate take profit level based on percentage
  defp calculate_target_level(entry_price, direction, take_profit_percent, state) do
    # Get pip value for this currency pair
    pip_value = if String.contains?(state.symbol, "JPY"), do: 0.01, else: 0.0001
    
    # Convert percentage to pips (higher percentage = wider target)
    pips = take_profit_percent * 200  # Scale to reasonable pips range
    
    if direction > 0 do
      # Long position: target above entry
      entry_price + (pips * pip_value)
    else
      # Short position: target below entry
      entry_price - (pips * pip_value)
    end
  end
  
  # Get price chart data for the agent
  defp get_price_chart_data(state, timeframe) do
    # Ensure we have enough bars
    bars = if length(state.last_bars) < timeframe do
      # Fetch more bars if needed
      {:ok, more_bars} = get_market_data(
        %{api_url: state.api_url, api_key: state.api_key},
        state.symbol,
        state.timeframe,
        %{limit: max(timeframe, @default_history_limit)}
      )
      more_bars
    else
      state.last_bars
    end
    
    # Return the most recent bars
    Enum.take(bars, timeframe)
  end
  
  # Get OHLCV data for the agent
  defp get_ohlcv_data(state, periods) do
    # Ensure we have enough bars
    bars = if length(state.last_bars) < periods do
      # Fetch more bars if needed
      {:ok, more_bars} = get_market_data(
        %{api_url: state.api_url, api_key: state.api_key},
        state.symbol,
        state.timeframe,
        %{limit: max(periods, @default_history_limit)}
      )
      more_bars
    else
      state.last_bars
    end
    
    # Return the most recent bars
    Enum.take(bars, periods)
  end
  
  # Calculate technical indicators from price data
  defp calculate_indicators(state, params) do
    # Get the list of indicators requested
    requested_indicators = Map.get(params, :indicators, [])
    
    # Ensure we have enough data
    _bars = if length(state.last_bars) < 200 do
      # Fetch more bars if needed
      {:ok, more_bars} = get_market_data(
        %{api_url: state.api_url, api_key: state.api_key},
        state.symbol,
        state.timeframe,
        %{limit: @default_history_limit}
      )
      more_bars
    else
      state.last_bars
    end
    
    # Calculate requested indicators
    # This is a simplified implementation that returns dummy values
    # In a real implementation, proper indicator calculations would be used
    Enum.reduce(requested_indicators, %{}, fn indicator, acc ->
      indicator_value = case indicator do
        :sma_20 -> 0.1  # Normalized SMA value
        :sma_50 -> 0.2
        :sma_200 -> 0.3
        :ema_20 -> 0.15
        :ema_50 -> 0.25
        :rsi_14 -> 55.0
        :macd -> 0.1
        :macd_signal -> 0.05
        :bollinger_upper -> 0.1
        :bollinger_lower -> -0.1
        :atr_14 -> 0.002
        :adx_14 -> 25.0
        :stoch_k -> 65.0
        :stoch_d -> 60.0
        _ -> 0.0
      end
      
      Map.put(acc, indicator, indicator_value)
    end)
  end
  
  # Calculate market sentiment data
  defp calculate_sentiment(_state, params) do
    # Get the list of sentiment types requested
    sentiment_types = Map.get(params, :sentiment_types, [])
    
    # Calculate requested sentiment indicators
    # This is a simplified implementation that returns dummy values
    Enum.reduce(sentiment_types, %{}, fn sentiment_type, acc ->
      sentiment_value = case sentiment_type do
        :market_sentiment -> 0.6  # Slightly bullish
        :volatility -> 0.4       # Moderate volatility
        :liquidity -> 0.8        # High liquidity
        :trend_strength -> 0.3   # Weak trend
        :market_regime -> 0.4    # Slightly trending
        _ -> 0.5                 # Neutral default
      end
      
      Map.put(acc, sentiment_type, sentiment_value)
    end)
  end
  
  # Get account data for the agent
  defp get_account_data(agent_id, state) do
    # Get agent's current position
    agent_state = Map.get(state.agent_states, agent_id, %{})
    position = Map.get(agent_state, :position, 0)
    
    # Calculate open profit/loss if there's an open position
    open_pl = if position != 0 do
      _order_id = Map.get(agent_state, :order_id)
      entry_price = Map.get(agent_state, :entry_price, 0.0)
      size = Map.get(agent_state, :size, 0.0)
      
      # Get latest price
      bid_ask = get_latest_bid_ask(state)
      current_price = if position > 0, do: bid_ask.bid, else: bid_ask.ask
      
      # Calculate P/L
      (current_price - entry_price) * position * size * 100000  # Convert to base currency
    else
      0.0
    end
    
    # Calculate current equity and drawdown
    equity = state.balance + open_pl
    max_equity = Map.get(state, :max_equity, state.balance)
    drawdown = if max_equity > 0, do: (max_equity - equity) / max_equity * 100.0, else: 0.0
    
    %{
      balance: state.balance,
      equity: equity,
      position: position,
      open_pl: open_pl,
      drawdown: drawdown
    }
  end
  
  # Get the latest bid/ask prices
  defp get_latest_bid_ask(state) do
    # Use the last tick if available
    if state.last_tick do
      state.last_tick
    else
      # Use the last bar's close as an approximation
      if length(state.last_bars) > 0 do
        last_bar = List.first(state.last_bars)
        close = Map.get(last_bar, :close, 1.0)
        
        # Simulate bid/ask spread
        spread = 0.0002  # 2 pips for EURUSD
        %{
          bid: close - spread / 2,
          ask: close + spread / 2
        }
      else
        # Default values if no data available
        %{
          bid: 1.0,
          ask: 1.0001
        }
      end
    end
  end
  
  # Get agent's current position
  defp get_agent_position(agent_id, state) do
    agent_state = Map.get(state.agent_states, agent_id, %{})
    Map.get(agent_state, :position, 0)
  end
  
  # Get agent's current order ID
  defp get_agent_order_id(agent_id, state) do
    agent_state = Map.get(state.agent_states, agent_id, %{})
    Map.get(agent_state, :order_id)
  end
end