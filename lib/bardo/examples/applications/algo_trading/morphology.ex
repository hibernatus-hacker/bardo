defmodule Bardo.Examples.Applications.AlgoTrading.Morphology do
  @moduledoc """
  Morphology definition for algorithmic trading agents.
  
  This module defines the structure of algorithmic trading agents,
  including their sensors for market data and technical indicators,
  and actuators for executing trades and managing positions.
  """
  
  alias Bardo.PopulationManager.Morphology
  alias Bardo.PopulationManager.ExtendedMorphology
  alias Bardo.Examples.Applications.AlgoTrading.TradingSensor
  alias Bardo.Examples.Applications.AlgoTrading.TradingActuator
  alias Bardo.Models
  
  @behaviour Morphology
  @behaviour ExtendedMorphology
  
  @doc """
  List of sensors available to the algorithmic trading agents.
  
  Returns a list of sensor models for trading applications.
  """
  @impl Morphology
  def sensors do
    [
      # Price Chart Image (PCI) sensor - 2D representation of price charts
      Models.sensor(%{
        id: nil,
        name: :price_chart,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 100, # 10x10 grid
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: %{dimension: 10, timeframe: 60}
      }),
      
      # OHLCV (Open, High, Low, Close, Volume) sensor
      Models.sensor(%{
        id: nil,
        name: :ohlcv,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 25, # 5 values for each of 5 time periods
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: %{periods: 5}
      }),
      
      # Technical Indicators sensor
      Models.sensor(%{
        id: nil,
        name: :indicators,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 15, # 15 different technical indicators
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: %{
          indicators: [
            :sma_20, :sma_50, :sma_200,    # Simple Moving Averages
            :ema_20, :ema_50,              # Exponential Moving Averages
            :rsi_14,                       # Relative Strength Index
            :macd, :macd_signal,           # MACD and signal line
            :bollinger_upper, :bollinger_lower, # Bollinger Bands
            :atr_14,                       # Average True Range
            :adx_14,                       # Average Directional Index
            :stoch_k, :stoch_d             # Stochastic Oscillator
          ]
        }
      }),
      
      # Market Sentiment sensor
      Models.sensor(%{
        id: nil,
        name: :sentiment,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 5, # 5 sentiment indicators
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: %{
          sentiment_types: [
            :market_sentiment,  # Overall market sentiment (bullish/bearish)
            :volatility,        # Market volatility index
            :liquidity,         # Trading volume relative to average
            :trend_strength,    # Strength of current trend
            :market_regime      # Market regime (ranging, trending, etc.)
          ]
        }
      }),
      
      # Account Info sensor
      Models.sensor(%{
        id: nil,
        name: :account,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 5,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
  end
  
  @doc """
  List of actuators available to the algorithmic trading agents.
  
  Returns a list of actuator models for trading applications.
  """
  @impl Morphology
  def actuators do
    [
      # Trading actuator - for entering/exiting positions
      Models.actuator(%{
        id: nil,
        name: :trade,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 2, # Direction and sizing
        fanin_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      
      # Risk Management actuator - for setting stop loss and take profit
      Models.actuator(%{
        id: nil,
        name: :risk_management,
        type: :trading,
        cx_id: nil,
        scape: nil,
        vl: 2, # Stop loss and take profit levels
        fanin_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
  end
  
  @doc """
  Get the sensor and actuator configuration for a trading agent.
  
  Returns a map with :sensors and :actuators keys.
  """
  @impl ExtendedMorphology
  def get_phys_config(_owner, cortex_id, scape_name) do
    %{
      sensors: sensors(cortex_id, scape_name),
      actuators: actuators(cortex_id, scape_name)
    }
  end
  
  @doc """
  Get the parameters required to enter the trading scape.
  
  Returns a map with parameters for connecting to the trading environment.
  """
  @impl ExtendedMorphology
  def get_scape_params(_owner, _agent_id, _cortex_id, _scape_name) do
    %{}
  end
  
  @doc """
  Define the neuron pattern for algorithmic trading networks.
  
  This function specifies how sensors and actuators connect to the neural network.
  """
  @impl ExtendedMorphology
  def neuron_pattern(_owner, _agent_id, _cortex_id, neural_interface) do
    # Extract fanout and fanin from neural interface
    sensors = neural_interface.sensors
    actuators = neural_interface.actuators
    
    # Calculate total inputs from all sensors
    sensor_fanout = Enum.reduce(sensors, 0, fn sensor, acc -> 
      sensor.fanout + acc 
    end)
    
    # Calculate total outputs for all actuators
    actuator_fanin = Enum.reduce(actuators, 0, fn actuator, acc -> 
      actuator.fanin + acc 
    end)
    
    # Define the sensor to neuron index mapping
    sensor_id_to_idx_map = create_sensor_mapping(sensors, 0)
    
    # Define the actuator to neuron index mapping
    actuator_id_to_idx_map = create_actuator_mapping(actuators, 0)
    
    # Create the neuron pattern
    %{
      sensor_id_to_idx_map: sensor_id_to_idx_map,
      actuator_id_to_idx_map: actuator_id_to_idx_map,
      total_neuron_count: sensor_fanout,
      output_neuron_count: actuator_fanin,
      bias_as_neuron: true
    }
  end
  
  @doc """
  Define the sensors for trading agents.
  
  Returns a list of sensor specifications.
  """
  def sensors(cortex_id, scape_name) do
    [
      # Price Chart Image sensor
      %{
        id: 1,
        name: :price_chart,
        module: TradingSensor,
        sensor_type: :price_chart,
        params: %{
          dimension: 10,    # 10x10 grid
          timeframe: 60     # 60 time periods
        },
        fanout: 100,        # 10x10 = 100 outputs
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # OHLCV data sensor
      %{
        id: 2,
        name: :ohlcv,
        module: TradingSensor,
        sensor_type: :ohlcv,
        params: %{
          periods: 5       # 5 time periods of history
        },
        fanout: 25,        # 5 values x 5 periods = 25 outputs
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # Technical indicators sensor
      %{
        id: 3,
        name: :indicators,
        module: TradingSensor,
        sensor_type: :indicators,
        params: %{
          indicators: [
            :sma_20, :sma_50, :sma_200,    # Simple Moving Averages
            :ema_20, :ema_50,              # Exponential Moving Averages
            :rsi_14,                       # Relative Strength Index
            :macd, :macd_signal,           # MACD and signal line
            :bollinger_upper, :bollinger_lower, # Bollinger Bands
            :atr_14,                       # Average True Range
            :adx_14,                       # Average Directional Index
            :stoch_k, :stoch_d             # Stochastic Oscillator
          ]
        },
        fanout: 15,        # 15 technical indicators
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # Market sentiment sensor
      %{
        id: 4,
        name: :sentiment,
        module: TradingSensor,
        sensor_type: :sentiment,
        params: %{
          sentiment_types: [
            :market_sentiment,  # Overall market sentiment (bullish/bearish)
            :volatility,        # Market volatility index
            :liquidity,         # Trading volume relative to average
            :trend_strength,    # Strength of current trend
            :market_regime      # Market regime (ranging, trending, etc.)
          ]
        },
        fanout: 5,         # 5 sentiment indicators
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # Account information sensor
      %{
        id: 5,
        name: :account,
        module: TradingSensor,
        sensor_type: :account,
        params: %{},
        fanout: 5,         # 5 outputs for account data
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    ]
  end
  
  @doc """
  Define the actuators for trading agents.
  
  Returns a list of actuator specifications.
  """
  def actuators(cortex_id, scape_name) do
    [
      # Trading actuator
      %{
        id: 1,
        name: :trade,
        module: TradingActuator,
        actuator_type: :trade,
        fanin: 2,          # 2 inputs: direction and position size
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # Risk management actuator
      %{
        id: 2,
        name: :risk_management,
        module: TradingActuator,
        actuator_type: :risk_management,
        fanin: 2,          # 2 inputs: stop loss and take profit levels
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    ]
  end
  
  # Helper function to create sensor ID to neuron index mapping
  defp create_sensor_mapping(sensors, start_idx) do
    Enum.reduce(sensors, {%{}, start_idx}, fn sensor, {map, idx} ->
      end_idx = idx + sensor.fanout
      updated_map = Map.put(map, sensor.id, {idx, end_idx})
      {updated_map, end_idx}
    end)
    |> elem(0)  # Return just the map
  end
  
  # Helper function to create actuator ID to neuron index mapping
  defp create_actuator_mapping(actuators, start_idx) do
    Enum.reduce(actuators, {%{}, start_idx}, fn actuator, {map, idx} ->
      end_idx = idx + actuator.fanin
      updated_map = Map.put(map, actuator.id, {idx, end_idx})
      {updated_map, end_idx}
    end)
    |> elem(0)  # Return just the map
  end
end