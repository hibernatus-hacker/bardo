defmodule Bardo.Examples.Applications.AlgoTrading.Simulators.ForexSimulator do
  @moduledoc """
  Forex market simulator for algorithmic trading.
  
  This module implements a sophisticated forex trading simulator that allows
  agents to trade currency pairs based on historical price data, with features like:
  
  - Historical OHLCV data from multiple sources
  - Real-time calculation of technical indicators
  - Realistic slippage and spread modeling
  - Advanced risk management
  - Detailed performance metrics
  
  It behaves as a private scape in the Bardo system.
  """
  
  alias Bardo.AgentManager.PrivateScape
  require Logger
  
  @behaviour PrivateScape
  
  # Define constants
  @default_balance 10000.0
  @default_leverage 100.0
  @max_drawdown_percent 20.0
  @default_symbol "EURUSD"
  @default_timeframe 15
  @default_data_path "priv/fx_tables/EURUSD15.txt"
  @default_slippage 2  # Slippage in pips
  @default_spread 2    # Spread in pips
  
  # Define nested modules for simulation structs
  
  defmodule State do
    @moduledoc "Forex simulator state struct"
    defstruct [
      :price_data,       # List of price data points
      :data_length,      # Length of the price data
      :index,            # Current position in the data
      :accounts,         # Map of agent accounts
      :scape_pid,        # PID of the scape
      :window_start,     # Start of the current data window
      :window_end,       # End of the current data window
      :symbol,           # Trading symbol
      :timeframe,        # Trading timeframe in minutes
      :spread,           # Spread in pips
      :slippage,         # Slippage in pips
      :indicators,       # Cached technical indicators
      :pip_value,        # Value of one pip in the base currency
      :sentiment_data,   # Market sentiment data
      :last_update_time  # Timestamp of last update
    ]
  end
  
  defmodule Account do
    @moduledoc "Trading account struct"
    defstruct [
      :agent_id,         # ID of the agent
      :balance,          # Account balance
      :equity,           # Current equity (balance + open profit/loss)
      :leverage,         # Account leverage
      :position,         # Current position (-1=short, 0=none, 1=long)
      :position_size,    # Size of the current position
      :order,            # Current order details (if position != 0)
      :stop_loss,        # Stop loss level (price)
      :take_profit,      # Take profit level (price)
      :risk_per_trade,   # Risk per trade as percentage
      :max_equity,       # Maximum equity achieved
      :min_equity,       # Minimum equity achieved
      :drawdown,         # Current drawdown as percentage
      :completed_trades, # List of completed trades
      :win_count,        # Number of winning trades
      :loss_count,       # Number of losing trades
      :total_profit,     # Sum of all profits
      :total_loss,       # Sum of all losses (as positive number)
      :trade_start_time, # Start time of current trade
      :trade_count       # Total number of trades executed
    ]
  end
  
  defmodule Order do
    @moduledoc "Trading order struct"
    defstruct [
      :open_price,       # Price when the order was opened
      :open_time,        # Time when the order was opened
      :size,             # Size of the order
      :direction,        # Direction of the order (-1=short, 1=long)
      :stop_loss,        # Stop loss level (price)
      :take_profit,      # Take profit level (price)
      :open_pl,          # Current profit/loss
      :risk_amount       # Amount risked in this trade
    ]
  end
  
  defmodule PriceData do
    @moduledoc "Price data struct for OHLCV information"
    defstruct [
      :time,             # Timestamp
      :open,             # Opening price
      :high,             # Highest price
      :low,              # Lowest price
      :close,            # Closing price
      :volume,           # Trading volume
      :symbol,           # Trading symbol
      :timeframe         # Timeframe in minutes
    ]
  end
  
  defmodule Trade do
    @moduledoc "Completed trade struct"
    defstruct [
      :direction,        # Trade direction (-1=short, 1=long)
      :open_price,       # Entry price
      :close_price,      # Exit price
      :open_time,        # Entry time
      :close_time,       # Exit time
      :profit_loss,      # Profit or loss from the trade
      :size,             # Position size
      :pips,             # Number of pips gained or lost
      :duration,         # Duration of the trade in minutes
      :reason            # Reason for trade closure (stop, target, manual)
    ]
  end
  
  @doc """
  Initialize the private scape for forex trading with provided parameters.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def init(params) do
    # Extract configuration parameters
    window_size = Map.get(params, :window_size, 5000)
    window_start = Map.get(params, :window_start, 0)
    symbol = Map.get(params, :symbol, @default_symbol)
    timeframe = Map.get(params, :timeframe, @default_timeframe)
    use_external_data = Map.get(params, :use_external_data, false)
    external_data_source = Map.get(params, :external_data_source, nil)
    spread = Map.get(params, :spread, @default_spread)
    slippage = Map.get(params, :slippage, @default_slippage)
    test_period = Map.get(params, :test_period, nil)
    start_date = Map.get(params, :start_date, nil)
    end_date = Map.get(params, :end_date, nil)
    
    # Load price data
    {:ok, price_data} = load_forex_data(symbol, timeframe, use_external_data, external_data_source)
    data_length = length(price_data)
    
    # Determine window bounds based on test period if provided
    {adjusted_start, adjusted_size} = if test_period || (start_date && end_date) do
      adjust_window_for_test_period(price_data, test_period, start_date, end_date)
    else
      {window_start, window_size}
    end
    
    # Calculate pip value (for standard 4-digit forex pairs)
    pip_value = if String.contains?(symbol, "JPY"), do: 0.01, else: 0.0001
    
    # Initialize state
    state = %State{
      price_data: price_data,
      data_length: data_length,
      index: adjusted_start,
      accounts: %{},
      scape_pid: self(),
      window_start: adjusted_start,
      window_end: min(adjusted_start + adjusted_size, data_length - 1),
      symbol: symbol,
      timeframe: timeframe,
      spread: spread,
      slippage: slippage,
      indicators: %{},
      pip_value: pip_value,
      sentiment_data: %{},
      last_update_time: DateTime.utc_now()
    }
    
    # Precalculate technical indicators
    state = calculate_indicators(state)
    
    Logger.info("[ForexSim] Initialized #{symbol}/#{timeframe}m simulator with window size: #{adjusted_size}")
    Logger.info("[ForexSim] Data range: #{adjusted_start} to #{adjusted_start + adjusted_size} (total: #{data_length})")
    {:ok, state}
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
        # Price Chart sensor - return price data for creating a 2D grid
        _dimension = Map.get(sensor_params, :dimension, 10)
        timeframe = Map.get(sensor_params, :timeframe, 60)
        get_price_chart_data(state, timeframe)
        
      :ohlcv ->
        # OHLCV sensor - return recent price candles
        periods = Map.get(sensor_params, :periods, 5)
        get_ohlcv_data(state, periods)
        
      :indicators ->
        # Indicators sensor - return technical indicators
        get_indicators_data(state, sensor_params)
        
      :sentiment ->
        # Sentiment sensor - return market sentiment data
        get_sentiment_data(state, sensor_params)
        
      :account ->
        # Account sensor - return account information
        account = Map.get(state.accounts, agent_id, create_default_account(agent_id))
        get_account_data(account, state)
        
      _ ->
        # Unknown sensor type, return empty list
        []
    end
    
    Logger.debug("[ForexSim] Sensor #{sensor_type} accessed by agent #{inspect(agent_id)}")
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
        Logger.warning("[ForexSim] Unknown function #{inspect(function)} called by agent #{inspect(agent_id)}")
        {[], state}
    end
  end
  
  @doc """
  Clean up resources when terminating the scape.
  
  Required by the PrivateScape behavior.
  """
  @impl PrivateScape
  def terminate(reason, _state) do
    # No resources to clean up
    Logger.info("[ForexSim] Terminating forex simulator, reason: #{inspect(reason)}")
    :ok
  end
  
  # Handle trade execution request
  defp handle_trade(params, agent_id, state) do
    # Get the values from params
    direction = Map.get(params, :direction, 0)
    size = Map.get(params, :size, 0.0)
    
    # If this is a new agent, create an account
    account = Map.get(state.accounts, agent_id) || create_default_account(agent_id)
    
    # Execute the trade
    {updated_account, _response} = execute_trade(account, direction, size, state)
    
    # Update the account in the state
    new_accounts = Map.put(state.accounts, agent_id, updated_account)
    new_state = %{state | accounts: new_accounts}
    
    # Check if we've reached the end of the data
    result = if state.index >= state.window_end do
      # Calculate final fitness
      fitness = calculate_fitness(updated_account)
      halt_flag = :goal_reached
      
      # Store trading results in the database for later retrieval
      store_trading_results(state, updated_account)
      
      # Return completion response with fitness and goal_reached flag
      {fitness, halt_flag}
    else
      # Step the simulation forward
      {:ok, _stepped_state} = step(%{}, new_state)
      
      # Return standard response with empty fitness and continue flag
      {[], :continue}
    end
    
    Logger.debug("[ForexSim] Trade executed by agent #{inspect(agent_id)}, direction: #{direction}, size: #{size}")
    {result, new_state}
  end
  
  # Handle risk management request
  defp handle_risk_management(params, agent_id, state) do
    # Get the values from params
    stop_loss = Map.get(params, :stop_loss, 0.0)
    take_profit = Map.get(params, :take_profit, 0.0)
    
    # Get the agent's account
    account = Map.get(state.accounts, agent_id) || create_default_account(agent_id)
    
    # Apply risk management settings
    updated_account = update_risk_levels(account, stop_loss, take_profit, state)
    
    # Update the account in the state
    new_accounts = Map.put(state.accounts, agent_id, updated_account)
    new_state = %{state | accounts: new_accounts}
    
    # Return standard response
    Logger.debug("[ForexSim] Risk levels updated by agent #{inspect(agent_id)}, SL: #{stop_loss}, TP: #{take_profit}")
    {[], new_state}
  end
  
  @doc """
  Handle a new agent entering the private scape.
  
  Creates a new trading account for the agent.
  """
  def enter(agent_id, _params, state) do
    # Create a new account for the agent
    account = create_default_account(agent_id)
    
    # Add the account to the state
    new_accounts = Map.put(state.accounts, agent_id, account)
    new_state = %{state | accounts: new_accounts}
    
    {:ok, new_state}
  end
  
  @doc """
  Handle an agent leaving the private scape.
  
  Closes any open positions and removes the agent's account.
  """
  def leave(agent_id, _params, state) do
    # Check if the agent has an account
    case Map.get(state.accounts, agent_id) do
      nil ->
        # Agent doesn't have an account
        {:ok, state}
        
      account ->
        # Close any open positions
        current_price = get_current_price(state)
        _closed_account = close_position(account, current_price, :manual, state)
        
        # Remove the account from the state
        new_accounts = Map.delete(state.accounts, agent_id)
        new_state = %{state | accounts: new_accounts}
        
        {:ok, new_state}
    end
  end
  
  @doc """
  Advance the simulation by one step.
  
  Updates all accounts and moves to the next price point.
  """
  def step(_params, state) do
    # Don't advance if we're at the end of the data window
    if state.index >= state.window_end do
      {:ok, state}
    else
      # Advance to the next price point
      new_index = state.index + 1
      
      # Update all accounts with the new price
      current_price_data = get_price_at(state, new_index)
      new_accounts = update_all_accounts(state.accounts, current_price_data, state)
      
      # Update the state
      new_state = %{state | 
        index: new_index, 
        accounts: new_accounts,
        last_update_time: DateTime.utc_now()
      }
      
      {:ok, new_state}
    end
  end
  
  # Private helper functions
  
  # Create a default account for a new agent
  defp create_default_account(agent_id) do
    %{
      agent_id: agent_id,
      balance: @default_balance,
      equity: @default_balance,
      leverage: @default_leverage,
      position: 0,
      position_size: 0.0,
      order: nil,
      stop_loss: nil,
      take_profit: nil,
      risk_per_trade: 0.02,  # 2% risk per trade
      max_equity: @default_balance,
      min_equity: @default_balance,
      drawdown: 0.0,
      completed_trades: [],
      win_count: 0,
      loss_count: 0,
      total_profit: 0.0,
      total_loss: 0.0,
      trade_start_time: nil,
      trade_count: 0
    }
  end
  
  # Load forex market data from file or external source
  defp load_forex_data(symbol, timeframe, use_external_data, external_data_source) do
    if use_external_data && external_data_source do
      # Try to load from external source
      load_external_forex_data(symbol, timeframe, external_data_source)
    else
      # Use internal data files
      internal_path = determine_data_path(symbol, timeframe)
      load_internal_forex_data(internal_path, symbol, timeframe)
    end
  end
  
  # Determine data file path based on symbol and timeframe
  defp determine_data_path(symbol, timeframe) do
    case {symbol, timeframe} do
      {"EURUSD", 15} -> "priv/fx_tables/EURUSD15.txt"
      {_, _} -> @default_data_path  # Default to EURUSD/15m if specific pair not available
    end
  end
  
  # Load forex data from internal file
  defp load_internal_forex_data(file_path, symbol, timeframe) do
    full_path = Application.app_dir(:bardo, file_path)
    
    case File.read(full_path) do
      {:ok, content} ->
        # Parse the CSV data
        data = content
               |> String.split("\n", trim: true)
               |> Enum.map(fn line -> parse_forex_line(line, symbol, timeframe) end)
        
        {:ok, data}
        
      {:error, reason} ->
        Logger.error("[ForexSim] Failed to load forex data: #{reason}")
        # Return empty data set to avoid crashing
        {:ok, []}
    end
  end
  
  # Load forex data from external source
  defp load_external_forex_data(symbol, timeframe, external_source) do
    # This would connect to external APIs or files
    # For now, simulate with a placeholder implementation
    Logger.info("[ForexSim] External data source requested: #{external_source}")
    Logger.info("[ForexSim] Loading mock data for #{symbol}/#{timeframe}")
    
    # Generate mock data
    data = generate_mock_forex_data(symbol, timeframe, 10000)
    {:ok, data}
  end
  
  # Generate mock forex data for testing
  defp generate_mock_forex_data(symbol, timeframe, count) do
    # Start with a base price appropriate for the currency pair
    base_price = case symbol do
      "EURUSD" -> 1.1000
      "GBPUSD" -> 1.3000
      "USDJPY" -> 110.00
      "AUDUSD" -> 0.7500
      _ -> 1.0000
    end
    
    # Generate a series of realistic-looking candles
    now = DateTime.utc_now()
    
    Enum.map(0..(count-1), fn i ->
      # Calculate timestamp (going backward from now)
      time = DateTime.add(now, -(i * timeframe * 60), :second)
      |> DateTime.to_string()
      
      # Generate random price movement with some trend persistence
      volatility = 0.0002  # Typical forex volatility
      trend_bias = :rand.normal() * 0.0001  # Small trend bias
      
      open = base_price + trend_bias * i + :rand.normal() * volatility * :math.sqrt(i)
      
      # Generate high, low, close with realistic relationships
      high_range = abs(:rand.normal()) * volatility * 2
      low_range = abs(:rand.normal()) * volatility * 2
      
      high = open + high_range
      low = open - low_range
      
      # Ensure high is always highest and low is always lowest
      high = max(high, open)
      low = min(low, open)
      
      # Close is somewhere between high and low with bias toward trend
      close_bias = trend_bias + :rand.normal() * volatility
      close = open + close_bias
      
      # Ensure close is between high and low
      close = min(max(close, low), high)
      
      # Generate volume
      volume = trunc(1000 + :rand.normal() * 200)
      volume = max(volume, 10)  # Ensure positive volume
      
      # Create price data struct
      %{
        time: time,
        open: open,
        high: high,
        low: low,
        close: close,
        volume: volume,
        symbol: symbol,
        timeframe: timeframe
      }
    end)
  end
  
  # Parse a line of forex data from CSV format
  defp parse_forex_line(line, symbol, timeframe) do
    [date, time, open, high, low, close, volume] = String.split(line, ",", trim: true)
    
    %{
      time: "#{date} #{time}",
      open: parse_float(open),
      high: parse_float(high),
      low: parse_float(low),
      close: parse_float(close),
      volume: parse_integer(volume),
      symbol: symbol,
      timeframe: timeframe
    }
  end
  
  # Parse float value with error handling
  defp parse_float(str) do
    case Float.parse(str) do
      {value, _} -> value
      :error -> 0.0
    end
  end
  
  # Parse integer value with error handling
  defp parse_integer(str) do
    case Integer.parse(str) do
      {value, _} -> value
      :error -> 0
    end
  end
  
  # Adjust window parameters for test period
  defp adjust_window_for_test_period(price_data, test_period, start_date, end_date) do
    cond do
      # Use specific date range if provided
      start_date != nil && end_date != nil ->
        {find_date_index(price_data, start_date), find_date_range_size(price_data, start_date, end_date)}
        
      # Use predefined test periods
      test_period == "last_month" ->
        # Find index approximately 30 days ago
        window_start = max(0, length(price_data) - div(30 * 24 * 60, List.first(price_data).timeframe))
        window_size = length(price_data) - window_start
        {window_start, window_size}
        
      test_period == "last_week" ->
        # Find index approximately 7 days ago
        window_start = max(0, length(price_data) - div(7 * 24 * 60, List.first(price_data).timeframe))
        window_size = length(price_data) - window_start
        {window_start, window_size}
        
      test_period == "last_year" ->
        # Find index approximately 365 days ago
        window_start = max(0, length(price_data) - div(365 * 24 * 60, List.first(price_data).timeframe))
        window_size = length(price_data) - window_start
        {window_start, window_size}
        
      true ->
        # Default to using the last 20% of data
        window_start = trunc(length(price_data) * 0.8)
        window_size = length(price_data) - window_start
        {window_start, window_size}
    end
  end
  
  # Find index in price data for a specific date
  defp find_date_index(price_data, date_str) do
    target_date = case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
    
    # Find first price point on or after the target date
    Enum.find_index(price_data, fn point -> 
      case DateTime.from_iso8601("#{point.time}Z") do
        {:ok, dt, _} -> Date.compare(DateTime.to_date(dt), target_date) >= 0
        _ -> false
      end
    end) || 0
  end
  
  # Find size of date range in price data
  defp find_date_range_size(price_data, start_date_str, end_date_str) do
    start_idx = find_date_index(price_data, start_date_str)
    end_idx = find_date_index(price_data, end_date_str)
    
    max(1, end_idx - start_idx)
  end
  
  # Get the current price data
  defp get_current_price(state) do
    get_price_at(state, state.index).close
  end
  
  # Get bid and ask prices (accounting for spread)
  defp get_current_bid_ask(state) do
    current_price = get_current_price(state)
    spread_amount = state.spread * state.pip_value
    
    %{
      bid: current_price - (spread_amount / 2),
      ask: current_price + (spread_amount / 2)
    }
  end
  
  # Get price data at a specific index
  defp get_price_at(state, index) do
    Enum.at(state.price_data, index)
  end
  
  # Get price chart data for visualization
  defp get_price_chart_data(state, timeframe) do
    # Ensure we don't go below index 0
    start_idx = max(state.index - timeframe + 1, 0)
    
    # Extract the price data for the requested window
    Enum.slice(state.price_data, start_idx, timeframe)
  end
  
  # Get OHLCV data for recent periods
  defp get_ohlcv_data(state, periods) do
    # Ensure we don't go below index 0
    start_idx = max(state.index - periods + 1, 0)
    
    # Extract the OHLCV data for the requested periods
    Enum.slice(state.price_data, start_idx, periods)
  end
  
  # Get technical indicators data
  defp get_indicators_data(state, params) do
    # Get the list of indicators requested
    requested_indicators = Map.get(params, :indicators, [])
    
    # Return the requested indicators
    Enum.reduce(requested_indicators, %{}, fn indicator, acc ->
      indicator_value = get_indicator_value(state, indicator)
      Map.put(acc, indicator, indicator_value)
    end)
  end
  
  # Get sentiment data
  defp get_sentiment_data(state, params) do
    # Get the list of sentiment types requested
    sentiment_types = Map.get(params, :sentiment_types, [])
    
    # Return the requested sentiment data
    Enum.reduce(sentiment_types, %{}, fn sentiment_type, acc ->
      sentiment_value = get_sentiment_value(state, sentiment_type)
      Map.put(acc, sentiment_type, sentiment_value)
    end)
  end
  
  # Get account data
  defp get_account_data(account, state) do
    # Calculate open profit/loss if there's an open position
    open_pl = if account.position != 0 and account.order != nil do
      current_price = get_current_price(state)
      calculate_profit_loss(account.order, current_price)
    else
      0.0
    end
    
    # Calculate current equity
    equity = account.balance + open_pl
    
    # Calculate current drawdown
    drawdown = if account.max_equity > 0 do
      (account.max_equity - equity) / account.max_equity * 100.0
    else
      0.0
    end
    
    # Return account information
    %{
      balance: account.balance,
      equity: equity,
      position: account.position,
      open_pl: open_pl,
      drawdown: drawdown
    }
  end
  
  # Get indicator value
  defp get_indicator_value(state, indicator) do
    case Map.get(state.indicators, indicator) do
      nil -> 
        # Calculate the indicator if not cached
        calculate_indicator(state, indicator)
        
      value -> 
        # Return cached value
        Enum.at(value, state.index)
    end
  end
  
  # Calculate a specific technical indicator
  defp calculate_indicator(state, indicator) do
    case indicator do
      :sma_20 -> 
        moving_average(state, 20, &price_close/1) |> Enum.at(state.index)
        
      :sma_50 -> 
        moving_average(state, 50, &price_close/1) |> Enum.at(state.index)
        
      :sma_200 -> 
        moving_average(state, 200, &price_close/1) |> Enum.at(state.index)
        
      :ema_20 -> 
        exponential_moving_average(state, 20, &price_close/1) |> Enum.at(state.index)
        
      :ema_50 -> 
        exponential_moving_average(state, 50, &price_close/1) |> Enum.at(state.index)
        
      :rsi_14 -> 
        relative_strength_index(state, 14) |> Enum.at(state.index)
        
      :macd -> 
        get_macd(state) |> Enum.at(state.index)
        
      :macd_signal -> 
        get_macd_signal(state) |> Enum.at(state.index)
        
      :bollinger_upper -> 
        get_bollinger_band(state, :upper) |> Enum.at(state.index)
        
      :bollinger_lower -> 
        get_bollinger_band(state, :lower) |> Enum.at(state.index)
        
      :atr_14 -> 
        average_true_range(state, 14) |> Enum.at(state.index)
        
      :adx_14 -> 
        average_directional_index(state, 14) |> Enum.at(state.index)
        
      :stoch_k -> 
        stochastic_oscillator(state, 14, 3, :k) |> Enum.at(state.index)
        
      :stoch_d -> 
        stochastic_oscillator(state, 14, 3, :d) |> Enum.at(state.index)
        
      _ -> 0.0  # Default for unknown indicators
    end
  end
  
  # Calculate all common technical indicators and cache them
  defp calculate_indicators(state) do
    indicators = %{
      :sma_20 => moving_average(state, 20, &price_close/1),
      :sma_50 => moving_average(state, 50, &price_close/1),
      :sma_200 => moving_average(state, 200, &price_close/1),
      :ema_20 => exponential_moving_average(state, 20, &price_close/1),
      :ema_50 => exponential_moving_average(state, 50, &price_close/1),
      :rsi_14 => relative_strength_index(state, 14),
      :macd => get_macd(state),
      :macd_signal => get_macd_signal(state),
      :bollinger_upper => get_bollinger_band(state, :upper),
      :bollinger_lower => get_bollinger_band(state, :lower),
      :atr_14 => average_true_range(state, 14),
      :adx_14 => average_directional_index(state, 14),
      :stoch_k => stochastic_oscillator(state, 14, 3, :k),
      :stoch_d => stochastic_oscillator(state, 14, 3, :d)
    }
    
    # Also calculate market sentiment data
    sentiment_data = %{
      :market_sentiment => calculate_market_sentiment(state),
      :volatility => calculate_volatility(state),
      :liquidity => calculate_liquidity(state),
      :trend_strength => calculate_trend_strength(state),
      :market_regime => calculate_market_regime(state)
    }
    
    # Update state with cached indicators
    %{state | indicators: indicators, sentiment_data: sentiment_data}
  end
  
  # Helper for close price extraction
  defp price_close(price_data), do: price_data.close
  
  # Simple Moving Average (SMA)
  defp moving_average(state, period, value_fn) do
    # Ensure period is at least 1
    period = max(period, 1)
    
    # Calculate SMA for each point
    Enum.map(0..(state.data_length-1), fn i ->
      if i < period - 1 do
        # Not enough data for full period
        # Average what we have
        start_idx = max(0, i - period + 1)
        slice = Enum.slice(state.price_data, start_idx, i + 1)
        Enum.sum(Enum.map(slice, value_fn)) / length(slice)
      else
        # Full period available
        slice = Enum.slice(state.price_data, (i - period + 1)..i)
        Enum.sum(Enum.map(slice, value_fn)) / period
      end
    end)
  end
  
  # Exponential Moving Average (EMA)
  defp exponential_moving_average(state, period, value_fn) do
    # Ensure period is at least 1
    period = max(period, 1)
    
    # Calculate multiplier: 2 / (period + 1)
    multiplier = 2 / (period + 1)
    
    # Start with SMA for first period points
    sma_values = moving_average(state, period, value_fn)
    
    # Calculate EMA using recursion
    {ema_values, _} = Enum.reduce(0..(state.data_length-1), {[], nil}, fn i, {results, prev_ema} ->
      if i < period - 1 do
        # Use SMA for initial period
        {results ++ [Enum.at(sma_values, i)], Enum.at(sma_values, i)}
      else
        # Calculate EMA: (Close - prevEMA) * multiplier + prevEMA
        current_value = value_fn.(Enum.at(state.price_data, i))
        prev_ema = prev_ema || Enum.at(sma_values, period - 1)
        new_ema = (current_value - prev_ema) * multiplier + prev_ema
        {results ++ [new_ema], new_ema}
      end
    end)
    
    ema_values
  end
  
  # Relative Strength Index (RSI)
  defp relative_strength_index(state, period) do
    # Ensure period is at least 2
    period = max(period, 2)
    
    # Get close prices
    close_prices = Enum.map(state.price_data, &price_close/1)
    
    # Calculate price changes
    price_changes = Enum.zip(
      Enum.drop(close_prices, 1),
      Enum.drop(close_prices, -1)
    ) |> Enum.map(fn {current, previous} -> current - previous end)
    
    # Calculate RSI for each point
    Enum.reduce(0..(state.data_length-1), [], fn i, results ->
      if i < period do
        # Not enough data for full calculation
        results ++ [50.0]  # Neutral RSI
      else
        # Get relevant price changes
        changes = Enum.slice(price_changes, (i-period)..(i-1))
        
        # Split into gains and losses
        {gains, losses} = Enum.reduce(changes, {0, 0}, fn change, {g, l} ->
          if change > 0 do
            {g + change, l}
          else
            {g, l + abs(change)}
          end
        end)
        
        # Calculate average gain and loss
        avg_gain = gains / period
        avg_loss = losses / period
        
        # Calculate relative strength and RSI
        rs = if avg_loss == 0, do: 100, else: avg_gain / avg_loss
        rsi = 100 - (100 / (1 + rs))
        
        results ++ [rsi]
      end
    end)
  end
  
  # Moving Average Convergence Divergence (MACD)
  defp get_macd(state) do
    # MACD: 12-period EMA - 26-period EMA
    ema_12 = exponential_moving_average(state, 12, &price_close/1)
    ema_26 = exponential_moving_average(state, 26, &price_close/1)
    
    Enum.zip(ema_12, ema_26)
    |> Enum.map(fn {ema12, ema26} -> ema12 - ema26 end)
  end
  
  # MACD Signal Line
  defp get_macd_signal(state) do
    # 9-period EMA of MACD
    macd = get_macd(state)
    
    # Calculate 9-period EMA of MACD
    macd_state = %{state | price_data: Enum.map(macd, fn value -> %{close: value} end), data_length: length(macd)}
    exponential_moving_average(macd_state, 9, &price_close/1)
  end
  
  # Bollinger Bands
  defp get_bollinger_band(state, band_type) do
    # Calculate 20-period SMA
    sma_20 = moving_average(state, 20, &price_close/1)
    
    # Calculate standard deviation of prices
    std_dev = Enum.map(0..(state.data_length-1), fn i ->
      if i < 19 do
        # Not enough data for full calculation
        0.01  # Default small value
      else
        # Get relevant prices
        prices = Enum.slice(state.price_data, (i-19)..i)
                |> Enum.map(&price_close/1)
        
        # Calculate standard deviation
        mean = Enum.sum(prices) / 20
        variance = Enum.sum(Enum.map(prices, fn p -> (p - mean) * (p - mean) end)) / 20
        :math.sqrt(variance)
      end
    end)
    
    # Calculate upper and lower bands
    Enum.zip(sma_20, std_dev)
    |> Enum.map(fn {sma, std} ->
      case band_type do
        :upper -> (sma + 2 * std - sma) / sma  # Normalized distance
        :lower -> (sma - 2 * std - sma) / sma  # Normalized distance
        _ -> 0.0
      end
    end)
  end
  
  # Average True Range (ATR)
  defp average_true_range(state, period) do
    # Ensure period is at least 1
    period = max(period, 1)
    
    # Calculate True Range for each point
    tr_values = Enum.map(0..(state.data_length-1), fn i ->
      if i == 0 do
        # First point has no previous close
        point = Enum.at(state.price_data, i)
        point.high - point.low
      else
        # Calculate true range
        current = Enum.at(state.price_data, i)
        previous = Enum.at(state.price_data, i-1)
        
        # True Range = max(high - low, |high - prevClose|, |low - prevClose|)
        Enum.max([
          current.high - current.low,
          abs(current.high - previous.close),
          abs(current.low - previous.close)
        ])
      end
    end)
    
    # Calculate ATR (Simple Moving Average of TR)
    tr_state = %{state | price_data: Enum.map(tr_values, fn value -> %{close: value} end), data_length: length(tr_values)}
    moving_average(tr_state, period, &price_close/1)
  end
  
  # Stochastic Oscillator
  defp stochastic_oscillator(state, k_period, d_period, output) do
    # Ensure periods are at least 1
    k_period = max(k_period, 1)
    d_period = max(d_period, 1)
    
    # Calculate %K for each point
    k_values = Enum.map(0..(state.data_length-1), fn i ->
      if i < k_period - 1 do
        # Not enough data for full calculation
        50.0  # Neutral value
      else
        # Get relevant prices
        period_data = Enum.slice(state.price_data, (i-k_period+1)..i)
        
        # Find highest high and lowest low in the period
        highest_high = Enum.max_by(period_data, fn point -> point.high end).high
        lowest_low = Enum.min_by(period_data, fn point -> point.low end).low
        
        # Calculate %K: (Current Close - Lowest Low) / (Highest High - Lowest Low) * 100
        current_close = Enum.at(state.price_data, i).close
        
        if highest_high == lowest_low do
          50.0  # Avoid division by zero
        else
          (current_close - lowest_low) / (highest_high - lowest_low) * 100
        end
      end
    end)
    
    case output do
      :k -> k_values
      :d -> 
        # %D is the SMA of %K
        k_state = %{state | price_data: Enum.map(k_values, fn value -> %{close: value} end), data_length: length(k_values)}
        moving_average(k_state, d_period, &price_close/1)
      _ -> k_values
    end
  end
  
  # Average Directional Index (ADX)
  defp average_directional_index(state, period) do
    # This is a simplified implementation of ADX
    # Full implementation would calculate +DI, -DI, and then the DX and ADX
    
    # For this example, we'll use a placeholder calculation
    # In a real implementation, this would be the proper ADX calculation
    tr = average_true_range(state, period)
    
    # Calculate a simplified ADX
    Enum.map(0..(state.data_length-1), fn i ->
      if i < period * 2 do
        25.0  # Default neutral value
      else
        # Use ATR trend as a simplified proxy for ADX
        # In a real implementation, this would use proper DI calculations
        point = Enum.at(state.price_data, i)
        prev_point = Enum.at(state.price_data, i-1)
        
        # Direction strength
        dir_strength = abs(point.close - prev_point.close) / tr |> Enum.at(i)
        
        # Scale to 0-100 range typical for ADX
        min(dir_strength * 100, 100.0)
      end
    end)
  end
  
  # Calculate market sentiment based on indicators
  defp calculate_market_sentiment(state) do
    # Use a combination of indicators to determine sentiment
    # Values: 0 = extremely bearish, 0.5 = neutral, 1 = extremely bullish
    
    # For this example, we'll use a simple calculation based on:
    # - Price position relative to moving averages
    # - RSI value
    # - MACD position
    
    Enum.map(0..(state.data_length-1), fn i ->
      price = Enum.at(state.price_data, i).close
      
      # Check price position relative to moving averages (if available)
      ma_position = if i >= 200 do
        sma_50 = Enum.at(state.indicators[:sma_50] || [], i, price)
        sma_200 = Enum.at(state.indicators[:sma_200] || [], i, price)
        
        cond do
          price > sma_50 && sma_50 > sma_200 -> 0.75  # Strong bullish
          price > sma_50 && sma_50 < sma_200 -> 0.65  # Moderately bullish
          price < sma_50 && sma_50 > sma_200 -> 0.45  # Moderately bearish
          price < sma_50 && sma_50 < sma_200 -> 0.25  # Strong bearish
          true -> 0.5  # Neutral
        end
      else
        0.5  # Not enough data, neutral
      end
      
      # Check RSI (if available)
      rsi_sentiment = if i >= 14 do
        rsi = Enum.at(state.indicators[:rsi_14] || [], i, 50)
        
        cond do
          rsi > 70 -> 0.8  # Overbought (bullish)
          rsi < 30 -> 0.2  # Oversold (bearish)
          rsi > 50 -> 0.6  # Moderately bullish
          rsi < 50 -> 0.4  # Moderately bearish
          true -> 0.5  # Neutral
        end
      else
        0.5  # Not enough data, neutral
      end
      
      # Check MACD (if available)
      macd_sentiment = if i >= 26 do
        macd = Enum.at(state.indicators[:macd] || [], i, 0)
        signal = Enum.at(state.indicators[:macd_signal] || [], i, 0)
        
        cond do
          macd > 0 && macd > signal -> 0.75  # Strong bullish
          macd > 0 && macd < signal -> 0.6   # Moderately bullish
          macd < 0 && macd > signal -> 0.4   # Moderately bearish
          macd < 0 && macd < signal -> 0.25  # Strong bearish
          true -> 0.5  # Neutral
        end
      else
        0.5  # Not enough data, neutral
      end
      
      # Combine all sentiments with weightings
      (ma_position * 0.4) + (rsi_sentiment * 0.3) + (macd_sentiment * 0.3)
    end)
  end
  
  # Calculate market volatility
  defp calculate_volatility(state) do
    # Use ATR as a measure of volatility
    # Scale it to a 0-1 range where 0 is low volatility, 1 is high
    
    atr_values = state.indicators[:atr_14] || average_true_range(state, 14)
    
    # Find max ATR for scaling
    max_atr = Enum.max(atr_values)
    
    # Scale each ATR value to 0-1 range
    Enum.map(atr_values, fn atr ->
      if max_atr > 0 do
        min(atr / (max_atr * 0.5), 1.0)  # Scale relative to max, cap at 1.0
      else
        0.1  # Default low volatility if max is 0
      end
    end)
  end
  
  # Calculate market liquidity
  defp calculate_liquidity(state) do
    # Use volume as a proxy for liquidity
    # Scale it to a 0-1 range where 0 is low liquidity, 1 is high
    
    volumes = Enum.map(state.price_data, fn point -> point.volume end)
    
    # Find average volume for last 20 periods
    Enum.map(0..(state.data_length-1), fn i ->
      start_idx = max(0, i - 19)
      recent_volumes = Enum.slice(volumes, start_idx, min(20, i + 1))
      avg_volume = Enum.sum(recent_volumes) / length(recent_volumes)
      
      current_volume = Enum.at(volumes, i)
      
      # Compare current volume to average
      if avg_volume > 0 do
        min(current_volume / avg_volume, 2.0) / 2.0  # Scale 0-2 then to 0-1
      else
        0.5  # Default medium liquidity
      end
    end)
  end
  
  # Calculate trend strength
  defp calculate_trend_strength(state) do
    # Use ADX as a measure of trend strength
    # ADX ranges from 0-100 where:
    # - 0-25: Weak or no trend
    # - 25-50: Strong trend
    # - 50-75: Very strong trend
    # - 75-100: Extremely strong trend
    
    adx_values = state.indicators[:adx_14] || average_directional_index(state, 14)
    
    # Scale to 0-1 range
    Enum.map(adx_values, fn adx -> adx / 100.0 end)
  end
  
  # Calculate market regime
  defp calculate_market_regime(state) do
    # Determine market regime: trending, ranging, volatile
    # Return values: 
    # - 0.0-0.33: Ranging market
    # - 0.34-0.66: Trending market
    # - 0.67-1.00: Volatile market
    
    # Combine ADX (trend strength) and ATR (volatility)
    adx_values = state.indicators[:adx_14] || average_directional_index(state, 14)
    atr_volatility = calculate_volatility(state)
    
    Enum.zip(adx_values, atr_volatility)
    |> Enum.map(fn {adx, volatility} ->
      adx_norm = adx / 100.0
      
      cond do
        adx_norm < 0.25 && volatility < 0.5 -> 0.2  # Ranging market (low trend, low volatility)
        adx_norm > 0.4 && volatility < 0.6 -> 0.5   # Trending market (strong trend, moderate volatility)
        volatility > 0.7 -> 0.8                     # Volatile market (high volatility)
        adx_norm > 0.6 -> 0.6                       # Strong trending market
        true -> 0.3                                 # Slightly ranging
      end
    end)
  end
  
  # Get sentiment value
  defp get_sentiment_value(state, sentiment_type) do
    case Map.get(state.sentiment_data, sentiment_type) do
      nil -> 0.5  # Default neutral value
      values -> Enum.at(values, state.index, 0.5)
    end
  end
  
  # Execute a trading decision
  defp execute_trade(account, direction, size, state) do
    # Get current price with spread
    prices = get_current_bid_ask(state)
    current_time = get_price_at(state, state.index).time
    
    # Add random slippage if enabled
    entry_price = if direction > 0 do
      prices.ask + random_slippage(state.slippage, state.pip_value)
    else
      prices.bid - random_slippage(state.slippage, state.pip_value)
    end
    
    # Check if the decision changes the current position
    if direction != account.position do
      # Close any existing position
      closed_account = if account.position != 0 do
        close_position(account, entry_price, :manual, state)
      else
        account
      end
      
      # Open a new position if the direction is not zero
      if direction != 0 do
        {updated_account, trade_result} = open_position(closed_account, direction, size, entry_price, current_time, state)
        {updated_account, trade_result}
      else
        # No new position
        {closed_account, %{status: :position_closed}}
      end
    else
      # Update the account with current price for mark-to-market
      updated_account = update_account(account, entry_price, state)
      {updated_account, %{status: :no_change}}
    end
  end
  
  # Generate random slippage
  defp random_slippage(base_slippage, pip_value) do
    # Generate random slippage between 0 and base_slippage pips
    :rand.uniform() * base_slippage * pip_value
  end
  
  # Update risk levels for an account
  defp update_risk_levels(account, stop_loss_percent, take_profit_percent, state) do
    if account.position != 0 and account.order != nil do
      _current_price = get_current_price(state)
      
      # Calculate stop loss and take profit levels
      stop_loss = calculate_stop_level(account.order.open_price, account.position, stop_loss_percent, state.pip_value)
      take_profit = calculate_target_level(account.order.open_price, account.position, take_profit_percent, state.pip_value)
      
      # Update the order
      updated_order = %{account.order | 
        stop_loss: stop_loss,
        take_profit: take_profit
      }
      
      # Update the account
      %{account | 
        order: updated_order,
        stop_loss: stop_loss,
        take_profit: take_profit
      }
    else
      # No open position, just store the risk levels for next trade
      %{account | 
        stop_loss: stop_loss_percent,
        take_profit: take_profit_percent
      }
    end
  end
  
  # Calculate stop loss level based on position direction and risk percentage
  defp calculate_stop_level(entry_price, direction, stop_percent, pip_value) do
    # Convert percentage to price movement (higher percentage = wider stop)
    price_distance = stop_percent * 50 * pip_value  # Scale to reasonable range
    
    if direction > 0 do
      # Long position: stop below entry
      entry_price - price_distance
    else
      # Short position: stop above entry
      entry_price + price_distance
    end
  end
  
  # Calculate take profit level based on position direction and profit percentage
  defp calculate_target_level(entry_price, direction, take_profit_percent, pip_value) do
    # Convert percentage to price movement (higher percentage = wider target)
    price_distance = take_profit_percent * 100 * pip_value  # Scale to reasonable range
    
    if direction > 0 do
      # Long position: target above entry
      entry_price + price_distance
    else
      # Short position: target below entry
      entry_price - price_distance
    end
  end
  
  # Close an existing position
  defp close_position(account, current_price, reason, state) do
    if account.position != 0 and account.order != nil do
      # Apply slippage to exit price
      exit_price = if account.position > 0 do
        current_price - random_slippage(state.slippage, state.pip_value)
      else
        current_price + random_slippage(state.slippage, state.pip_value)
      end
      
      # Calculate profit/loss
      profit_loss = calculate_profit_loss(account.order, exit_price)
      
      # Update account balance
      new_balance = account.balance + profit_loss
      
      # Get the current time
      close_time = get_price_at(state, state.index).time
      
      # Calculate pips gained/lost
      pips = calculate_pips(account.order.open_price, exit_price, account.position, state.pip_value)
      
      # Calculate trade duration (placeholder, would use actual time diff in real implementation)
      duration = 0  # In minutes
      
      # Create completed trade record
      completed_trade = %Trade{
        direction: account.position,
        open_price: account.order.open_price,
        close_price: exit_price,
        open_time: account.order.open_time,
        close_time: close_time,
        profit_loss: profit_loss,
        size: account.order.size,
        pips: pips,
        duration: duration,
        reason: reason
      }
      
      new_completed_trades = account.completed_trades ++ [completed_trade]
      
      # Update win/loss counts and totals
      {new_win_count, new_loss_count, new_total_profit, new_total_loss} = 
        if profit_loss > 0 do
          {account.win_count + 1, account.loss_count, account.total_profit + profit_loss, account.total_loss}
        else
          {account.win_count, account.loss_count + 1, account.total_profit, account.total_loss + abs(profit_loss)}
        end
      
      # Reset position
      %{account | 
        balance: new_balance, 
        equity: new_balance,
        position: 0, 
        position_size: 0.0,
        order: nil,
        stop_loss: nil,
        take_profit: nil,
        max_equity: max(account.max_equity, new_balance),
        min_equity: min(account.min_equity, new_balance),
        completed_trades: new_completed_trades,
        win_count: new_win_count,
        loss_count: new_loss_count,
        total_profit: new_total_profit,
        total_loss: new_total_loss,
        trade_start_time: nil,
        trade_count: account.trade_count + 1
      }
    else
      # No position to close
      account
    end
  end
  
  # Calculate pips gained or lost
  defp calculate_pips(open_price, close_price, direction, pip_value) do
    if pip_value > 0 do
      (close_price - open_price) * direction / pip_value
    else
      0.0
    end
  end
  
  # Open a new position
  defp open_position(account, direction, size_percent, current_price, current_time, state) do
    # Calculate position size based on account balance, leverage, and size percentage
    base_size = account.balance * account.leverage / current_price
    position_size = base_size * size_percent
    
    # Calculate risk amount based on risk_per_trade
    risk_amount = account.balance * account.risk_per_trade
    
    # Calculate default stop loss and take profit levels if not specified
    stop_loss = if account.stop_loss do
      calculate_stop_level(current_price, direction, account.stop_loss, state.pip_value)
    else
      # Default stop loss (2% of account)
      calculate_stop_level(current_price, direction, 0.5, state.pip_value)
    end
    
    take_profit = if account.take_profit do
      calculate_target_level(current_price, direction, account.take_profit, state.pip_value)
    else
      # Default take profit (4% of account)
      calculate_target_level(current_price, direction, 0.5, state.pip_value)
    end
    
    # Create a new order
    order = %Order{
      open_price: current_price,
      open_time: current_time,
      direction: direction,
      size: position_size,
      stop_loss: stop_loss,
      take_profit: take_profit,
      open_pl: 0.0,
      risk_amount: risk_amount
    }
    
    # Update account
    updated_account = %{account | 
      position: direction, 
      position_size: position_size,
      order: order,
      max_equity: max(account.max_equity, account.equity),
      min_equity: min(account.min_equity, account.equity),
      trade_start_time: current_time
    }
    
    # Result
    result = %{
      status: :position_opened,
      direction: direction,
      size: position_size,
      price: current_price,
      stop_loss: stop_loss,
      take_profit: take_profit
    }
    
    {updated_account, result}
  end
  
  # Update an account with the current price
  defp update_account(account, current_price, state) do
    if account.position != 0 and account.order != nil do
      # Calculate unrealized profit/loss
      open_pl = calculate_profit_loss(account.order, current_price)
      
      # Update equity
      equity = account.balance + open_pl
      
      # Calculate current drawdown
      drawdown = if account.max_equity > 0 do
        (account.max_equity - equity) / account.max_equity * 100.0
      else
        0.0
      end
      
      # Update order
      updated_order = %{account.order | open_pl: open_pl}
      
      # Check for stop loss or take profit hit
      cond do
        # Check stop loss (long position)
        account.position > 0 && account.order.stop_loss && current_price <= account.order.stop_loss ->
          close_position(account, account.order.stop_loss, :stop_loss, state)
          
        # Check stop loss (short position)
        account.position < 0 && account.order.stop_loss && current_price >= account.order.stop_loss ->
          close_position(account, account.order.stop_loss, :stop_loss, state)
          
        # Check take profit (long position)
        account.position > 0 && account.order.take_profit && current_price >= account.order.take_profit ->
          close_position(account, account.order.take_profit, :take_profit, state)
          
        # Check take profit (short position)
        account.position < 0 && account.order.take_profit && current_price <= account.order.take_profit ->
          close_position(account, account.order.take_profit, :take_profit, state)
          
        # Check for margin call (if drawdown exceeds maximum)
        drawdown > @max_drawdown_percent ->
          # Close position due to margin call
          close_position(account, current_price, :margin_call, state)
          
        true ->
          # Update account
          %{account | 
            equity: equity,
            order: updated_order,
            drawdown: drawdown,
            max_equity: max(account.max_equity, equity),
            min_equity: min(account.min_equity, equity)
          }
      end
    else
      # No open position
      account
    end
  end
  
  # Calculate profit/loss for an open position
  defp calculate_profit_loss(order, current_price) do
    price_diff = (current_price - order.open_price) * order.direction
    price_diff * order.size
  end
  
  # Update all accounts with the current price
  defp update_all_accounts(accounts, price_data, state) do
    Enum.reduce(accounts, %{}, fn {agent_id, account}, acc ->
      updated_account = update_account(account, price_data.close, state)
      Map.put(acc, agent_id, updated_account)
    end)
  end
  
  # Store trading results in the database for later retrieval
  defp store_trading_results(state, account) do
    # Calculate trading metrics
    profit_factor = calculate_profit_factor(account)
    win_rate = calculate_win_rate(account)
    avg_win = calculate_avg_win(account)
    avg_loss = calculate_avg_loss(account)
    max_drawdown = calculate_max_drawdown(account)
    sharpe_ratio = calculate_sharpe_ratio(account)
    
    # Create trading results record
    results = %{
      symbol: state.symbol,
      timeframe: state.timeframe,
      profit_loss: account.balance - @default_balance,
      win_rate: win_rate,
      profit_factor: profit_factor,
      max_drawdown: max_drawdown,
      trade_count: account.trade_count,
      win_count: account.win_count,
      loss_count: account.loss_count,
      avg_profit_per_trade: (if account.trade_count > 0 do (account.balance - @default_balance) / account.trade_count else 0.0 end),
      avg_win: avg_win,
      avg_loss: avg_loss,
      sharpe_ratio: sharpe_ratio,
      detailed_metrics: %{
        total_profit: account.total_profit,
        total_loss: account.total_loss,
        max_equity: account.max_equity,
        min_equity: account.min_equity,
        ending_balance: account.balance,
        trades: account.completed_trades
      },
      timestamp: DateTime.utc_now() |> DateTime.to_string()
    }
    
    # Store in database (if available)
    case Code.ensure_loaded?(Bardo.DB) do
      true ->
        trading_results_id = :"#{state.scape_pid}_results"
        apply(Bardo.DB, :store, [:trading_results, trading_results_id, results])
      _ ->
        Logger.warning("[ForexSim] DB module not available, trading results not stored")
    end
    
    # Return the results
    results
  end
  
  # Calculate fitness for an account
  defp calculate_fitness(account) do
    # Calculate various performance metrics
    profit_loss = account.balance - @default_balance
    profit_factor = calculate_profit_factor(account)
    max_drawdown = calculate_max_drawdown(account)
    win_rate = calculate_win_rate(account)
    sharpe_ratio = calculate_sharpe_ratio(account)
    
    # Combine metrics into a fitness value vector
    # Higher is better for all metrics
    [
      profit_loss,                   # Raw profit/loss
      profit_factor * 100,           # Profit factor (scaled)
      -max_drawdown * 10,            # Drawdown (negative, lower is better)
      win_rate * 100,                # Win rate (scaled)
      sharpe_ratio * 10              # Risk-adjusted return
    ]
  end
  
  # Calculate profit factor (total profits / total losses)
  defp calculate_profit_factor(account) do
    if account.total_loss > 0 do
      account.total_profit / account.total_loss
    else
      if account.total_profit > 0, do: 10.0, else: 1.0  # Arbitrary values for edge cases
    end
  end
  
  # Calculate win rate (percentage of winning trades)
  defp calculate_win_rate(account) do
    total_trades = account.win_count + account.loss_count
    
    if total_trades > 0 do
      account.win_count / total_trades
    else
      0.0
    end
  end
  
  # Calculate average winning trade
  defp calculate_avg_win(account) do
    if account.win_count > 0 do
      account.total_profit / account.win_count
    else
      0.0
    end
  end
  
  # Calculate average losing trade
  defp calculate_avg_loss(account) do
    if account.loss_count > 0 do
      account.total_loss / account.loss_count
    else
      0.0
    end
  end
  
  # Calculate maximum drawdown as percentage
  defp calculate_max_drawdown(account) do
    if account.max_equity > 0 do
      (account.max_equity - account.min_equity) / account.max_equity * 100.0
    else
      0.0
    end
  end
  
  # Calculate Sharpe ratio (simplified)
  defp calculate_sharpe_ratio(account) do
    # Simplified Sharpe calculation
    # Assuming risk-free rate of 0 and using a simple return calculation
    
    # Calculate returns from completed trades
    returns = Enum.map(account.completed_trades, fn trade ->
      trade.profit_loss / @default_balance
    end)
    
    # Need at least a few trades for meaningful calculation
    if length(returns) < 5 do
      0.0
    else
      # Calculate average return
      avg_return = Enum.sum(returns) / length(returns)
      
      # Calculate standard deviation of returns
      variance = Enum.reduce(returns, 0, fn return, acc ->
        acc + :math.pow(return - avg_return, 2)
      end) / length(returns)
      
      std_dev = :math.sqrt(variance)
      
      # Calculate annualized Sharpe ratio
      # Assuming 252 trading days per year, scaled by actual trade count
      annual_factor = :math.sqrt(252 / max(length(returns), 1))
      
      if std_dev > 0 do
        (avg_return / std_dev) * annual_factor
      else
        if avg_return > 0, do: 3.0, else: 0.0  # Default values
      end
    end
  end
end