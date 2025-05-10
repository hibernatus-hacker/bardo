defmodule Bardo.Examples.Applications.AlgoTrading.DataUtils do
  @moduledoc """
  Utilities for managing market data for algorithmic trading.
  
  This module provides functions for:
  - Loading and saving historical market data
  - Converting between different data formats
  - Preprocessing and cleaning market data
  - Extracting features from market data
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  
  @doc """
  Download historical data for the specified instrument and timeframe.
  
  ## Parameters
  
  - broker_module: Module implementing the BrokerInterface
  - broker_state: Broker state map from initialization
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  - timeframe: Timeframe code (e.g., "M15", "H1")
  - options: Additional options
    - `:start_date` - Start date (ISO8601 format)
    - `:end_date` - End date (ISO8601 format)
    - `:save_path` - Directory to save data (default: data directory for the instrument/timeframe)
    - `:format` - Data format ("csv" or "binary", default: "csv")
    - `:broker_type` - Broker type for format standardization
  
  ## Returns
  
  - `{:ok, filepath}` - Path to the downloaded data file
  - `{:error, reason}` - If the download fails
  """
  def download_historical_data(broker_module, broker_state, instrument, timeframe, options \\ %{}) do
    # Extract options
    start_date = Map.get(options, :start_date, one_year_ago())
    end_date = Map.get(options, :end_date, DateTime.utc_now() |> DateTime.to_iso8601())
    broker_type = Map.get(options, :broker_type, :unknown)
    format = Map.get(options, :format, "csv")
    
    # Standardize instrument format (replace / with _)
    instrument_normalized = String.replace(instrument, "/", "_")
    
    # Determine save path
    save_path = case Map.get(options, :save_path) do
      nil ->
        market_type = if String.contains?(instrument, "USD") || String.contains?(instrument, "EUR") ||
                         String.contains?(instrument, "GBP") || String.contains?(instrument, "JPY") do
          "forex"
        else
          "crypto"
        end
        
        broker_name = broker_module_to_name(broker_module)
        Path.join(["/home/user/Desktop/bardo/priv/market_data", market_type, broker_name, instrument_normalized, timeframe])
        
      path -> path
    end
    
    # Ensure save path exists
    File.mkdir_p!(save_path)
    
    # Format dates for filename
    from_date = parse_date_for_filename(start_date)
    to_date = parse_date_for_filename(end_date)
    
    # Generate filename
    filename = "#{instrument_normalized}_#{timeframe}_#{from_date}_#{to_date}.#{format}"
    filepath = Path.join(save_path, filename)
    
    # Download data using the broker module
    Logger.info("Downloading #{instrument} #{timeframe} data from #{from_date} to #{to_date}")
    
    # Get data from broker
    case apply(broker_module, :get_historical_data, [broker_state, instrument, timeframe, %{
      from: start_date,
      to: end_date
    }]) do
      {:ok, data} ->
        # Standardize data format
        candles = data.candles
                  |> BrokerInterface.standardize_price_data(broker_type)
        
        # Save data based on format
        save_result = case format do
          "csv" -> save_to_csv(candles, filepath)
          "binary" -> save_to_binary(candles, filepath)
          _ -> {:error, "Unsupported format: #{format}"}
        end
        
        case save_result do
          :ok ->
            # Create metadata file
            metadata_path = Path.join(save_path, "metadata.json")
            metadata = %{
              pair: instrument,
              timeframe: timeframe,
              data_source: broker_module_to_name(broker_module),
              start_date: start_date,
              end_date: end_date,
              total_records: length(candles),
              last_updated: DateTime.utc_now() |> DateTime.to_iso8601()
            }
            
            File.write!(metadata_path, Jason.encode!(metadata, pretty: true))
            
            {:ok, filepath}
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Load historical data from a file.
  
  ## Parameters
  
  - file_path: Path to the data file
  - format: Data format ("csv" or "binary", default: determined from file extension)
  
  ## Returns
  
  - `{:ok, candles}` - List of candle data
  - `{:error, reason}` - If loading fails
  """
  def load_historical_data(file_path, format \\ nil) do
    # Determine format from file extension if not provided
    format = case format do
      nil -> Path.extname(file_path) |> String.replace(".", "")
      fmt -> fmt
    end
    
    # Load data based on format
    case format do
      "csv" -> load_from_csv(file_path)
      "binary" -> load_from_binary(file_path)
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end
  
  @doc """
  Merge multiple data files into a single file.
  
  ## Parameters
  
  - file_paths: List of paths to the data files
  - output_path: Path for the merged output file
  - options: Additional options
    - `:format` - Output format ("csv" or "binary", default: "csv")
    - `:sort` - Sort data by time (default: true)
    - `:remove_duplicates` - Remove duplicate entries (default: true)
  
  ## Returns
  
  - `{:ok, output_path}` - Path to the merged file
  - `{:error, reason}` - If merging fails
  """
  def merge_data_files(file_paths, output_path, options \\ %{}) do
    # Extract options
    format = Map.get(options, :format, "csv")
    sort = Map.get(options, :sort, true)
    remove_duplicates = Map.get(options, :remove_duplicates, true)
    
    # Ensure output directory exists
    output_dir = Path.dirname(output_path)
    File.mkdir_p!(output_dir)
    
    # Load all data files
    data_results = Enum.map(file_paths, &load_historical_data/1)
    
    # Check if all files loaded successfully
    if Enum.all?(data_results, fn {status, _} -> status == :ok end) do
      # Extract candles from results
      all_candles = Enum.flat_map(data_results, fn {:ok, candles} -> candles end)
      
      # Process candles
      processed_candles = if remove_duplicates do
        sorted_candles = if sort, do: sort_candles_by_time(all_candles), else: all_candles
        remove_duplicate_candles(sorted_candles)
      else
        if sort, do: sort_candles_by_time(all_candles), else: all_candles
      end
      
      # Save processed data
      save_result = case format do
        "csv" -> save_to_csv(processed_candles, output_path)
        "binary" -> save_to_binary(processed_candles, output_path)
        _ -> {:error, "Unsupported format: #{format}"}
      end
      
      case save_result do
        :ok -> {:ok, output_path}
        {:error, reason} -> {:error, reason}
      end
    else
      # Find first error
      {_, error} = Enum.find(data_results, fn {status, _} -> status == :error end)
      {:error, "Failed to load one or more data files: #{error}"}
    end
  end
  
  @doc """
  Resample data to a different timeframe.
  
  ## Parameters
  
  - candles: List of candle data
  - source_timeframe: Source timeframe (e.g., "M15")
  - target_timeframe: Target timeframe (e.g., "H1")
  
  ## Returns
  
  - `{:ok, resampled_candles}` - Resampled candle data
  - `{:error, reason}` - If resampling fails
  """
  def resample_data(candles, source_timeframe, target_timeframe) do
    # Convert timeframes to minutes
    source_minutes = timeframe_to_minutes(source_timeframe)
    target_minutes = timeframe_to_minutes(target_timeframe)
    
    # Validate timeframes
    if source_minutes == 0 or target_minutes == 0 do
      {:error, "Invalid timeframe format"}
    else
      # Check if target timeframe is a multiple of source timeframe
      if rem(target_minutes, source_minutes) != 0 do
        {:error, "Target timeframe must be a multiple of source timeframe"}
      else
        # Calculate how many source candles per target candle
        candles_per_group = div(target_minutes, source_minutes)
        
        # Sort candles by time
        sorted_candles = sort_candles_by_time(candles)
        
        # Group candles by target timeframe
        grouped_candles = Enum.chunk_every(sorted_candles, candles_per_group)
        
        # Create resampled candles from each group
        resampled_candles = Enum.map(grouped_candles, &aggregate_candles/1)
        
        {:ok, resampled_candles}
      end
    end
  end
  
  # Private helper functions
  
  # Save candles to CSV format
  defp save_to_csv(candles, file_path) do
    try do
      # Open file for writing
      file = File.open!(file_path, [:write, :utf8])
      
      # Write header
      IO.write(file, "timestamp,open,high,low,close,volume,complete\n")
      
      # Write each candle
      Enum.each(candles, fn candle ->
        complete = Map.get(candle, :complete, true)
        complete_str = if is_boolean(complete), do: to_string(complete), else: complete
        
        line = [
          candle.time,
          candle.open,
          candle.high,
          candle.low,
          candle.close,
          candle.volume,
          complete_str
        ] |> Enum.join(",")
        
        IO.write(file, "#{line}\n")
      end)
      
      # Close file
      File.close(file)
      :ok
    rescue
      e -> {:error, "Failed to save CSV file: #{inspect(e)}"}
    end
  end
  
  # Save candles to binary format
  defp save_to_binary(candles, file_path) do
    try do
      # Convert candles to binary format
      binary_data = :erlang.term_to_binary(candles)
      
      # Write to file
      File.write!(file_path, binary_data)
      :ok
    rescue
      e -> {:error, "Failed to save binary file: #{inspect(e)}"}
    end
  end
  
  # Load candles from CSV format
  defp load_from_csv(file_path) do
    try do
      # Read file content
      content = File.read!(file_path)
      
      # Split into lines and skip header
      [_header | lines] = String.split(content, "\n", trim: true)
      
      # Parse each line into a candle
      candles = Enum.map(lines, fn line ->
        [time, open, high, low, close, volume, complete] = String.split(line, ",", trim: true)
        
        %{
          time: time,
          open: parse_float(open),
          high: parse_float(high),
          low: parse_float(low),
          close: parse_float(close),
          volume: parse_integer(volume),
          complete: parse_boolean(complete)
        }
      end)
      
      {:ok, candles}
    rescue
      e -> {:error, "Failed to load CSV file: #{inspect(e)}"}
    end
  end
  
  # Load candles from binary format
  defp load_from_binary(file_path) do
    try do
      # Read binary data
      binary_data = File.read!(file_path)
      
      # Convert from binary format
      candles = :erlang.binary_to_term(binary_data)
      
      {:ok, candles}
    rescue
      e -> {:error, "Failed to load binary file: #{inspect(e)}"}
    end
  end
  
  # Remove duplicate candles based on timestamp
  defp remove_duplicate_candles(candles) do
    # Create map with time as key to eliminate duplicates
    candles
    |> Enum.reduce(%{}, fn candle, acc ->
      Map.put(acc, candle.time, candle)
    end)
    |> Map.values()
  end
  
  # Sort candles by timestamp
  defp sort_candles_by_time(candles) do
    Enum.sort_by(candles, fn candle ->
      parse_timestamp(candle.time)
    end)
  end
  
  # Aggregate multiple candles into a single candle
  defp aggregate_candles(candles) when length(candles) > 0 do
    first_candle = List.first(candles)
    last_candle = List.last(candles)
    
    # Extract high, low, and volume from all candles
    {high, low, volume} = Enum.reduce(candles, {first_candle.high, first_candle.low, 0}, fn candle, {h, l, v} ->
      {
        max(h, candle.high),
        min(l, candle.low),
        v + candle.volume
      }
    end)
    
    # Create aggregated candle
    %{
      time: first_candle.time,
      open: first_candle.open,
      high: high,
      low: low,
      close: last_candle.close,
      volume: volume,
      complete: Map.get(last_candle, :complete, true)
    }
  end
  
  # Handle empty candle list
  defp aggregate_candles([]), do: nil
  
  # Convert timeframe string to minutes
  defp timeframe_to_minutes(timeframe) do
    case timeframe do
      "M" <> minutes -> String.to_integer(minutes)
      "S" <> seconds -> div(String.to_integer(seconds), 60)
      "H" <> hours -> String.to_integer(hours) * 60
      "D" <> days -> String.to_integer(days) * 24 * 60
      "D" -> 24 * 60  # Daily
      "W" -> 7 * 24 * 60  # Weekly
      "M" -> 30 * 24 * 60  # Monthly (approximation)
      _ -> 0  # Invalid format
    end
  end
  
  # Parse a float with error handling
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(_), do: 0.0
  
  # Parse an integer with error handling
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_float(value), do: trunc(value)
  defp parse_integer(_), do: 0
  
  # Parse a boolean with error handling
  defp parse_boolean("true"), do: true
  defp parse_boolean("false"), do: false
  defp parse_boolean(true), do: true
  defp parse_boolean(false), do: false
  defp parse_boolean(_), do: true  # Default to true
  
  # Parse a timestamp to a sortable format
  defp parse_timestamp(timestamp) do
    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _} -> dt
      _ ->
        # Try alternate formats
        case Regex.run(~r/(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})/, timestamp) do
          [_, year, month, day, hour, minute, second] ->
            date = Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))
            time = Time.new!(String.to_integer(hour), String.to_integer(minute), String.to_integer(second))
            {:ok, dt} = DateTime.new(date, time, "Etc/UTC")
            dt
          _ -> 
            case Regex.run(~r/(\d{4})(\d{2})(\d{2})/, timestamp) do
              [_, year, month, day] ->
                date = Date.new!(String.to_integer(year), String.to_integer(month), String.to_integer(day))
                time = Time.new!(0, 0, 0)
                {:ok, dt} = DateTime.new(date, time, "Etc/UTC")
                dt
              _ -> DateTime.utc_now()  # Default
            end
        end
    end
  end
  
  # Parse a date string for filename
  defp parse_date_for_filename(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, dt, _} -> DateTime.to_date(dt) |> Date.to_string() |> String.replace("-", "")
      _ -> 
        # Try to extract date part from other formats
        case Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, date_str) do
          [_, year, month, day] -> "#{year}#{month}#{day}"
          _ -> "00000000"  # Default
        end
    end
  end
  
  # Get a date one year ago in ISO format
  defp one_year_ago do
    DateTime.utc_now()
    |> DateTime.add(-365 * 24 * 60 * 60, :second)
    |> DateTime.to_iso8601()
  end
  
  # Convert broker module to name for paths
  defp broker_module_to_name(module) do
    module_str = to_string(module)
    
    cond do
      String.contains?(module_str, "Oanda") -> "oanda"
      String.contains?(module_str, "Gemini") -> "gemini"
      String.contains?(module_str, "MetaTrader") -> "metatrader"
      true -> "other"
    end
  end
end