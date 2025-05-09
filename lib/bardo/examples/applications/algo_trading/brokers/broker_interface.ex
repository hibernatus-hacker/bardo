defmodule Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface do
  @moduledoc """
  Behavior defining the interface for all broker implementations.
  
  This module defines a consistent API for interacting with different brokers,
  allowing the trading system to be broker-agnostic. Any broker implementation
  must implement all these callback functions.
  """
  
  @doc """
  Initialize the broker with configuration options.
  
  ## Parameters
  
  - opts: A map of broker-specific options
  
  ## Returns
  
  - `{:ok, state}` - Broker state if initialization successful
  - `{:error, reason}` - If initialization fails
  """
  @callback init(opts :: map()) :: {:ok, map()} | {:error, any()}
  
  @doc """
  Get account information from the broker.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, account_info}` - Account information map
  - `{:error, reason}` - If the request fails
  """
  @callback get_account_info(state :: map()) :: {:ok, map()} | {:error, any()}
  
  @doc """
  Get a list of available instruments from the broker.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, instruments}` - List of available instruments
  - `{:error, reason}` - If the request fails
  """
  @callback get_instruments(state :: map()) :: {:ok, list(map())} | {:error, any()}
  
  @doc """
  Get historical price data for an instrument.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code (e.g., "EUR/USD")
  - timeframe: The timeframe (e.g., "M15" for 15-minute candles)
  - opts: Additional options (broker-specific)
  
  ## Returns
  
  - `{:ok, candles}` - List of candle data
  - `{:error, reason}` - If the request fails
  """
  @callback get_historical_data(state :: map(), instrument :: String.t(), timeframe :: String.t(), opts :: map()) :: 
    {:ok, map()} | {:error, any()}
    
  @doc """
  Get current price quotes for one or more instruments.
  
  ## Parameters
  
  - state: The broker state map
  - instruments: List of instrument codes or a single instrument code
  
  ## Returns
  
  - `{:ok, quotes}` - Map of instrument quotes
  - `{:error, reason}` - If the request fails
  """
  @callback get_quotes(state :: map(), instruments :: list(String.t()) | String.t()) :: 
    {:ok, map()} | {:error, any()}
    
  @doc """
  Execute a trade order.
  
  ## Parameters
  
  - state: The broker state map
  - order: A map containing order details
  
  ## Returns
  
  - `{:ok, order_details}` - Details of the executed order
  - `{:error, reason}` - If the order execution fails
  """
  @callback execute_order(state :: map(), order :: map()) :: 
    {:ok, map()} | {:error, any()}
    
  @doc """
  Get open positions for the account.
  
  ## Parameters
  
  - state: The broker state map
  
  ## Returns
  
  - `{:ok, positions}` - List of open positions
  - `{:error, reason}` - If the request fails
  """
  @callback get_positions(state :: map()) :: 
    {:ok, list(map())} | {:error, any()}
    
  @doc """
  Close a position for a specific instrument.
  
  ## Parameters
  
  - state: The broker state map
  - instrument: The instrument code
  - opts: Additional options (broker-specific)
  
  ## Returns
  
  - `{:ok, result}` - Result of the position close operation
  - `{:error, reason}` - If the operation fails
  """
  @callback close_position(state :: map(), instrument :: String.t(), opts :: map()) :: 
    {:ok, map()} | {:error, any()}
    
  # Helper functions for broker implementations
  
  @doc """
  Convert standard order direction to broker-specific format.
  
  Different brokers may use different representations for order direction.
  This function provides a standard way to convert between them.
  
  ## Examples
  
      iex> BrokerInterface.convert_direction(1, :metatrader)
      0  # MT4/MT5 uses 0 for buy, 1 for sell
      
      iex> BrokerInterface.convert_direction(-1, :oanda)
      "SELL"  # Oanda uses "BUY"/"SELL" strings
  """
  def convert_direction(direction, broker_type) do
    case broker_type do
      :metatrader ->
        # MT4/MT5 uses 0 for buy, 1 for sell
        if direction > 0, do: 0, else: 1
        
      :oanda ->
        # Oanda uses "BUY"/"SELL" strings
        if direction > 0, do: "BUY", else: "SELL"
        
      :gemini ->
        # Gemini uses "buy"/"sell" strings (lowercase)
        if direction > 0, do: "buy", else: "sell"
        
      _ ->
        # Default format
        if direction > 0, do: :buy, else: :sell
    end
  end
  
  @doc """
  Standardize price data format from broker-specific format.
  
  Different brokers return price data in different formats.
  This function converts them to a standard format used by the simulator.
  """
  def standardize_price_data(price_data, broker_type) do
    Enum.map(price_data, fn candle ->
      case broker_type do
        :metatrader ->
          # MT4/MT5 format conversion
          %{
            time: Map.get(candle, "time", ""),
            open: Map.get(candle, "open", 0.0),
            high: Map.get(candle, "high", 0.0),
            low: Map.get(candle, "low", 0.0),
            close: Map.get(candle, "close", 0.0),
            volume: Map.get(candle, "volume", 0)
          }
          
        :oanda ->
          # Oanda format conversion
          %{
            time: Map.get(candle, "time", ""),
            open: get_nested(candle, ["mid", "o"], 0.0) |> parse_float(),
            high: get_nested(candle, ["mid", "h"], 0.0) |> parse_float(),
            low: get_nested(candle, ["mid", "l"], 0.0) |> parse_float(),
            close: get_nested(candle, ["mid", "c"], 0.0) |> parse_float(),
            volume: Map.get(candle, "volume", 0) |> parse_integer()
          }
          
        :gemini ->
          # Gemini format conversion
          %{
            time: Map.get(candle, "time", Map.get(candle, "timestamp", "")),
            open: Map.get(candle, "open", 0.0) |> parse_float(),
            high: Map.get(candle, "high", 0.0) |> parse_float(),
            low: Map.get(candle, "low", 0.0) |> parse_float(),
            close: Map.get(candle, "close", 0.0) |> parse_float(),
            volume: Map.get(candle, "volume", 0) |> parse_integer()
          }
          
        _ ->
          # Default format (assume already standardized)
          candle
      end
    end)
  end
  
  # Private helper functions
  
  # Get a value from a nested map structure
  defp get_nested(map, keys, default) do
    Enum.reduce_while(keys, map, fn key, acc ->
      case acc do
        %{^key => value} -> {:cont, value}
        _ -> {:halt, default}
      end
    end)
  end
  
  # Parse float with error handling
  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      :error -> 0.0
    end
  end
  defp parse_float(value) when is_float(value), do: value
  defp parse_float(value) when is_integer(value), do: value * 1.0
  defp parse_float(_), do: 0.0
  
  # Parse integer with error handling
  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(value) when is_float(value), do: trunc(value)
  defp parse_integer(_), do: 0
end