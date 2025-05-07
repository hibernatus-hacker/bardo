defmodule Bardo.Examples.Benchmarks.Dpb.DpbActuator do
  @moduledoc """
  Actuator implementation for the Double Pole Balancing (DPB) benchmark.
  
  This module provides actuators that agents can use to control
  the cart in the pole balancing simulation.
  """
  
  alias Bardo.AgentManager.Actuator
  
  @behaviour Actuator
  
  # Maximum force that can be applied to the cart
  @max_force 10.0
  
  @doc """
  Initialize a new actuator for the DPB simulation.
  
  Parameters:
  - id: Actuator ID
  - actuator_type: :force
  - fanin: Number of input elements
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  - parameters: Additional parameters (with_damping or without_damping)
  """
  @impl Actuator
  def init(id, actuator_type, fanin, cortex_pid, scape_pid, agent_id, parameters) do
    state = %{
      id: id,
      actuator_type: actuator_type,
      fanin: fanin,
      cortex_pid: cortex_pid,
      scape_pid: scape_pid,
      agent_id: agent_id,
      parameters: parameters
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle a list of incoming signals from the neural network.
  
  This function:
  1. Converts neural network output to a force value
  2. Sends the force value to the DPB simulator
  3. Processes responses (fitness, simulation state)
  """
  @impl Actuator
  def handle(signals, state) do
    %{
      actuator_type: actuator_type,
      scape_pid: scape_pid,
      agent_id: agent_id,
      parameters: parameters
    } = state
    
    # Get the neural network output
    [value | _] = signals
    
    # Convert the output to a force value
    # Force is scaled to [-10, 10] Newtons
    force = value * @max_force
    
    # Prepare parameters for the scape
    actuate_params = %{
      actuator_type: actuator_type,
      force: force,
      parameters: parameters
    }
    
    # Send an actuate request to the scape
    result = case GenServer.call(scape_pid, {:actuate, agent_id, actuate_params}) do
      {:success, response, _scape_state} ->
        check_termination(response, state)
        
      {:error, _reason} ->
        # Just continue on error
        {:ok, state}
    end
    
    result
  end
  
  # Check if the agent should terminate based on the scape response
  defp check_termination(response, state) do
    %{cortex_pid: cortex_pid} = state
    
    case response do
      # Check if simulation failed (pole fell or cart out of bounds)
      %{status: :failed, fitness: fitness} ->
        # Send termination signal to cortex
        send(cortex_pid, {:terminate, fitness})
        {:terminate, fitness}
        
      # Check if simulation has reached maximum steps (success)
      %{status: :completed, fitness: fitness} ->
        # Send termination signal to cortex
        send(cortex_pid, {:terminate, fitness})
        {:terminate, fitness}
        
      # Otherwise continue simulation
      _ ->
        {:ok, state}
    end
  end
  
  @doc """
  Create a force actuator configuration for DPB with damping.
  
  Parameters:
  - id: Actuator ID
  - fanin: Number of input elements from the neural network
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns an actuator specification map.
  """
  @spec with_damping(integer(), integer(), atom(), atom()) :: map()
  def with_damping(id, fanin, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_force_with_damping,
      module: __MODULE__,
      actuator_type: :force,
      parameters: :with_damping,
      fanin: fanin,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a force actuator configuration for DPB without damping.
  
  Parameters:
  - id: Actuator ID
  - fanin: Number of input elements from the neural network
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns an actuator specification map.
  """
  @spec without_damping(integer(), integer(), atom(), atom()) :: map()
  def without_damping(id, fanin, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_force_without_damping,
      module: __MODULE__,
      actuator_type: :force,
      parameters: :without_damping,
      fanin: fanin,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
end