defmodule Bardo.Examples.Applications.AlgoTrading.DataDownloader do
  @moduledoc """
  Specialized module for downloading and managing historical market data.
  
  This module provides enhanced functionality for:
  - Downloading historical data from different brokers
  - Managing data storage with proper directory organization
  - Merging and preprocessing data files
  - Handling data format consistency across brokers
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.DataUtils
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini
  
  # Root directory for market data
  @market_data_dir "/home/user/Desktop/bardo/priv/market_data"
  
  # Default dates
  @default_timeframe "M15"
  
  @doc """
  Download historical data for a specific instrument and timeframe.
  
  ## Parameters
  
  - broker_module: Module implementing the BrokerInterface
  - broker_state: State returned from broker initialization
  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  - options: Additional download options
    - `:timeframe` - Candle timeframe (default: "M15")
    - `:start_date` - Start date in ISO8601 format (default: 1 year ago)
    - `:end_date` - End date in ISO8601 format (default: now)
    - `:chunk_size` - Size of data chunks for large downloads (default: 1000)
    - `:output_dir` - Custom output directory (default: auto-determined)
  
  ## Returns
  
  - `{:ok, filepath}` - Path to the downloaded data file
  - `{:error, reason}` - If download fails
  """
  def download_data(broker_module, broker_state, instrument, options \\ %{}) do
    # Extract options with defaults
    timeframe = Map.get(options, :timeframe, @default_timeframe)
    
    # Determine default dates if not provided
    now = DateTime.utc_now()
    one_year_ago = DateTime.add(now, -365 * 24 * 60 * 60, :second)
    
    start_date = Map.get(options, :start_date, DateTime.to_iso8601(one_year_ago))
    end_date = Map.get(options, :end_date, DateTime.to_iso8601(now))
    
    # Determine broker type
    broker_type = determine_broker_type(broker_module)
    
    # Determine the save directory
    save_dir = case Map.get(options, :output_dir) do
      nil ->
        # Auto-determine based on instrument and broker
        market_type = determine_market_type(instrument)
        broker_name = broker_module_to_name(broker_module)
        
        # Replace any slashes in instrument name with underscores
        instrument_normalized = String.replace(instrument, "/", "_")
        
        Path.join([@market_data_dir, market_type, broker_name, instrument_normalized, timeframe])
        
      dir -> dir
    end
    
    # Ensure directory exists
    File.mkdir_p!(save_dir)
    
    # Format dates for filename
    from_date = format_date_for_filename(start_date)
    to_date = format_date_for_filename(end_date)
    
    # Generate output filename
    filename = "#{String.replace(instrument, "/", "_")}_#{timeframe}_#{from_date}_#{to_date}.csv"
    output_path = Path.join(save_dir, filename)
    
    # Log the download operation
    Logger.info("Downloading #{instrument} data (#{timeframe}) from #{from_date} to #{to_date}")
    
    # Check broker module for specific download methods
    cond do
      # Use OANDA's specialized download function if available
      broker_module == Oanda && function_exported?(Oanda, :download_historical_data, 5) ->
        Oanda.download_historical_data(
          broker_state,
          instrument,
          timeframe,
          save_dir,
          %{
            from: start_date,
            to: end_date,
            chunk_size: Map.get(options, :chunk_size, 1000)
          }
        )
        
      # For Gemini and other brokers, use the standard approach
      true ->
        case broker_module.get_historical_data(broker_state, instrument, timeframe, %{
          from: start_date,
          to: end_date
        }) do
          {:ok, data} ->
            # Standardize data format
            candles = data.candles
                      |> BrokerInterface.standardize_price_data(broker_type)
            
            # Save to CSV
            save_to_csv(candles, output_path)
            
            # Create metadata file
            metadata_path = Path.join(save_dir, "metadata.json")
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
            
            {:ok, output_path}
            
          {:error, reason} ->
            {:error, reason}
        end
    end
  end
  
  @doc """
  Download data for multiple currency pairs.
  
  ## Parameters
  
  - broker_module: Module implementing the BrokerInterface
  - broker_state: State returned from broker initialization
  - instruments: List of instrument codes
  - options: Additional download options
    - Same as `download_data/4`
  
  ## Returns
  
  - `{:ok, results}` - Map of instrument to result
  - `{:error, reason}` - If a critical error occurs
  """
  def download_multiple(broker_module, broker_state, instruments, options \\ %{}) do
    results = Enum.map(instruments, fn instrument ->
      result = download_data(broker_module, broker_state, instrument, options)
      {instrument, result}
    end)
    
    # Check if all downloads were successful
    if Enum.all?(results, fn {_, {status, _}} -> status == :ok end) do
      # Format results as a map
      result_map = Enum.reduce(results, %{}, fn {instrument, {:ok, path}}, acc ->
        Map.put(acc, instrument, path)
      end)
      
      {:ok, result_map}
    else
      # At least one download failed
      failed = Enum.filter(results, fn {_, {status, _}} -> status == :error end)
                |> Enum.map(fn {instrument, {_, reason}} -> "#{instrument}: #{reason}" end)
                |> Enum.join(", ")
      
      {:error, "Failed to download some instruments: #{failed}"}
    end
  end
  
  @doc """
  Merge multiple data files for the same instrument.
  
  ## Parameters
  
  - file_paths: List of file paths to merge
  - output_path: Path for the merged file
  - options: Additional options
    - `:sort` - Sort data by time (default: true)
    - `:remove_duplicates` - Remove duplicate entries (default: true)
  
  ## Returns
  
  - `{:ok, output_path}` - Path to the merged file
  - `{:error, reason}` - If merging fails
  """
  def merge_data_files(file_paths, output_path, options \\ %{}) do
    DataUtils.merge_data_files(file_paths, output_path, options)
  end
  
  @doc """
  List available data files for an instrument.
  
  ## Parameters
  
  - instrument: Instrument code
  - options: Additional options
    - `:broker` - Broker name (:oanda, :gemini, etc.)
    - `:timeframe` - Candle timeframe (default: "M15")
  
  ## Returns
  
  - `{:ok, files}` - List of data files
  - `{:error, reason}` - If listing fails
  """
  def list_data_files(instrument, options \\ %{}) do
    # Normalize instrument
    instrument_normalized = String.replace(instrument, "/", "_")
    
    # Get timeframe
    timeframe = Map.get(options, :timeframe, @default_timeframe)
    
    # Determine directories to search
    dirs = cond do
      # Specific broker
      broker = Map.get(options, :broker) ->
        broker_name = case broker do
          :oanda -> "oanda"
          :gemini -> "gemini"
          name when is_binary(name) -> name
          _ -> "other"
        end
        
        market_type = determine_market_type(instrument)
        [Path.join([@market_data_dir, market_type, broker_name, instrument_normalized, timeframe])]
        
      # All brokers
      true ->
        market_type = determine_market_type(instrument)
        
        # Find all broker directories
        broker_dirs = find_broker_dirs(market_type)
        
        # Create paths for each broker
        Enum.map(broker_dirs, fn broker ->
          Path.join([@market_data_dir, market_type, broker, instrument_normalized, timeframe])
        end)
    end
    
    # Collect files from all relevant directories
    files = Enum.flat_map(dirs, fn dir ->
      if File.exists?(dir) do
        Path.wildcard(Path.join(dir, "*.csv"))
      else
        []
      end
    end)
    
    # Format results
    formatted_files = Enum.map(files, fn file ->
      # Extract metadata about the file
      stats = File.stat!(file)
      
      # Try to parse filename for date range
      [_, _, from, to] = Path.basename(file, ".csv") |> String.split("_", parts: 4)
      
      %{
        path: file,
        filename: Path.basename(file),
        size: stats.size,
        from_date: from,
        to_date: to,
        last_modified: stats.mtime
      }
    end)
    
    # Sort by date (newest first)
    sorted_files = Enum.sort_by(formatted_files, fn file -> file.to_date end, :desc)
    
    {:ok, sorted_files}
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
  
  # Determine the type of broker from module
  defp determine_broker_type(broker_module) do
    cond do
      broker_module == Oanda -> :oanda
      broker_module == Gemini -> :gemini
      true -> :unknown
    end
  end
  
  # Determine the market type based on instrument
  defp determine_market_type(instrument) do
    # Check common forex pairs
    forex_pairs = ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"]
    
    if Enum.any?(forex_pairs, fn pair -> String.contains?(instrument, pair) end) do
      "forex"
    else
      # Assume crypto if not forex
      "crypto"
    end
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
  
  # Find broker directories for a market type
  defp find_broker_dirs(market_type) do
    market_dir = Path.join(@market_data_dir, market_type)
    
    if File.exists?(market_dir) do
      File.ls!(market_dir)
    else
      []
    end
  end
  
  # Format a date string for filename
  defp format_date_for_filename(date_str) do
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
end