defmodule Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini do
  @moduledoc """
  Gemini API integration for algorithmic cryptocurrency trading.
  
  This module provides functions to interact with Gemini's REST API for:
  - Retrieving historical cryptocurrency data
  - Placing and managing trades
  - Accessing account information
  - Streaming price updates
  
  API documentation: https://docs.gemini.com/rest-api/
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  
  @behaviour BrokerInterface
  
  # Gemini API base URLs
  @api_sandbox "https://api.sandbox.gemini.com"
  @api_live "https://api.gemini.com"
  
  # Default HTTP headers
  @default_headers [
    {"Content-Type", "application/json"},
    {"Accept", "application/json"},
    {"Cache-Control", "no-cache"}
  ]
  
  # Default HTTP options
  @default_opts [
    timeout: 30_000,        # 30-second timeout
    recv_timeout: 30_000,   # 30-second receive timeout
    follow_redirect: true
  ]
  
  # Default timeframes mapped to Gemini format
  @timeframes %{
    "M1" => "1m",    # 1 minute
    "M5" => "5m",    # 5 minutes
    "M15" => "15m",  # 15 minutes
    "M30" => "30m",  # 30 minutes
    "H1" => "1hr",   # 1 hour
    "H6" => "6hr",   # 6 hours
    "D1" => "1day"   # 1 day
  }
  
  @doc """
  Initialize the Gemini broker interface with API credentials.
  
  ## Parameters
  
  - opts: A map containing the following options
    - `:api_key` - Gemini API key
    - `:api_secret` - Gemini API secret
    - `:live` - Boolean whether to use live or sandbox API (default: false)
    - `:timeout` - Request timeout in milliseconds (default: 30000)
  
  ## Returns
  
  - `{:ok, state}` - If initialization is successful
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def init(opts) do
    # Extract required options
    api_key = Map.get(opts, :api_key)
    api_secret = Map.get(opts, :api_secret)
    live = Map.get(opts, :live, false)
    
    if !api_key || !api_secret do
      {:error, "API key and secret are required"}
    else
      # Set up the state with API configuration
      state = %{
        api_key: api_key,
        api_secret: api_secret,
        live: live,
        base_url: if(live, do: @api_live, else: @api_sandbox),
        headers: @default_headers,
        opts: Map.get(opts, :timeout, nil) |> maybe_override_timeout(@default_opts)
      }
      
      # Test connection by getting symbols
      case get_instruments(state) do
        {:ok, _} -> {:ok, state}
        {:error, reason} -> {:error, reason}
      end
    end
  end
  
  @doc """
  Get account information from Gemini.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, account_info}` - Account information map
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_account_info(state) do
    # Build request for authenticated endpoint
    payload = %{
      request: "/v1/account",
      nonce: generate_nonce()
    }
    
    # Make authorized request
    case make_authorized_request(state, "account", payload) do
      {:ok, body} ->
        {:ok, Jason.decode!(body)}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get a list of available instruments (symbols) from Gemini.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, instruments}` - List of available instruments
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_instruments(state) do
    url = "#{state.base_url}/v1/symbols"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        symbols = Jason.decode!(body)
        
        # Convert to standard format
        instruments = Enum.map(symbols, fn symbol ->
          %{
            name: symbol,
            display_name: symbol,
            type: "crypto"
          }
        end)
        
        {:ok, instruments}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[Gemini] Error getting instruments: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[Gemini] Error getting instruments: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get historical price data for a cryptocurrency pair.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The cryptocurrency pair symbol (e.g., "BTCUSD")
  - timeframe: The timeframe (e.g., "M15" for 15-minute candles)
  - opts: Additional options
    - `:limit` - Number of candles to retrieve (default: 500, max: 1000)
    - `:since` - Start timestamp in milliseconds
    - `:until` - End timestamp in milliseconds
  
  ## Returns
  
  - `{:ok, candles}` - List of candle data
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_historical_data(state, instrument, timeframe, opts \\ %{}) do
    # Format instrument code for Gemini (lowercase)
    gemini_instrument = String.downcase(String.replace(instrument, "/", ""))
    
    # Map timeframe to Gemini format
    gemini_timeframe = Map.get(@timeframes, timeframe, timeframe)
    
    # Build query parameters
    params = %{}
    
    # Add optional parameters
    params = if Map.has_key?(opts, :limit) do
      Map.put(params, "limit_trades", opts.limit)
    else
      params
    end
    
    params = if Map.has_key?(opts, :since) do
      Map.put(params, "timestamp", opts.since)
    else
      params
    end
    
    # Note: Gemini doesn't have a "to" parameter in its candles API
    
    # Build the URL
    query_string = if map_size(params) > 0 do
      "?" <> URI.encode_query(params)
    else
      ""
    end
    
    url = "#{state.base_url}/v2/candles/#{gemini_instrument}/#{gemini_timeframe}#{query_string}"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        candles_data = Jason.decode!(body)
        
        # Gemini returns candles as arrays: [timestamp, open, high, low, close, volume]
        candles = Enum.map(candles_data, fn [timestamp, open, high, low, close, volume] ->
          %{
            time: format_timestamp(timestamp),
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume,
            complete: true
          }
        end)
        
        {:ok, %{
          instrument: instrument,
          granularity: timeframe,
          candles: candles
        }}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[Gemini] Error getting historical data: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[Gemini] Error getting historical data: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get current price quotes for one or more cryptocurrency pairs.
  
  ## Parameters
  
  - state: The broker state map
  - instruments: List of instrument codes or a single instrument code
  
  ## Returns
  
  - `{:ok, quotes}` - Map of instrument quotes
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_quotes(state, instruments) when is_list(instruments) do
    # Get quotes for each instrument
    results = Enum.map(instruments, fn instrument ->
      {instrument, get_quotes(state, instrument)}
    end)
    
    # Check if all requests were successful
    if Enum.all?(results, fn {_, {status, _}} -> status == :ok end) do
      # Combine results into a map
      quotes = Enum.reduce(results, %{}, fn {instrument, {:ok, quote_data}}, acc ->
        Map.put(acc, instrument, quote_data)
      end)
      
      {:ok, quotes}
    else
      # Return first error
      {_, error} = Enum.find(results, fn {_, {status, _}} -> status == :error end)
      error
    end
  end
  
  @impl BrokerInterface
  def get_quotes(state, instrument) when is_binary(instrument) do
    # Format instrument code for Gemini (lowercase)
    gemini_instrument = String.downcase(String.replace(instrument, "/", ""))
    
    url = "#{state.base_url}/v1/pubticker/#{gemini_instrument}"
    
    case HTTPoison.get(url, state.headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        response = Jason.decode!(body)
        
        # Convert Gemini's format to our standard format
        quote_data = %{
          instrument: instrument,
          time: response["volume"]["timestamp"] |> format_timestamp(),
          bid: response["bid"] |> parse_float(),
          ask: response["ask"] |> parse_float(),
          spread: (response["ask"] |> parse_float()) - (response["bid"] |> parse_float()),
          status: "tradeable"
        }
        
        {:ok, quote_data}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[Gemini] Error getting quotes: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[Gemini] Error getting quotes: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Execute a trade order on Gemini.
  
  ## Parameters
  
  - state: The broker state map
  - order: A map containing order details:
    - `:instrument` - Instrument code
    - `:side` - Order side ("buy" or "sell")
    - `:amount` - Amount to buy or sell
    - `:price` - Price for limit orders
    - `:type` - Order type ("exchange limit", "exchange market", etc.)
    - `:options` - Array of order execution options (optional)
  
  ## Returns
  
  - `{:ok, order_details}` - Details of the executed order
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def execute_order(state, order) do
    # Format instrument code for Gemini (lowercase)
    symbol = String.downcase(String.replace(order.instrument, "/", ""))
    
    # Build payload for order
    payload = %{
      request: "/v1/order/new",
      nonce: generate_nonce(),
      symbol: symbol,
      amount: to_string(order.amount),
      side: order.side,
      type: Map.get(order, :type, "exchange limit")
    }
    
    # Add price for limit orders
    payload = if Map.get(order, :type, "") == "exchange limit" do
      Map.put(payload, :price, to_string(order.price))
    else
      payload
    end
    
    # Add options if provided
    payload = if Map.has_key?(order, :options) and is_list(order.options) do
      Map.put(payload, :options, order.options)
    else
      payload
    end
    
    # Make authorized request
    case make_authorized_request(state, "order/new", payload) do
      {:ok, body} ->
        {:ok, Jason.decode!(body)}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get open positions (active orders) for the account.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, positions}` - List of open positions
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def get_positions(state) do
    # Build request for authenticated endpoint
    payload = %{
      request: "/v1/orders",
      nonce: generate_nonce()
    }
    
    # Make authorized request
    case make_authorized_request(state, "orders", payload) do
      {:ok, body} ->
        orders = Jason.decode!(body)
        
        # Convert to standard format
        positions = Enum.map(orders, fn order ->
          %{
            instrument: order["symbol"],
            id: order["order_id"],
            side: order["side"],
            amount: order["original_amount"] |> parse_float(),
            remaining: order["remaining_amount"] |> parse_float(),
            price: order["price"] |> parse_float(),
            type: order["type"],
            status: order["is_live"],
            timestamp: order["timestampms"] |> format_timestamp()
          }
        end)
        
        {:ok, positions}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Close a position (cancel an order) for a specific instrument.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code (unused, as Gemini requires order ID)
  - opts: Additional options
    - `:order_id` - The ID of the order to cancel (required)
  
  ## Returns
  
  - `{:ok, result}` - Result of the position close operation
  - `{:error, reason}` - If there's an error
  """
  @impl BrokerInterface
  def close_position(state, _instrument, opts \\ %{}) do
    # Gemini requires order ID to cancel
    order_id = Map.get(opts, :order_id)
    
    if is_nil(order_id) do
      {:error, "Order ID is required to cancel an order"}
    else
      # Build request for authenticated endpoint
      payload = %{
        request: "/v1/order/cancel",
        nonce: generate_nonce(),
        order_id: order_id
      }
      
      # Make authorized request
      case make_authorized_request(state, "order/cancel", payload) do
        {:ok, body} ->
          {:ok, Jason.decode!(body)}
          
        {:error, reason} ->
          {:error, reason}
      end
    end
  end
  
  # Private helper functions
  
  # Generate a nonce for authenticated requests
  defp generate_nonce do
    :os.system_time(:millisecond)
  end
  
  # Make an authorized request to Gemini API
  defp make_authorized_request(state, endpoint, payload) do
    url = "#{state.base_url}/v1/#{endpoint}"
    
    # Encode payload as JSON
    payload_json = Jason.encode!(payload)
    payload_base64 = Base.encode64(payload_json)
    
    # Create signature
    signature = :crypto.mac(:hmac, :sha384, 
                           state.api_secret |> Base.decode64!(), 
                           payload_base64)
                |> Base.encode16()
                |> String.downcase()
    
    # Build headers with authentication
    headers = [
      {"X-GEMINI-APIKEY", state.api_key},
      {"X-GEMINI-PAYLOAD", payload_base64},
      {"X-GEMINI-SIGNATURE", signature}
      | state.headers
    ]
    
    # Make request
    case HTTPoison.post(url, "", headers, state.opts) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} when status_code in 200..201 ->
        {:ok, body}
        
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("[Gemini] Error in authorized request to #{endpoint}: #{status_code}, #{body}")
        {:error, "HTTP Error #{status_code}: #{body}"}
        
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("[Gemini] Error in authorized request to #{endpoint}: #{inspect(reason)}")
        {:error, "HTTP Request failed: #{inspect(reason)}"}
    end
  end
  
  # Format a Unix timestamp to ISO8601
  defp format_timestamp(timestamp) when is_integer(timestamp) do
    # Gemini timestamps are in milliseconds
    case DateTime.from_unix(div(timestamp, 1000)) do
      {:ok, dt} -> DateTime.to_iso8601(dt)
      _ -> ""
    end
  end
  
  defp format_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {int, _} -> format_timestamp(int)
      :error -> timestamp  # Already formatted
    end
  end
  
  defp format_timestamp(nil), do: ""
  
  # Helper to parse a float value from a map with a default
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(_), do: 0.0
  
  # Helper to override timeout in options if provided
  defp maybe_override_timeout(nil, opts), do: opts
  defp maybe_override_timeout(timeout, opts) when is_integer(timeout) do
    opts
    |> Keyword.put(:timeout, timeout)
    |> Keyword.put(:recv_timeout, timeout)
  end
end