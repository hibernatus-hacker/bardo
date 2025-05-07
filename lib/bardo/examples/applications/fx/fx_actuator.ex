defmodule Bardo.Examples.Applications.Fx.FxActuator do
  @moduledoc """
  Actuator implementation for the Forex (FX) trading application.
  
  This module provides actuators that agents can use to interact
  with the Forex trading environment, primarily for executing trades.
  """
  
  alias Bardo.AgentManager.Actuator
  
  @behaviour Actuator
  
  @doc """
  Initialize a new actuator for FX trading.
  
  Parameters:
  - id: Actuator ID
  - actuator_type: :trade
  - fanin: Number of input elements
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  """
  @impl Actuator
  def init(_params) do
    state = %{
      id: nil,
      actuator_type: :trade,
      fanin: 1,
      cortex_pid: nil,
      scape_pid: nil,
      agent_id: nil
    }
    
    {:ok, state}
  end
  
  # Legacy init function for compatibility
  def init(id, actuator_type, fanin, cortex_pid, scape_pid, agent_id) do
    state = %{
      id: id,
      actuator_type: actuator_type,
      fanin: fanin,
      cortex_pid: cortex_pid,
      scape_pid: scape_pid,
      agent_id: agent_id
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle a list of incoming signals from the neural network.
  
  This function:
  1. Converts neural network output to a trade decision
  2. Sends the trade decision to the FX simulator
  3. Processes responses (fitness, account updates)
  """
  @impl Actuator
  def actuate(_actuator_type, {agent_id, signals, _params, _vl, scape, actuator_id, mod_state}) do
    # Get the neural network output
    [value | _] = signals
    
    # Convert the output to a trade decision
    # -1 = short, 0 = no position, 1 = long
    trade_decision = convert_to_trade_decision(value)
    
    # Prepare parameters for the scape
    trade_params = %{
      value: trade_decision
    }
    
    # Send the decision to the scape
    if is_pid(scape) do
      Bardo.AgentManager.PrivateScape.actuate(scape, agent_id, actuator_id, :trade, trade_params)
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
  
  # Legacy handle function for compatibility
  def handle(signals, state) do
    %{
      actuator_type: actuator_type,
      scape_pid: scape_pid,
      agent_id: agent_id
    } = state
    
    # Get the neural network output
    [value | _] = signals
    
    # Convert the output to a trade decision
    # -1 = short, 0 = no position, 1 = long
    trade_decision = convert_to_trade_decision(value)
    
    # Prepare parameters for the scape
    params = %{
      actuator_type: actuator_type,
      value: trade_decision
    }
    
    # Send an actuate request to the scape
    result = case GenServer.call(scape_pid, {:actuate, agent_id, params}) do
      {:success, response, _scape_state} ->
        check_termination(response, state)
        
      {:error, _reason} ->
        # Just continue on error
        {:ok, state}
    end
    
    result
  end
  
  # Convert neural network output to a trade decision
  defp convert_to_trade_decision(value) do
    cond do
      value < -0.33 -> -1    # Short position
      value > 0.33  -> 1     # Long position
      true          -> 0     # No position
    end
  end
  
  # Check if the agent should terminate based on the scape response
  defp check_termination(response, state) do
    %{cortex_pid: cortex_pid} = state
    
    case response do
      # Check if trading simulation is complete
      %{status: :complete, fitness: fitness} ->
        # Send termination signal to cortex
        send(cortex_pid, {:terminate, fitness})
        {:terminate, fitness}
        
      # Otherwise continue trading
      _ ->
        {:ok, state}
    end
  end
end