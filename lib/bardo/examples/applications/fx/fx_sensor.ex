defmodule Bardo.Examples.Applications.Fx.FxSensor do
  @moduledoc """
  Sensor implementation for the Forex (FX) trading application.

  This module provides sensors that agents can use to perceive
  forex market data, including:

  - Price Chart Image (PCI): 2D grid representation of price movement
  - Price List Information (PLI): Normalized vector of recent prices
  - Internals: Current trading position information
  """

  @doc """
  Creates a Price Chart Image (PCI) sensor configuration.

  ## Parameters
    * `dimension` - The dimension size of the price chart grid
    * `timeframe` - The number of time periods to consider
    * `cortex_id` - The ID of the cortex this sensor is connected to
    * `scape_name` - The name of the scape this sensor will read from

  ## Returns
    * A sensor specification map
  """
  @spec pci(pos_integer(), pos_integer(), binary() | atom(), atom()) :: map()
  def pci(dimension, timeframe, cortex_id, scape_name) do
    %{
      id: nil,
      name: :pci_sensor,
      type: :pci,
      cx_id: cortex_id,
      scape: scape_name,
      vl: dimension * dimension,  # Flattened 2D grid
      fanout_ids: [],
      generation: nil,
      format: nil,
      parameters: %{
        dimension: dimension,
        timeframe: timeframe
      }
    }
  end

  @doc """
  Creates a Price List Information (PLI) sensor configuration.

  ## Parameters
    * `count` - The number of price points to consider
    * `period` - The time period between price points
    * `cortex_id` - The ID of the cortex this sensor is connected to
    * `scape_name` - The name of the scape this sensor will read from

  ## Returns
    * A sensor specification map
  """
  @spec pli(pos_integer(), pos_integer(), binary() | atom(), atom()) :: map()
  def pli(count, period, cortex_id, scape_name) do
    %{
      id: nil,
      name: :pli_sensor,
      type: :pli,
      cx_id: cortex_id,
      scape: scape_name,
      vl: count,  # One value per price point
      fanout_ids: [],
      generation: nil,
      format: nil,
      parameters: %{
        count: count,
        period: period
      }
    }
  end

  @doc """
  Creates an Internals sensor configuration for tracking account state.

  ## Parameters
    * `size` - The number of internal account state variables to track
    * `cortex_id` - The ID of the cortex this sensor is connected to
    * `scape_name` - The name of the scape this sensor will read from

  ## Returns
    * A sensor specification map
  """
  @spec internals(pos_integer(), binary() | atom(), atom()) :: map()
  def internals(size, cortex_id, scape_name) do
    %{
      id: nil,
      name: :internals_sensor,
      type: :internals,
      cx_id: cortex_id,
      scape: scape_name,
      vl: size,  # Typically 5 internal variables: balance, equity, position, P/L, leverage
      fanout_ids: [],
      generation: nil,
      format: nil,
      parameters: %{
        size: size
      }
    }
  end
  
  alias Bardo.AgentManager.Sensor
  
  @behaviour Sensor
  
  @doc """
  Initialize a new sensor for FX trading.
  
  This is the implementation of the Sensor behavior's init/1 callback.
  """
  @impl Sensor
  def init(params) do
    state = %{
      id: nil,
      sensor_type: Map.get(params, :sensor_type, :pli),
      params: Map.get(params, :params, %{dimension: 10, timeframe: 50}),
      fanout: Map.get(params, :fanout, 10),
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
      :pci ->
        # PCI is a 2D grid representation of price movements
        # Convert to a flattened normalized vector
        process_pci_data(percept, params)
        
      :pli ->
        # PLI is a vector of recent price information
        # Normalize the price data
        process_pli_data(percept)
        
      :internals ->
        # Internals contain current account/position information
        # Convert to a normalized vector
        process_internals_data(percept)
        
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
  # Legacy init function for compatibility
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
  # Legacy read function for compatibility
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
      {:success, response, _} ->
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
  defp generate_default_output(vl) do
    # Return a vector of appropriate length filled with zeros
    List.duplicate(0.0, vl)
  end
end