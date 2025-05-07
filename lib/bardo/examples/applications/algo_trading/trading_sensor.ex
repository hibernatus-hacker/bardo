defmodule Bardo.Examples.Applications.AlgoTrading.TradingSensor do
  @moduledoc """
  Sensor implementation for algorithmic trading agents.
  
  This module provides various sensors that agents can use to perceive
  market data and trading environment information:
  
  - price_chart: 2D grid representation of price movement (similar to candlestick chart)
  - ohlcv: Open, High, Low, Close, Volume data for recent periods
  - indicators: Various technical indicators (moving averages, oscillators, etc.)
  - sentiment: Market sentiment indicators and market regime classification
  - account: Current account and position information
  """
  
  alias Bardo.AgentManager.Sensor
  
  @behaviour Sensor
  
  @doc """
  Initialize a new sensor for algorithmic trading.
  
  This is the implementation of the Sensor behavior's init/1 callback.
  """
  @impl Sensor
  def init(params) do
    state = %{
      id: nil,
      sensor_type: Map.get(params, :sensor_type, :ohlcv),
      params: Map.get(params, :params, %{}),
      fanout: Map.get(params, :fanout, 25),
      cortex_pid: nil,
      scape_pid: nil,
      agent_id: nil
    }
    
    {:ok, state}
  end
  
  @doc """
  Process sensory data based on sensor type.
  
  This is the implementation of the Sensor behavior's percept/2 callback.
  """
  @impl Sensor
  def percept(sensor_type, {percept, _agent_id, vl, params, mod_state}) do
    # Process the sensor data based on the sensor type
    output = case sensor_type do
      :price_chart ->
        # 2D grid representation of price movements
        # Convert to a flattened normalized vector
        process_price_chart_data(percept, params)
        
      :ohlcv ->
        # OHLCV (Open, High, Low, Close, Volume) data
        # Normalize the price data
        process_ohlcv_data(percept, params)
        
      :indicators ->
        # Technical indicators data
        # Process and normalize indicator values
        process_indicators_data(percept, params)
        
      :sentiment ->
        # Market sentiment data
        # Process sentiment indicators
        process_sentiment_data(percept, params)
        
      :account ->
        # Account information
        # Normalize account data
        process_account_data(percept, params)
        
      _ ->
        # Default case for unknown sensor types
        generate_default_output(vl)
    end
    
    # Return the processed sensory input and state
    {output, mod_state}
  end
  
  @doc """
  Send a sensing request to the scape.
  
  This is the implementation of the Sensor behavior's sense/2 callback.
  """
  @impl Sensor
  def sense(sensor_type, {agent_id, _vl, params, scape, sensor_id, _op_mode, mod_state}) do
    # Prepare sensing parameters
    sense_params = %{
      sensor_type: sensor_type,
      params: params
    }
    
    # Request data from the scape via PrivateScape
    if is_pid(scape) do
      Bardo.AgentManager.PrivateScape.sense(scape, agent_id, sensor_id, sense_params)
    end
    
    # Return state (PrivateScape will send percept back to sensor)
    mod_state
  end
  
  @doc """
  Cleanup resources when terminating.
  """
  @impl Sensor
  def terminate(_reason, _mod_state) do
    # No resources to clean up
    :ok
  end
  
  # Process Price Chart data - 2D representation of price movements
  defp process_price_chart_data(price_data, params) do
    %{dimension: dimension, timeframe: timeframe} = params
    dimension = dimension || 10
    timeframe = timeframe || 30
    
    # Extract the necessary price data (ensure we have enough data)
    chart_data = case price_data do
      data when is_list(data) -> Enum.take(data, timeframe)
      _ -> []
    end
    
    # If we don't have enough data, return zeros
    if length(chart_data) < 2 do
      List.duplicate(0.0, dimension * dimension)
    else
      # Find min and max values for normalization
      {min_price, max_price} = find_price_range(chart_data)
      price_range = max(max_price - min_price, 0.0001)  # Avoid division by zero
      
      # Create a normalized 2D grid representation of price movement
      # and flatten it to a 1D vector
      create_price_grid(chart_data, dimension, min_price, price_range)
      |> List.flatten()
    end
  end
  
  # Process OHLCV (Open, High, Low, Close, Volume) data
  defp process_ohlcv_data(price_data, params) do
    periods = Map.get(params, :periods, 5)
    
    # Extract the required number of periods from the data
    ohlcv_data = case price_data do
      data when is_list(data) -> Enum.take(data, periods)
      _ -> []
    end
    
    # If we don't have enough data, return zeros
    if length(ohlcv_data) < 1 do
      List.duplicate(0.0, periods * 5)
    else
      # Find min and max values for normalization
      {min_price, max_price} = find_price_range(ohlcv_data)
      price_range = max(max_price - min_price, 0.0001)  # Avoid division by zero
      
      # Find min and max volume for normalization
      {min_volume, max_volume} = find_volume_range(ohlcv_data)
      volume_range = max(max_volume - min_volume, 1)  # Avoid division by zero
      
      # Normalize each OHLCV value
      ohlcv_data
      |> Enum.flat_map(fn candle ->
        [
          normalize_price(candle.open, min_price, price_range),
          normalize_price(candle.high, min_price, price_range),
          normalize_price(candle.low, min_price, price_range),
          normalize_price(candle.close, min_price, price_range),
          normalize_volume(candle.volume, min_volume, volume_range)
        ]
      end)
      |> pad_list(periods * 5, 0.0)  # Ensure consistent length
    end
  end
  
  # Process Technical Indicators data
  defp process_indicators_data(indicators_data, params) do
    # Get the list of indicators from params
    indicator_list = Map.get(params, :indicators, [])
    
    # If no indicator list is provided, return zeros
    if indicator_list == [] do
      List.duplicate(0.0, 15)  # Default to 15 indicators
    else
      # Process each indicator
      Enum.map(indicator_list, fn indicator ->
        # Extract the indicator value from the data
        value = case indicators_data do
          %{^indicator => val} -> val
          _ -> nil
        end
        
        # Normalize the indicator value based on its type
        normalize_indicator(indicator, value)
      end)
      |> pad_list(15, 0.0)  # Ensure consistent length
    end
  end
  
  # Process Market Sentiment data
  defp process_sentiment_data(sentiment_data, params) do
    # Get the list of sentiment types from params
    sentiment_types = Map.get(params, :sentiment_types, [])
    
    # If no sentiment types are provided, return zeros
    if sentiment_types == [] do
      List.duplicate(0.5, 5)  # Default to 5 sentiment indicators with neutral value
    else
      # Process each sentiment type
      Enum.map(sentiment_types, fn sentiment_type ->
        # Extract the sentiment value from the data
        value = case sentiment_data do
          %{^sentiment_type => val} -> val
          _ -> nil
        end
        
        # Normalize the sentiment value (typically already in [0,1] range)
        normalize_sentiment(sentiment_type, value)
      end)
      |> pad_list(5, 0.5)  # Ensure consistent length with neutral default
    end
  end
  
  # Process Account Information data
  defp process_account_data(account_data, _params) do
    # Extract account information
    balance = Map.get(account_data, :balance, 0.0)
    equity = Map.get(account_data, :equity, 0.0)
    position = Map.get(account_data, :position, 0)
    open_pl = Map.get(account_data, :open_pl, 0.0)
    drawdown = Map.get(account_data, :drawdown, 0.0)
    
    # Normalize account values
    [
      normalize_balance(balance),
      normalize_equity(equity),
      normalize_position(position),
      normalize_open_pl(open_pl),
      normalize_drawdown(drawdown)
    ]
  end
  
  # Find the minimum and maximum price values in OHLC data
  defp find_price_range(price_data) do
    Enum.reduce(price_data, {nil, nil}, fn candle, {min_val, max_val} ->
      # Extract OHLC values
      values = [
        Map.get(candle, :open, 0.0),
        Map.get(candle, :high, 0.0),
        Map.get(candle, :low, 0.0),
        Map.get(candle, :close, 0.0)
      ]
      
      # Find the min and max values
      candle_min = Enum.min(values)
      candle_max = Enum.max(values)
      
      # Update overall min and max
      min_val = if is_nil(min_val), do: candle_min, else: min(min_val, candle_min)
      max_val = if is_nil(max_val), do: candle_max, else: max(max_val, candle_max)
      
      {min_val, max_val}
    end)
  end
  
  # Find the minimum and maximum volume values
  defp find_volume_range(price_data) do
    Enum.reduce(price_data, {nil, nil}, fn candle, {min_val, max_val} ->
      volume = Map.get(candle, :volume, 0)
      
      min_val = if is_nil(min_val), do: volume, else: min(min_val, volume)
      max_val = if is_nil(max_val), do: volume, else: max(max_val, volume)
      
      {min_val, max_val}
    end)
  end
  
  # Create a 2D grid representation of price movement (like a candlestick chart)
  defp create_price_grid(price_data, dimension, min_price, price_range) do
    # Create a grid of dimension x dimension filled with zeros
    grid = List.duplicate(List.duplicate(0.0, dimension), dimension)
    
    # Fill the grid with price data
    timeframe = length(price_data)
    
    Enum.reduce(0..(timeframe-1), grid, fn t, acc_grid ->
      # Calculate the x position (time)
      x = trunc(t * dimension / timeframe)
      
      # Extract price data for this point
      candle = Enum.at(price_data, t)
      
      # Calculate the y positions for open, high, low, close
      open_y = calculate_y_position(candle.open, min_price, price_range, dimension)
      high_y = calculate_y_position(candle.high, min_price, price_range, dimension)
      low_y = calculate_y_position(candle.low, min_price, price_range, dimension)
      close_y = calculate_y_position(candle.close, min_price, price_range, dimension)
      
      # Determine if candle is bullish (close > open) or bearish (close < open)
      is_bullish = candle.close >= candle.open
      
      # Create a "wick" from high to low
      wick_grid = Enum.reduce(low_y..high_y, acc_grid, fn y, g ->
        update_grid_at(g, x, y, 0.3)  # Partial value for wick
      end)
      
      # Create the "body" from open to close
      {body_start, body_end} = if is_bullish, do: {open_y, close_y}, else: {close_y, open_y}
      
      Enum.reduce(body_start..body_end, wick_grid, fn y, g ->
        # Use different values for bullish vs bearish
        value = if is_bullish, do: 1.0, else: 0.7
        update_grid_at(g, x, y, value)
      end)
    end)
  end
  
  # Calculate y position for a price value
  defp calculate_y_position(price, min_price, price_range, dimension) do
    y = trunc((price - min_price) * (dimension - 1) / price_range)
    min(max(y, 0), dimension - 1)  # Ensure y is within bounds
  end
  
  # Update a value in a 2D grid
  defp update_grid_at(grid, x, y, value) do
    List.update_at(grid, y, fn row ->
      List.update_at(row, x, fn current -> max(current, value) end)
    end)
  end
  
  # Normalization functions
  
  # Normalize a price value
  defp normalize_price(price, min_price, price_range) do
    (price - min_price) / price_range
  end
  
  # Normalize a volume value
  defp normalize_volume(volume, min_volume, volume_range) do
    (volume - min_volume) / volume_range
  end
  
  # Normalize a technical indicator value based on its type
  defp normalize_indicator(indicator_type, value) when is_number(value) do
    case indicator_type do
      # Oscillators already in a standard range
      :rsi_14 -> value / 100.0  # RSI is 0-100, normalize to 0-1
      :stoch_k -> value / 100.0 # Stochastic is 0-100
      :stoch_d -> value / 100.0 # Stochastic is 0-100
      
      # Moving averages - convert to percent difference from current price
      :sma_20 -> sigmoid(value * 100.0)  # Percent difference * 100 through sigmoid
      :sma_50 -> sigmoid(value * 100.0)
      :sma_200 -> sigmoid(value * 100.0)
      :ema_20 -> sigmoid(value * 100.0)
      :ema_50 -> sigmoid(value * 100.0)
      
      # MACD is typically centered around 0, use sigmoid to normalize
      :macd -> sigmoid(value * 10.0)
      :macd_signal -> sigmoid(value * 10.0)
      
      # Bollinger Bands - already normalized as percent
      :bollinger_upper -> value
      :bollinger_lower -> value
      
      # ADX is 0-100
      :adx_14 -> value / 100.0
      
      # ATR - use sigmoid to normalize volatile value
      :atr_14 -> sigmoid(value * 5.0)
      
      # Default for unknown indicators
      _ -> sigmoid(value)
    end
  end
  defp normalize_indicator(_indicator_type, _value), do: 0.0  # Default for nil values
  
  # Normalize a sentiment value
  defp normalize_sentiment(_sentiment_type, value) when is_number(value) do
    # Most sentiment values should already be normalized to [0,1]
    # But ensure they're in that range
    min(max(value, 0.0), 1.0)
  end
  defp normalize_sentiment(_sentiment_type, _value), do: 0.5  # Default neutral value
  
  # Normalization functions for account data
  defp normalize_balance(balance) do
    # Normalize balance to [0,1] range
    # Assuming typical account sizes between 0 and 100,000
    min(max(balance / 100_000.0, 0.0), 1.0)
  end
  
  defp normalize_equity(equity) do
    # Normalize equity to [0,1] range
    # Assuming typical equity values between 0 and 100,000
    min(max(equity / 100_000.0, 0.0), 1.0)
  end
  
  defp normalize_position(position) do
    # Position is typically -1 (short), 0 (none), 1 (long)
    # Convert to [0,1] range
    (position + 1) / 2
  end
  
  defp normalize_open_pl(open_pl) do
    # Normalize open P/L to [0,1] range
    # Using sigmoid function to handle wide range of P/L values
    sigmoid(open_pl / 1000.0)
  end
  
  defp normalize_drawdown(drawdown) do
    # Drawdown is typically 0-100%
    # Normalize to [0,1] range where 0 = no drawdown, 1 = maximum drawdown
    min(max(drawdown / 100.0, 0.0), 1.0)
  end
  
  # Sigmoid function for normalization
  defp sigmoid(x) do
    1.0 / (1.0 + :math.exp(-x))
  end
  
  # Pad a list to a specified length with a default value
  defp pad_list(list, length, default) do
    current_length = length(list)
    if current_length >= length do
      Enum.take(list, length)
    else
      list ++ List.duplicate(default, length - current_length)
    end
  end
  
  # Generate default output when there's an error or no data
  defp generate_default_output(vl) do
    # Return a vector of appropriate length filled with zeros
    List.duplicate(0.0, vl)
  end
end