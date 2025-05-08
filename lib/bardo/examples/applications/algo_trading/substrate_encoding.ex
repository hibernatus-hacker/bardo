defmodule Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding do
  @moduledoc """
  Substrate-based neural network encoding for algorithmic trading.
  
  This module implements Hypercube-based Substrate encoding for neural networks
  used in algorithmic trading. Substrate encoding provides several advantages:
  
  1. **Geometric interpretation** - Maps market data to a coordinate space
  2. **Regularized structure** - Provides natural symmetry in the network
  3. **Improved generalization** - Better performance on unseen market conditions
  4. **Efficient representation** - Compact encoding of complex patterns
  
  The substrate encoding maps market data (candles, indicators, etc.) into a 3D space:
  - X-axis: Time (recent to older candles)
  - Y-axis: Price levels (high to low)
  - Z-axis: Data types (OHLC, volume, indicators)
  
  Neurons are then placed at specific coordinates in this space, and connections
  are established based on geometric rules and evolved weights.
  """
  
  alias Bardo.PopulationManager.Genotype
  # Models is used indirectly through Genotype
  
  @doc """
  Create a substrate-encoded genotype for an algorithmic trading neural network.
  
  This function creates a genotype with a predefined substrate structure optimized
  for processing market data and generating trading signals.
  
  ## Parameters
  
  - opts: Map of configuration options with the following keys:
    - :input_time_points - Number of time points for input data (default: 60)
    - :input_price_levels - Number of price levels for input data (default: 20)
    - :input_data_types - Number of data types (OHLC, indicators) (default: 10)
    - :hidden_layers - Number of hidden layers (default: 2)
    - :hidden_neurons_per_layer - Neurons per hidden layer (default: 20)
    - :output_neurons - Number of output neurons (default: 3)
    
  ## Returns
  
  A genotype map with substrate-encoded neural network structure.
  """
  def create_substrate_genotype(opts \\ %{}) do
    # Extract configuration options with defaults
    input_time_points = Map.get(opts, :input_time_points, 60)
    input_price_levels = Map.get(opts, :input_price_levels, 20)
    input_data_types = Map.get(opts, :input_data_types, 10)
    hidden_layers = Map.get(opts, :hidden_layers, 2)
    hidden_neurons_per_layer = Map.get(opts, :hidden_neurons_per_layer, 20)
    output_neurons = Map.get(opts, :output_neurons, 3)
    
    # Initialize an empty genotype
    genotype = Genotype.new()
    
    # Add input neurons (in a 3D grid: time x price levels x data types)
    {genotype, input_neurons} = create_input_layer(
      genotype, 
      input_time_points, 
      input_price_levels, 
      input_data_types
    )
    
    # Add hidden layers
    {genotype, hidden_layer_neurons} = create_hidden_layers(
      genotype, 
      hidden_layers, 
      hidden_neurons_per_layer
    )
    
    # Add output neurons
    {genotype, output_neurons} = create_output_layer(
      genotype, 
      output_neurons
    )
    
    # Connect layers with substrate-based connectivity
    genotype = connect_layers_with_substrate(
      genotype, 
      input_neurons, 
      hidden_layer_neurons, 
      output_neurons
    )
    
    # Add metadata about the substrate structure
    genotype = Map.put(genotype, :substrate_metadata, %{
      input_time_points: input_time_points,
      input_price_levels: input_price_levels,
      input_data_types: input_data_types,
      hidden_layers: hidden_layers,
      hidden_neurons_per_layer: hidden_neurons_per_layer,
      output_neurons: output_neurons,
      input_neuron_ids: input_neurons,
      hidden_neuron_ids: hidden_layer_neurons,
      output_neuron_ids: output_neurons,
      encoding: :substrate
    })
    
    genotype
  end
  
  @doc """
  Create input neurons in a 3D substrate grid (time x price levels x data types).
  
  ## Parameters
  
  - genotype: The current genotype to modify
  - time_points: Number of time points (x-axis)
  - price_levels: Number of price levels (y-axis)
  - data_types: Number of data types (z-axis)
  
  ## Returns
  
  {updated_genotype, list_of_input_neuron_ids}
  """
  def create_input_layer(genotype, time_points, price_levels, data_types) do
    # Create neurons for each point in the 3D grid
    Enum.reduce(0..(time_points-1), {genotype, []}, fn x, {g, neurons} ->
      Enum.reduce(0..(price_levels-1), {g, neurons}, fn y, {g2, neurons2} ->
        Enum.reduce(0..(data_types-1), {g2, neurons2}, fn z, {g3, neurons3} ->
          # Calculate normalized coordinates (-1.0 to 1.0)
          x_coord = -1.0 + 2.0 * (x / (time_points - 1))
          y_coord = -1.0 + 2.0 * (y / (price_levels - 1))
          z_coord = -1.0 + 2.0 * (z / (data_types - 1))
          
          # Create neuron with substrate coordinates
          neuron_id = "input_#{x}_#{y}_#{z}"
          neuron = %{
            layer: :input,
            activation_function: :tanh,
            substrate_coords: [x_coord, y_coord, z_coord],
            bias: 0.0
          }
          
          # Add neuron to genotype
          updated_g = put_in(g3, [:neurons, neuron_id], neuron)
          
          # Return updated genotype and append neuron id to list
          {updated_g, [neuron_id | neurons3]}
        end)
      end)
    end)
  end
  
  @doc """
  Create hidden layers with neurons arranged in a substrate pattern.
  
  ## Parameters
  
  - genotype: The current genotype to modify
  - num_layers: Number of hidden layers
  - neurons_per_layer: Number of neurons per hidden layer
  
  ## Returns
  
  {updated_genotype, map_of_hidden_neuron_ids_by_layer}
  """
  def create_hidden_layers(genotype, num_layers, neurons_per_layer) do
    # Create neurons for each hidden layer
    Enum.reduce(0..(num_layers-1), {genotype, %{}}, fn layer_idx, {g, neurons_by_layer} ->
      # Calculate z-coordinate for this layer (evenly distributed)
      z_coord = -0.5 + layer_idx * (1.0 / (num_layers - 1))
      
      # Create neurons for this layer
      {updated_g, layer_neurons} = Enum.reduce(0..(neurons_per_layer-1), {g, []}, fn neuron_idx, {g2, neuron_list} ->
        # Calculate x, y coordinates using a grid or spiral pattern
        {x_coord, y_coord} = calculate_hidden_neuron_coords(neuron_idx, neurons_per_layer)
        
        # Create neuron with substrate coordinates
        neuron_id = "hidden_#{layer_idx}_#{neuron_idx}"
        neuron = %{
          layer: :hidden,
          activation_function: :tanh,
          substrate_coords: [x_coord, y_coord, z_coord],
          bias: :rand.normal() * 0.1
        }
        
        # Add neuron to genotype
        updated_g2 = put_in(g2, [:neurons, neuron_id], neuron)
        
        # Return updated genotype and append neuron id to list
        {updated_g2, [neuron_id | neuron_list]}
      end)
      
      # Update the map of neurons by layer
      updated_neurons_by_layer = Map.put(neurons_by_layer, layer_idx, layer_neurons)
      
      {updated_g, updated_neurons_by_layer}
    end)
  end
  
  @doc """
  Create output neurons for the substrate network.
  
  ## Parameters
  
  - genotype: The current genotype to modify
  - num_outputs: Number of output neurons
  
  ## Returns
  
  {updated_genotype, list_of_output_neuron_ids}
  """
  def create_output_layer(genotype, num_outputs) do
    # Create output neurons arranged in a substrate pattern
    Enum.reduce(0..(num_outputs-1), {genotype, []}, fn idx, {g, neurons} ->
      # Calculate coordinates for output neurons
      x_coord = if num_outputs > 1, do: -1.0 + 2.0 * (idx / (num_outputs - 1)), else: 0.0
      y_coord = 0.0  # All on the same y level
      z_coord = 1.0  # Furthest forward in z direction
      
      # Create neuron with substrate coordinates
      neuron_id = "output_#{idx}"
      neuron = %{
        layer: :output,
        activation_function: :tanh,
        substrate_coords: [x_coord, y_coord, z_coord],
        bias: :rand.normal() * 0.1
      }
      
      # Add neuron to genotype
      updated_g = put_in(g, [:neurons, neuron_id], neuron)
      
      # Return updated genotype and append neuron id to list
      {updated_g, [neuron_id | neurons]}
    end)
  end
  
  @doc """
  Connect layers using substrate-based connectivity patterns.
  
  ## Parameters
  
  - genotype: The current genotype to modify
  - input_neurons: List of input neuron IDs
  - hidden_layer_neurons: Map of hidden layer neuron IDs by layer
  - output_neurons: List of output neuron IDs
  
  ## Returns
  
  Updated genotype with connections added
  """
  def connect_layers_with_substrate(genotype, input_neurons, hidden_layer_neurons, output_neurons) do
    # Connect input to first hidden layer
    first_hidden_layer = Map.get(hidden_layer_neurons, 0, [])
    g1 = connect_with_substrate_pattern(genotype, input_neurons, first_hidden_layer, :input_to_hidden)
    
    # Connect hidden layers to each other
    g2 = Enum.reduce(0..(map_size(hidden_layer_neurons) - 2), g1, fn layer_idx, g ->
      current_layer = Map.get(hidden_layer_neurons, layer_idx, [])
      next_layer = Map.get(hidden_layer_neurons, layer_idx + 1, [])
      connect_with_substrate_pattern(g, current_layer, next_layer, :hidden_to_hidden)
    end)
    
    # Connect last hidden layer to output
    last_hidden_layer = Map.get(hidden_layer_neurons, map_size(hidden_layer_neurons) - 1, [])
    g3 = connect_with_substrate_pattern(g2, last_hidden_layer, output_neurons, :hidden_to_output)
    
    # Additional forward (skip) connections from input to output
    g4 = connect_with_substrate_pattern(g3, input_neurons, output_neurons, :input_to_output, 0.2)
    
    g4
  end
  
  @doc """
  Connect two layers of neurons using substrate coordinates to determine connectivity.
  
  ## Parameters
  
  - genotype: The current genotype to modify
  - from_neurons: List of source neuron IDs
  - to_neurons: List of target neuron IDs
  - connection_type: Symbol indicating the type of connection pattern
  - connection_probability: Probability of creating each potential connection
  
  ## Returns
  
  Updated genotype with connections added
  """
  def connect_with_substrate_pattern(genotype, from_neurons, to_neurons, connection_type, connection_probability \\ 1.0) do
    # For each possible connection
    Enum.reduce(from_neurons, genotype, fn from_id, g1 ->
      Enum.reduce(to_neurons, g1, fn to_id, g2 ->
        # Skip if already connected
        if has_connection?(g2, from_id, to_id) do
          g2
        else
          # Get substrate coordinates
          from_coords = get_in(g2, [:neurons, from_id, :substrate_coords])
          to_coords = get_in(g2, [:neurons, to_id, :substrate_coords])
          
          # Determine whether to create connection based on coordinates and pattern
          if should_connect?(from_coords, to_coords, connection_type, connection_probability) do
            # Create connection with weight based on substrate distance
            weight = calculate_weight_from_distance(from_coords, to_coords, connection_type)
            
            # Add connection to genotype
            conn_id = "conn_#{from_id}_#{to_id}"
            connection = %{
              from_id: from_id,
              to_id: to_id,
              weight: weight
            }
            
            put_in(g2, [:connections, conn_id], connection)
          else
            g2
          end
        end
      end)
    end)
  end
  
  # Calculate coordinates for hidden neurons using a spiral or grid pattern
  defp calculate_hidden_neuron_coords(idx, total) do
    # Use a grid-based approach for arranging neurons
    grid_size = :math.sqrt(total) |> :math.ceil() |> trunc()
    
    # Calculate grid position
    grid_x = rem(idx, grid_size)
    grid_y = div(idx, grid_size)
    
    # Normalize to [-1, 1] range
    x = -1.0 + 2.0 * (grid_x / (grid_size - 1))
    y = -1.0 + 2.0 * (grid_y / (grid_size - 1))
    
    # Add small random jitter for more natural distribution
    x = x + :rand.normal() * 0.05
    y = y + :rand.normal() * 0.05
    
    # Ensure coordinates stay in range
    x = max(-1.0, min(1.0, x))
    y = max(-1.0, min(1.0, y))
    
    {x, y}
  end
  
  # Check if two neurons should be connected based on their substrate coordinates
  defp should_connect?(from_coords, to_coords, connection_type, connection_probability) do
    # Apply random connection probability first
    if :rand.uniform() > connection_probability do
      false
    else
      case connection_type do
        :input_to_hidden ->
          # Connect based on proximity and forward direction (z-axis)
          distance = euclidean_distance(from_coords, to_coords)
          z_from = Enum.at(from_coords, 2)
          z_to = Enum.at(to_coords, 2)
          distance < 1.0 && z_from < z_to
          
        :hidden_to_hidden ->
          # Connect if in forward direction and within distance threshold
          distance = euclidean_distance(from_coords, to_coords)
          z_from = Enum.at(from_coords, 2)
          z_to = Enum.at(to_coords, 2)
          distance < 0.8 && z_from < z_to
          
        :hidden_to_output ->
          # Connect all hidden to output neurons
          true
          
        :input_to_output ->
          # Selective connections from input to output for skip connections
          # Focus on recent time points (higher x value)
          x_from = Enum.at(from_coords, 0)
          x_from > 0.5 && :rand.uniform() < 0.3
          
        _ ->
          # Default: use distance-based connectivity
          distance = euclidean_distance(from_coords, to_coords)
          distance < 0.8
      end
    end
  end
  
  # Calculate connection weight based on substrate coordinates
  defp calculate_weight_from_distance(from_coords, to_coords, connection_type) do
    # Base weight calculation on distance between neurons
    distance = euclidean_distance(from_coords, to_coords)
    
    # Different weight initialization based on connection type
    base_weight = case connection_type do
      :input_to_hidden -> :rand.normal() * 0.2
      :hidden_to_hidden -> :rand.normal() * 0.4
      :hidden_to_output -> :rand.normal() * 0.5
      :input_to_output -> :rand.normal() * 0.1
      _ -> :rand.normal() * 0.3
    end
    
    # Adjust weight by distance (closer neurons have stronger connections)
    distance_factor = :math.exp(-distance * 2)
    base_weight * distance_factor
  end
  
  # Check if a connection already exists
  defp has_connection?(genotype, from_id, to_id) do
    Enum.any?(genotype.connections, fn {_id, conn} ->
      conn.from_id == from_id && conn.to_id == to_id
    end)
  end
  
  # Calculate Euclidean distance between coordinates
  defp euclidean_distance(coords1, coords2) do
    Enum.zip(coords1, coords2)
    |> Enum.map(fn {a, b} -> (a - b) * (a - b) end)
    |> Enum.sum()
    |> :math.sqrt()
  end
  
  @doc """
  Convert price data to a substrate input grid representation.
  
  This function maps OHLCV and indicator data into the substrate's 3D coordinate system
  for neural network processing.
  
  ## Parameters
  
  - price_data: List of price data candles
  - indicators: Map of technical indicators
  - input_time_points: Number of time points to include (default: 60)
  - input_price_levels: Number of price levels to divide the range into (default: 20)
  - input_data_types: Number of data types to include (default: 10)
  
  ## Returns
  
  A 3D grid (as nested lists) of normalized values corresponding to substrate inputs
  """
  def convert_price_data_to_substrate(price_data, indicators, input_time_points \\ 60, input_price_levels \\ 20, input_data_types \\ 10) do
    # Take the most recent candles up to input_time_points
    recent_data = Enum.take(price_data, input_time_points)
    |> Enum.reverse()  # Most recent first
    
    # Calculate price range for normalization
    price_range = calculate_price_range(recent_data)
    {min_price, max_price} = price_range
    
    # Create the 3D grid with dimensions [time][price][data_type]
    # Initialize with zeros
    grid = for _x <- 0..(input_time_points-1) do
      for _y <- 0..(input_price_levels-1) do
        for _z <- 0..(input_data_types-1) do
          0.0
        end
      end
    end
    
    # Fill the grid with data
    grid = 
      # Loop through time points
      Enum.reduce(0..min(input_time_points - 1, length(recent_data) - 1), grid, fn t, g1 ->
        candle = Enum.at(recent_data, t)
        
        # Loop through price levels
        Enum.reduce(0..(input_price_levels-1), g1, fn p, g2 ->
          # Calculate price at this level
          price_at_level = min_price + (max_price - min_price) * (p / (input_price_levels - 1))
          
          # Loop through data types
          Enum.reduce(0..(input_data_types-1), g2, fn d, g3 ->
            # Get value for this data type, time, and price
            value = get_data_value(candle, indicators, t, price_at_level, d)
            
            # Update grid at this position
            List.update_at(g3, t, fn time_slice ->
              List.update_at(time_slice, p, fn price_slice ->
                List.replace_at(price_slice, d, value)
              end)
            end)
          end)
        end)
      end)
    
    grid
  end
  
  @doc """
  Flatten a 3D substrate grid to a 1D list for neural network input.
  
  ## Parameters
  
  - grid: The 3D grid of substrate values
  - genotype: The substrate-encoded genotype (for coordinate mapping)
  
  ## Returns
  
  A map of neuron ID to input value, ready for neural network activation
  """
  def flatten_substrate_grid(grid, genotype) do
    # Extract input neuron IDs and their coordinates
    input_neurons = for {id, neuron} <- genotype.neurons, neuron.layer == :input do
      {id, neuron.substrate_coords}
    end
    
    # Get grid dimensions
    time_points = length(grid)
    price_levels = if time_points > 0, do: length(Enum.at(grid, 0)), else: 0
    data_types = if price_levels > 0, do: length(Enum.at(Enum.at(grid, 0), 0)), else: 0
    
    # Map substrate coordinates to grid indices
    Enum.reduce(input_neurons, %{}, fn {id, coords}, acc ->
      # Convert substrate coords (-1.0 to 1.0) to grid indices
      [x_coord, y_coord, z_coord] = coords
      
      x_idx = trunc((x_coord + 1.0) / 2.0 * (time_points - 1))
      y_idx = trunc((y_coord + 1.0) / 2.0 * (price_levels - 1))
      z_idx = trunc((z_coord + 1.0) / 2.0 * (data_types - 1))
      
      # Ensure indices are within bounds
      x_idx = max(0, min(time_points - 1, x_idx))
      y_idx = max(0, min(price_levels - 1, y_idx))
      z_idx = max(0, min(data_types - 1, z_idx))
      
      # Get the value from the grid
      value = get_in(grid, [Access.at(x_idx), Access.at(y_idx), Access.at(z_idx)]) || 0.0
      
      # Add to the map
      Map.put(acc, id, value)
    end)
  end
  
  # Calculate the min and max price from candle data
  defp calculate_price_range(candles) do
    # Initialize with first candle's prices or defaults
    init_candle = List.first(candles) || %{high: 1.0, low: 0.0}
    
    # Find min and max across all candles
    Enum.reduce(candles, {init_candle.low, init_candle.high}, fn candle, {min_p, max_p} ->
      {
        min(min_p, candle.low),
        max(max_p, candle.high)
      }
    end)
  end
  
  # Get data value for a specific position in the substrate
  defp get_data_value(candle, indicators, time_idx, price_level, data_type) do
    case data_type do
      # Price level activation (1.0 if price crosses this level, 0.0 otherwise)
      0 -> 
        if candle.low <= price_level && candle.high >= price_level, do: 1.0, else: 0.0
        
      # Open price proximity
      1 -> 
        gaussian_activation(candle.open, price_level, (candle.high - candle.low) * 0.1)
        
      # High price proximity
      2 -> 
        gaussian_activation(candle.high, price_level, (candle.high - candle.low) * 0.1)
        
      # Low price proximity
      3 -> 
        gaussian_activation(candle.low, price_level, (candle.high - candle.low) * 0.1)
        
      # Close price proximity
      4 -> 
        gaussian_activation(candle.close, price_level, (candle.high - candle.low) * 0.1)
        
      # Volume (higher at price levels near VWAP)
      5 -> 
        vwap = (candle.high + candle.low + candle.close) / 3
        volume_activation = gaussian_activation(vwap, price_level, (candle.high - candle.low) * 0.2)
        normalized_volume = min(candle.volume / 10000, 1.0)  # Normalize volume
        volume_activation * normalized_volume
        
      # Technical indicators (use different indicators based on data_type)
      _ ->
        get_indicator_value(indicators, data_type - 6, time_idx, price_level)
    end
  end
  
  # Gaussian activation function for continuous value representation
  defp gaussian_activation(center, point, sigma) do
    distance = abs(center - point)
    :math.exp(-(distance * distance) / (2 * sigma * sigma))
  end
  
  # Get indicator value for a specific data type and time
  defp get_indicator_value(indicators, indicator_idx, time_idx, _price_level) do
    case indicator_idx do
      0 -> # Moving Average
        get_in(indicators, [:sma_20, Access.at(time_idx)]) || 0.5
        
      1 -> # RSI
        rsi = get_in(indicators, [:rsi_14, Access.at(time_idx)]) || 50.0
        rsi / 100.0  # Normalize to [0, 1]
        
      2 -> # MACD
        macd = get_in(indicators, [:macd, Access.at(time_idx)]) || 0.0
        signal = get_in(indicators, [:macd_signal, Access.at(time_idx)]) || 0.0
        # Normalize and rescale to [-1, 1]
        (macd - signal) * 5.0 |> min(1.0) |> max(-1.0)
        
      3 -> # Bollinger Bands
        upper = get_in(indicators, [:bollinger_upper, Access.at(time_idx)]) || 0.1
        lower = get_in(indicators, [:bollinger_lower, Access.at(time_idx)]) || -0.1
        # Calculate relative position between bands
        (upper + lower) / 2.0
        
      _ -> # Default to 0.0 for undefined indicators
        0.0
    end
  end
end