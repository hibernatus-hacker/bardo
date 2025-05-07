defmodule Bardo.Examples.Applications.Fx.FxSensor do
  @moduledoc """
  Sensor implementation for the Forex (FX) trading application.
  
  This module provides sensors that agents can use to perceive
  forex market data, including:
  
  - Price Chart Image (PCI): 2D grid representation of price movement
  - Price List Information (PLI): Normalized vector of recent prices
  - Internals: Current trading position information
  """
  
  alias Bardo.AgentManager.Sensor
  
  @behaviour Sensor
  
  @doc """
  Initialize a new sensor for FX trading.
  
  Parameters:
  - id: Sensor ID
  - sensor_type: :pci, :pli, or :internals
  - params: Configuration parameters for the sensor
  - fanout: Number of output elements
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  """
  @impl Sensor
  def init(id, sensor_type, params, fanout, cortex_pid, scape_pid, agent_id) do
    state = %{
      id: id,
      sensor_type: sensor_type,
      params: params,
      fanout: fanout,
      cortex_pid: cortex_pid,
      scape_pid: scape_pid,
      agent_id: agent_id
    }
    
    {:ok, state}
  end
  
  @doc """
  Read data from the sensor.
  
  This function sends a sensing request to the scape and processes the response.
  """
  @impl Sensor
  def read(state) do
    %{
      sensor_type: sensor_type,
      params: params,
      scape_pid: scape_pid,
      agent_id: agent_id
    } = state
    
    # Request data from the scape
    sense_params = %{
      sensor_type: sensor_type,
      params: params
    }
    
    # Send a sense request to the scape
    case GenServer.call(scape_pid, {:sense, agent_id, sense_params}) do
      {:success, response, _scape_state} ->
        # Process the sensor data based on the sensor type
        percept(sensor_type, response, state)
        
      {:error, _reason} ->
        # Return a default output on error
        {:ok, generate_default_output(state), state}
    end
  end
  
  # Process the sensor data based on sensor type
  defp percept(:pci, data, state) do
    # PCI is a 2D grid representation of price movements
    # Convert to a flattened normalized vector
    output = process_pci_data(data, state.params)
    {:ok, output, state}
  end
  
  defp percept(:pli, data, state) do
    # PLI is a vector of recent price information
    # Normalize the price data
    output = process_pli_data(data)
    {:ok, output, state}
  end
  
  defp percept(:internals, data, state) do
    # Internals contain current account/position information
    # Convert to a normalized vector
    output = process_internals_data(data)
    {:ok, output, state}
  end
  
  # Process Price Chart Image (PCI) data
  defp process_pci_data(price_data, params) do
    %{dimension: dimension, timeframe: timeframe} = params
    
    # Extract the necessary price data
    prices = Enum.take(price_data, timeframe)
    
    # Find min and max values for normalization
    {min_price, max_price} = find_price_range(prices)
    price_range = max(max_price - min_price, 0.0001)  # Avoid division by zero
    
    # Create a normalized 2D grid representation of price movement
    # and flatten it to a 1D vector
    create_price_grid(prices, dimension, min_price, price_range)
    |> List.flatten()
  end
  
  # Process Price List Information (PLI) data
  defp process_pli_data(price_data) do
    # Normalize the price data to the range [0, 1]
    {min_price, max_price} = find_price_range(price_data)
    price_range = max(max_price - min_price, 0.0001)  # Avoid division by zero
    
    # Normalize each price value
    Enum.map(price_data, fn price ->
      (price - min_price) / price_range
    end)
  end
  
  # Process account/position Internals data
  defp process_internals_data(internals) do
    %{
      balance: balance,
      equity: equity,
      position: position,
      open_pl: open_pl,
      leverage: leverage
    } = internals
    
    # Normalize account values
    norm_balance = normalize_balance(balance)
    norm_equity = normalize_equity(equity)
    norm_position = normalize_position(position)
    norm_open_pl = normalize_open_pl(open_pl)
    norm_leverage = normalize_leverage(leverage)
    
    [norm_balance, norm_equity, norm_position, norm_open_pl, norm_leverage]
  end
  
  # Find the minimum and maximum price values
  defp find_price_range(prices) do
    Enum.reduce(prices, {nil, nil}, fn price, {min_val, max_val} ->
      min_val = if is_nil(min_val), do: price, else: min(min_val, price)
      max_val = if is_nil(max_val), do: price, else: max(max_val, price)
      {min_val, max_val}
    end)
  end
  
  # Create a 2D grid representation of price movement
  defp create_price_grid(prices, dimension, min_price, price_range) do
    # Create a grid of dimension x dimension filled with zeros
    grid = List.duplicate(List.duplicate(0.0, dimension), dimension)
    
    # Fill the grid with price data
    timeframe = length(prices)
    
    Enum.reduce(0..(timeframe-1), grid, fn t, acc_grid ->
      # Calculate the x position (time)
      x = trunc(t * dimension / timeframe)
      
      # Calculate the y position (price level)
      price = Enum.at(prices, t)
      y = trunc((price - min_price) * (dimension - 1) / price_range)
      y = min(max(y, 0), dimension - 1)  # Ensure y is within bounds
      
      # Set the grid value at (x,y) to 1.0
      update_grid_at(acc_grid, x, y, 1.0)
    end)
  end
  
  # Update a value in a 2D grid
  defp update_grid_at(grid, x, y, value) do
    List.update_at(grid, y, fn row ->
      List.update_at(row, x, fn _ -> value end)
    end)
  end
  
  # Normalization functions for account/position data
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
    # Position is already normalized: -1 (short), 0 (none), 1 (long)
    # Convert to [0,1] range
    (position + 1) / 2
  end
  
  defp normalize_open_pl(open_pl) do
    # Normalize open P/L to [0,1] range
    # Using sigmoid function to handle wide range of P/L values
    1.0 / (1.0 + :math.exp(-open_pl / 1000.0))
  end
  
  defp normalize_leverage(leverage) do
    # Normalize leverage to [0,1] range
    # Assuming typical leverage values between 1 and 100
    min(max((leverage - 1) / 99.0, 0.0), 1.0)
  end
  
  # Generate default output when there's an error or no data
  defp generate_default_output(state) do
    case state.sensor_type do
      :pci ->
        # Default PCI is all zeros
        List.duplicate(0.0, state.fanout)
        
      :pli ->
        # Default PLI is all zeros
        List.duplicate(0.0, state.fanout)
        
      :internals ->
        # Default internals: neutral values
        List.duplicate(0.5, state.fanout)
    end
  end
end