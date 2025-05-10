defmodule Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda do
  @moduledoc """
  OANDA API integration for algorithmic trading.
  
  This module provides functions to interact with OANDA's REST API for:
  - Retrieving historical forex data
  - Placing and managing trades
  - Accessing account information
  - Streaming price updates
  
  API documentation: https://developer.oanda.com/rest-live-v20/introduction/
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  
  @behaviour BrokerInterface
  
  # OANDA API base URLs
  @api_practice "https://api-fxpractice.oanda.com"
  @api_live "https://api-fxtrade.oanda.com"
  @streaming_practice "https://stream-fxpractice.oanda.com"
  @streaming_live "https://stream-fxtrade.oanda.com"
  
  # Default HTTP headers
  @default_headers [
    {"Content-Type", "application/json"},
    {"Connection", "keep-alive"},
    {"Accept", "application/json"}
  ]
  
  # Default HTTP options
  @default_opts [
    timeout: 30_000,        # 30-second timeout
    recv_timeout: 30_000,   # 30-second receive timeout
    follow_redirect: true
  ]
  
  # Default timeframes in OANDA format
  @timeframes %{
    "M1" => "S60",    # 1 minute = 60 seconds
    "M5" => "S300",   # 5 minutes = 300 seconds
    "M15" => "M15",   # 15 minutes
    "M30" => "M30",   # 30 minutes
    "H1" => "H1",     # 1 hour
    "H4" => "H4",     # 4 hours
    "D1" => "D"       # 1 day
  }
  
  @doc """
  Initialize the OANDA broker interface with API credentials.
  
  ## Parameters
  
  - opts: A map containing the following options
    - `:api_key` - OANDA API key/token
    - `:account_id` - OANDA account ID
    - `:live` - Boolean whether to use live or practice API (default: false)
    - `:timeout` - Request timeout in milliseconds (default: 30000)
    - `:base_currency` - Base currency for the account (default: "USD")
  
  ## Returns
  
  - `{:ok, state}` - If initialization is successful
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def init(opts) do
    # Extract required options
    api_key = Map.get(opts, :api_key)
    account_id = Map.get(opts, :account_id)
    live = Map.get(opts, :live, false)
    
    if !api_key || !account_id do
      {:error, "API key and account ID are required"}
    else
      # Set up the state with API configuration
      state = %{
        api_key: api_key,
        account_id: account_id,
        live: live,
        base_url: if(live, do: @api_live, else: @api_practice),
        streaming_url: if(live, do: @streaming_live, else: @streaming_practice),
        headers: [{"Authorization", "Bearer #{api_key}"} | @default_headers],
        opts: Map.get(opts, :timeout, nil) |> maybe_override_timeout(@default_opts),
        base_currency: Map.get(opts, :base_currency, "USD")
      }
      
      # Test connection
      case get_account_info(state) do
        {:ok, _} -> {:ok, state}
        {:error, reason} -> {:error, reason}
      end
    end
  end
  
  @doc """
  Get account information from OANDA.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, account_info}` - Account information map
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_account_info(state) do
    url = "#{state.base_url}/v3/accounts/#{state.account_id}"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = decode_response_body(body)
        {:ok, decoded_body}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error getting account info: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error getting account info: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get a list of available instruments from OANDA.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, instruments}` - List of available instruments
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_instruments(state) do
    url = "#{state.base_url}/v3/accounts/#{state.account_id}/instruments"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = decode_response_body(body)

        {:ok,
          decoded_body
          |> Map.get("instruments", [])
          |> Enum.map(fn instrument ->
            %{
              name: Map.get(instrument, "name"),
              type: Map.get(instrument, "type"),
              display_name: Map.get(instrument, "displayName"),
              pip_location: Map.get(instrument, "pipLocation"),
              margin_rate: Map.get(instrument, "marginRate")
            }
          end)
        }
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error getting instruments: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error getting instruments: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get historical price data for an instrument.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code (e.g., "EUR_USD")
  - timeframe: The timeframe (e.g., "M15" for 15-minute candles)
  - opts: Additional options
    - `:count` - Number of candles to retrieve (default: 500)
    - `:from` - Start datetime (ISO8601 format)
    - `:to` - End datetime (ISO8601 format)
    - `:include_first` - Whether to include the candle at the from time (default: true)
  
  ## Returns
  
  - `{:ok, candles}` - List of candle data
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_historical_data(state, instrument, timeframe, opts \\ %{}) do
    # Format instrument code for OANDA (replace / with _)
    oanda_instrument = String.replace(instrument, "/", "_")
    
    # Map timeframe to OANDA format
    oanda_granularity = Map.get(@timeframes, timeframe, timeframe)
    
    # Build query parameters
    params = %{
      "granularity" => oanda_granularity,
      "price" => "M",  # Midpoint candles
    }
    
    # Add optional parameters
    params = if Map.has_key?(opts, :count) do
      Map.put(params, "count", opts.count)
    else
      params
    end
    
    params = if Map.has_key?(opts, :from) do
      Map.put(params, "from", opts.from)
    else
      params
    end
    
    params = if Map.has_key?(opts, :to) do
      Map.put(params, "to", opts.to)
    else
      params
    end
    
    params = if Map.has_key?(opts, :include_first) do
      Map.put(params, "includeFirst", opts.include_first)
    else
      params
    end
    
    # Build the URL with query parameters
    query_string = URI.encode_query(params)
    url = "#{state.base_url}/v3/instruments/#{oanda_instrument}/candles?#{query_string}"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = decode_response_body(body)

        candles = Enum.map(decoded_body["candles"], fn candle ->
          %{
            time: candle["time"],
            open: get_float(candle["mid"], "o"),
            high: get_float(candle["mid"], "h"),
            low: get_float(candle["mid"], "l"),
            close: get_float(candle["mid"], "c"),
            volume: candle["volume"],
            complete: candle["complete"]
          }
        end)

        {:ok, %{
          instrument: decoded_body["instrument"],
          granularity: decoded_body["granularity"],
          candles: candles
        }}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error getting historical data: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error getting historical data: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Download all available historical data for an instrument and timeframe.
  
  This function will fetch all available historical data in chunks and save it to the specified directory.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code (e.g., "EUR_USD")
  - timeframe: The timeframe (e.g., "M15" for 15-minute candles)
  - save_path: Directory path to save the data
  - opts: Additional options
    - `:from` - Start datetime (ISO8601 format, default: 1 year ago)
    - `:to` - End datetime (ISO8601 format, default: now)
    - `:chunk_size` - Number of candles per request (default: 1000)
  
  ## Returns
  
  - `{:ok, filename}` - Path to the saved file
  - `{:error, reason}` - If there's an error
  """
  def download_historical_data(state, instrument, timeframe, save_path, opts \\ %{}) do
    # Format instrument for filename
    instrument_formatted = String.replace(instrument, "/", "")
    
    # Default to 1 year of data if not specified
    now = DateTime.utc_now()
    one_year_ago = DateTime.add(now, -365 * 24 * 60 * 60, :second)
    
    from = Map.get(opts, :from, DateTime.to_iso8601(one_year_ago))
    to = Map.get(opts, :to, DateTime.to_iso8601(now))
    chunk_size = Map.get(opts, :chunk_size, 1000)
    
    # Create destination directory if it doesn't exist
    File.mkdir_p!(save_path)
    
    # Formatting dates for filename
    from_date = case DateTime.from_iso8601(from) do
      {:ok, dt, _} -> DateTime.to_date(dt) |> Date.to_string() |> String.replace("-", "")
      _ -> "00000000"
    end
    
    to_date = case DateTime.from_iso8601(to) do
      {:ok, dt, _} -> DateTime.to_date(dt) |> Date.to_string() |> String.replace("-", "")
      _ -> "99999999"
    end
    
    # Generate filename
    filename = "#{instrument_formatted}_#{timeframe}_#{from_date}_#{to_date}.csv"
    filepath = Path.join(save_path, filename)
    
    # Download data in chunks
    Logger.info("[OANDA] Downloading historical data for #{instrument} (#{timeframe})")
    
    download_result = download_data_chunks(state, instrument, timeframe, from, to, chunk_size)
    
    case download_result do
      {:ok, candles} ->
        # Save to CSV
        Logger.info("[OANDA] Saving #{length(candles)} candles to #{filepath}")
        
        # Write CSV header and data
        file = File.open!(filepath, [:write, :utf8])
        IO.write(file, "timestamp,open,high,low,close,volume,complete\n")
        
        Enum.each(candles, fn candle ->
          IO.write(file, "#{candle.time},#{candle.open},#{candle.high},#{candle.low},#{candle.close},#{candle.volume},#{candle.complete}\n")
        end)
        
        File.close(file)
        
        # Create metadata file
        metadata_path = Path.join(save_path, "metadata.json")
        metadata = %{
          pair: instrument,
          timeframe: timeframe,
          data_source: "OANDA",
          start_date: from,
          end_date: to,
          total_records: length(candles),
          last_updated: DateTime.to_iso8601(DateTime.utc_now())
        }
        
        File.write!(metadata_path, Jason.encode!(metadata, pretty: true))
        
        {:ok, filepath}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get current price quotes for instruments.
  
  ## Parameters
  
  - state: The broker state map
  - instruments: List of instrument codes
  
  ## Returns
  
  - `{:ok, quotes}` - Map of instrument quotes
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_quotes(state, instruments) when is_list(instruments) do
    # Format instrument codes for OANDA
    oanda_instruments = Enum.map(instruments, &String.replace(&1, "/", "_"))
    instruments_param = Enum.join(oanda_instruments, "%2C")
    
    url = "#{state.base_url}/v3/accounts/#{state.account_id}/pricing?instruments=#{instruments_param}"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = decode_response_body(body)

        prices = Enum.reduce(decoded_body["prices"], %{}, fn price, acc ->
          instrument = price["instrument"]

          quote_data = %{
            instrument: instrument,
            time: price["time"],
            bid: get_float(price, "closeoutBid"),
            ask: get_float(price, "closeoutAsk"),
            spread: get_float(price, "closeoutAsk") - get_float(price, "closeoutBid"),
            status: price["status"]
          }

          Map.put(acc, instrument, quote_data)
        end)

        {:ok, prices}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error getting quotes: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error getting quotes: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @impl BrokerInterface
  def get_quotes(state, instrument) when is_binary(instrument) do
    get_quotes(state, [instrument])
  end
  
  @doc """
  Execute a trade order on OANDA.
  
  ## Parameters
  
  - state: The broker state map
  - order: A map containing order details:
    - `:instrument` - Instrument code
    - `:units` - Number of units (positive for buy, negative for sell)
    - `:type` - Order type ("MARKET", "LIMIT", "STOP", etc.)
    - `:price` - Price for LIMIT or STOP orders
    - `:stop_loss` - Optional stop loss price
    - `:take_profit` - Optional take profit price
    - `:time_in_force` - Optional time in force ("GTC", "GTD", "FOK", "IOC")
    
  ## Returns
  
  - `{:ok, order_details}` - Details of the executed order
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def execute_order(state, order) do
    url = "#{state.base_url}/v3/accounts/#{state.account_id}/orders"
    
    # Format instrument for OANDA
    instrument = String.replace(order.instrument, "/", "_")
    
    # Build the order payload
    payload = %{
      "order" => %{
        "instrument" => instrument,
        "units" => order.units,
        "type" => order.type
      }
    }
    
    # Add optional parameters
    payload = case order.type do
      "MARKET" ->
        payload
        
      "LIMIT" ->
        put_in(payload, ["order", "price"], to_string(order.price))
        
      "STOP" ->
        put_in(payload, ["order", "price"], to_string(order.price))
        
      _ ->
        payload
    end
    
    # Add stop loss if provided
    payload = if Map.has_key?(order, :stop_loss) do
      put_in(payload, ["order", "stopLossOnFill"], %{
        "price" => to_string(order.stop_loss)
      })
    else
      payload
    end
    
    # Add take profit if provided
    payload = if Map.has_key?(order, :take_profit) do
      put_in(payload, ["order", "takeProfitOnFill"], %{
        "price" => to_string(order.take_profit)
      })
    else
      payload
    end
    
    # Add time in force if provided
    payload = if Map.has_key?(order, :time_in_force) do
      put_in(payload, ["order", "timeInForce"], order.time_in_force)
    else
      put_in(payload, ["order", "timeInForce"], "GTC")  # Default to Good Till Cancelled
    end
    
    case HTTPoison.post(url, Jason.encode!(payload), state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} when status_code in 200..201 ->
        decoded_body = decode_response_body(body)
        {:ok, decoded_body}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error executing order: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error executing order: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get open positions for the account.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, positions}` - List of open positions
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_positions(state) do
    url = "#{state.base_url}/v3/accounts/#{state.account_id}/openPositions"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        decoded_body = decode_response_body(body)

        positions = Enum.map(decoded_body["positions"], fn position ->
          %{
            instrument: position["instrument"],
            long_units: Map.get(position["long"], "units", "0") |> String.to_integer(),
            long_avg_price: get_float(position["long"], "averagePrice"),
            short_units: Map.get(position["short"], "units", "0") |> String.to_integer(),
            short_avg_price: get_float(position["short"], "averagePrice"),
            pl: get_float(position, "pl"),
            unrealized_pl: get_float(position, "unrealizedPL")
          }
        end)

        {:ok, positions}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error getting positions: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error getting positions: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Close a position for a specific instrument.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code
  - opts: Additional options
    - `:longUnits` - Number of long units to close (default: "ALL")
    - `:shortUnits` - Number of short units to close (default: "ALL")
  
  ## Returns
  
  - `{:ok, result}` - Result of the position close operation
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def close_position(state, instrument, opts \\ %{}) do
    # Format instrument for OANDA
    oanda_instrument = String.replace(instrument, "/", "_")
    
    url = "#{state.base_url}/v3/accounts/#{state.account_id}/positions/#{oanda_instrument}/close"
    
    # Build the payload
    payload = %{}
    
    # Add units to close if provided
    payload = if Map.has_key?(opts, :longUnits) do
      Map.put(payload, "longUnits", opts.longUnits)
    else
      Map.put(payload, "longUnits", "ALL")
    end
    
    payload = if Map.has_key?(opts, :shortUnits) do
      Map.put(payload, "shortUnits", opts.shortUnits)
    else
      Map.put(payload, "shortUnits", "ALL")
    end
    
    case HTTPoison.put(url, Jason.encode!(payload), state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} when status_code in 200..201 ->
        decoded_body = decode_response_body(body)
        {:ok, decoded_body}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[OANDA] Error closing position: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[OANDA] Error closing position: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  # Private helper functions

  # Helper function to decode gzipped JSON responses
  defp decode_response_body(body) do
    case body do
      <<31, 139, _::binary>> -> # gzip magic bytes
        :zlib.gunzip(body) |> Jason.decode!()
      _ ->
        Jason.decode!(body)
    end
  end

  # Download data in chunks
  defp download_data_chunks(state, instrument, timeframe, from, to, chunk_size) do
    Logger.info("[OANDA] Starting chunk download from #{from} to #{to}")
    
    # Maximum number of chunks to download as a safety measure
    max_requests = 100
    
    # Download data with recursion limit
    download_with_limit(state, instrument, timeframe, from, to, chunk_size, [], 0, max_requests)
  end
  
  # Helper function to download data with request limit
  defp download_with_limit(state, instrument, timeframe, from, to, chunk_size, acc, request_count, max_requests) do
    # Safety check: Stop if we exceed max requests
    if request_count >= max_requests do
      Logger.warn("[OANDA] Maximum request limit (#{max_requests}) reached, stopping download")
      {:ok, List.flatten(acc)}
    else
      # Safety check: Stop if from >= to
      if from >= to do
        Logger.info("[OANDA] End date reached, download complete")
        {:ok, List.flatten(acc)}
      else
        # Get a chunk of data
        Logger.info("[OANDA] Downloading chunk #{request_count + 1}/#{max_requests} from #{from}")
        
        case get_historical_data(state, instrument, timeframe, %{
          from: from,
          count: chunk_size
        }) do
          {:ok, %{candles: []}} ->
            # No more candles available
            Logger.info("[OANDA] No more candles available, download complete")
            {:ok, List.flatten(acc)}
            
          {:ok, %{candles: candles}} ->
            # Get the time of the last candle for next batch
            last_candle = List.last(candles)
            
            # Log progress
            Logger.info("[OANDA] Downloaded chunk with #{length(candles)} candles, next from: #{last_candle.time}")
            
            # Detect when we're getting the same data repeatedly
            is_repeating = if length(candles) == 1 && length(acc) > 0 do
              # Check if this single candle matches the last candle from previous request
              prev_candles = hd(acc)
              prev_last = List.last(prev_candles)
              prev_last.time == last_candle.time
            else
              false
            end
            
            if is_repeating do
              Logger.info("[OANDA] Detected repeating data point, download complete")
              {:ok, List.flatten(acc)}
            else
              # Calculate new from time (add 1 second to avoid duplicates)
              next_from = case DateTime.from_iso8601(last_candle.time) do
                {:ok, dt, _} ->
                  dt
                  |> DateTime.add(1, :second)
                  |> DateTime.to_iso8601()
                _ ->
                  # If we can't parse the time, we're done
                  to
              end
              
              # Continue downloading
              download_with_limit(
                state, 
                instrument, 
                timeframe, 
                next_from, 
                to, 
                chunk_size, 
                [candles | acc],
                request_count + 1,
                max_requests
              )
            end
            
          {:error, reason} ->
            Logger.error("[OANDA] Error downloading chunk: #{inspect(reason)}")
            {:error, reason}
        end
      end
    end
  end
  
  # Helper to get a float value from a map with a default
  defp get_float(map, key, default \\ 0.0) when is_map(map) do
    case Map.get(map, key) do
      nil -> default
      value when is_binary(value) ->
        case Float.parse(value) do
          {float, _} -> float
          :error -> default
        end
      value when is_float(value) -> value
      value when is_integer(value) -> value * 1.0
      _ -> default
    end
  end
  
  # Helper to override timeout in options if provided
  defp maybe_override_timeout(nil, opts), do: opts
  defp maybe_override_timeout(timeout, opts) when is_integer(timeout) do
    opts
    |> Keyword.put(:timeout, timeout)
    |> Keyword.put(:recv_timeout, timeout)
  end
end