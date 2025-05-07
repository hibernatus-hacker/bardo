defmodule Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface do
  @moduledoc """
  Generic interface for connecting trading agents to external brokers.
  
  This module defines the common interface for all broker implementations
  and provides helper functions for integrating with various trading platforms.
  """
  
  alias Bardo.AgentManager.PrivateScape
  require Logger
  
  @callback connect(map()) :: {:ok, map()} | {:error, any()}
  @callback disconnect(map()) :: :ok | {:error, any()}
  @callback get_account_info(map()) :: {:ok, map()} | {:error, any()}
  @callback get_market_data(map(), String.t(), integer(), map()) :: {:ok, list(map())} | {:error, any()}
  @callback place_order(map(), String.t(), integer(), float(), map()) :: {:ok, map()} | {:error, any()}
  @callback close_order(map(), String.t()) :: {:ok, map()} | {:error, any()}
  @callback modify_order(map(), String.t(), map()) :: {:ok, map()} | {:error, any()}
  
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
        
      :binance ->
        # Binance uses "BUY"/"SELL" strings
        if direction > 0, do: "BUY", else: "SELL"
        
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
          
        :binance ->
          # Binance format conversion
          # Binance returns arrays, not objects
          case candle do
            [time, open, high, low, close, volume | _] when is_list(candle) ->
              %{
                time: format_timestamp(time),
                open: parse_float(open),
                high: parse_float(high),
                low: parse_float(low),
                close: parse_float(close),
                volume: parse_integer(volume)
              }
            _ -> 
              # Try to handle object format
              %{
                time: Map.get(candle, "openTime", "") |> format_timestamp(),
                open: Map.get(candle, "open", 0.0) |> parse_float(),
                high: Map.get(candle, "high", 0.0) |> parse_float(),
                low: Map.get(candle, "low", 0.0) |> parse_float(),
                close: Map.get(candle, "close", 0.0) |> parse_float(),
                volume: Map.get(candle, "volume", 0) |> parse_integer()
              }
          end
          
        _ ->
          # Default format (assume already standardized)
          candle
      end
    end)
  end
  
  @doc """
  Format an order for submission to a broker.
  
  Different brokers require different order formats.
  This function creates the appropriate format for each broker type.
  """
  def format_order(symbol, direction, size, price, stop_loss, take_profit, broker_type) do
    broker_direction = convert_direction(direction, broker_type)
    
    case broker_type do
      :metatrader ->
        # MT4/MT5 order format
        %{
          symbol: symbol,
          cmd: broker_direction,
          volume: size,
          price: price,
          sl: stop_loss,
          tp: take_profit
        }
        
      :oanda ->
        # Oanda order format
        %{
          order: %{
            instrument: symbol,
            units: if direction > 0, do: size, else: -size,
            type: "MARKET",
            positionFill: "DEFAULT",
            stopLossOnFill: %{
              price: stop_loss |> Float.to_string([decimals: 5])
            },
            takeProfitOnFill: %{
              price: take_profit |> Float.to_string([decimals: 5])
            }
          }
        }
        
      :binance ->
        # Binance order format
        %{
          symbol: symbol,
          side: broker_direction,
          type: "MARKET",
          quantity: size
        }
        
      _ ->
        # Default format
        %{
          symbol: symbol,
          direction: broker_direction,
          size: size,
          price: price,
          stop_loss: stop_loss,
          take_profit: take_profit
        }
    end
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
  
  # Format timestamp to standard format
  defp format_timestamp(timestamp) when is_binary(timestamp), do: timestamp
  defp format_timestamp(timestamp) when is_integer(timestamp) do
    # Convert Unix timestamp to datetime string
    case DateTime.from_unix(div(timestamp, 1000)) do
      {:ok, datetime} -> DateTime.to_string(datetime)
      _ -> ""
    end
  end
  defp format_timestamp(_), do: ""
end