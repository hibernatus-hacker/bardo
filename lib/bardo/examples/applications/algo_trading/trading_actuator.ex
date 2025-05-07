defmodule Bardo.Examples.Applications.AlgoTrading.TradingActuator do
  @moduledoc """
  Actuator implementation for algorithmic trading agents.
  
  This module provides actuators that agents can use to interact
  with trading environments:
  
  - trade: For entering and exiting trading positions with direction and size
  - risk_management: For setting stop loss and take profit levels
  """
  
  alias Bardo.AgentManager.Actuator
  
  @behaviour Actuator
  
  @doc """
  Initialize a new actuator for algorithmic trading.
  
  This is the implementation of the Actuator behavior's init/1 callback.
  """
  @impl Actuator
  def init(params) do
    state = %{
      id: nil,
      actuator_type: Map.get(params, :actuator_type, :trade),
      fanin: Map.get(params, :fanin, 2),
      cortex_pid: nil,
      scape_pid: nil,
      agent_id: nil
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle a list of incoming signals from the neural network.
  
  This function:
  1. Processes the neural network outputs
  2. Converts them to trading decisions
  3. Sends the decisions to the trading environment
  """
  @impl Actuator
  def actuate(actuator_type, {agent_id, signals, _params, _vl, scape, actuator_id, mod_state}) do
    # Process signals based on actuator type
    trade_params = case actuator_type do
      :trade ->
        # Extract direction and size signals
        [direction_signal, size_signal | _] = pad_signals(signals, 2)
        
        # Convert to trade decision
        # Direction: -1 = short, 0 = no position, 1 = long
        direction = convert_to_trade_direction(direction_signal)
        
        # Size: 0.0-1.0 representing percentage of maximum position size
        size = convert_to_position_size(size_signal)
        
        # Prepare trade parameters
        %{
          action: :trade,
          direction: direction,
          size: size
        }
        
      :risk_management ->
        # Extract risk management signals
        [stop_loss_signal, take_profit_signal | _] = pad_signals(signals, 2)
        
        # Convert to risk parameters
        # Stop loss: 0.0-1.0 representing percentage from entry price
        stop_loss = convert_to_risk_level(stop_loss_signal)
        
        # Take profit: 0.0-1.0 representing percentage from entry price
        take_profit = convert_to_risk_level(take_profit_signal)
        
        # Prepare risk management parameters
        %{
          action: :risk_management,
          stop_loss: stop_loss,
          take_profit: take_profit
        }
        
      _ ->
        # Unknown actuator type, use empty parameters
        %{action: :unknown}
    end
    
    # Send the decision to the scape
    if is_pid(scape) do
      Bardo.AgentManager.PrivateScape.actuate(scape, agent_id, actuator_id, actuator_type, trade_params)
    end
    
    # Return updated state
    mod_state
  end
  
  @doc """
  Cleanup resources when terminating.
  """
  @impl Actuator
  def terminate(_reason, _mod_state) do
    # No resources to clean up
    :ok
  end
  
  # Ensure signals list has the required length
  defp pad_signals(signals, length) do
    current_length = length(signals)
    if current_length >= length do
      Enum.take(signals, length)
    else
      signals ++ List.duplicate(0.0, length - current_length)
    end
  end
  
  # Convert neural network output to a trade direction
  defp convert_to_trade_direction(value) do
    cond do
      value < -0.33 -> -1    # Short position
      value > 0.33  -> 1     # Long position
      true          -> 0     # No position
    end
  end
  
  # Convert neural network output to a position size
  defp convert_to_position_size(value) do
    # Ensure value is in [0,1] range
    # This represents percentage of maximum allowed position size
    min(max(value, 0.0), 1.0)
  end
  
  # Convert neural network output to a risk level
  defp convert_to_risk_level(value) do
    # Ensure value is in [0,1] range
    # This represents percentage from entry price for stop loss or take profit
    min(max(value, 0.0), 1.0)
  end
end