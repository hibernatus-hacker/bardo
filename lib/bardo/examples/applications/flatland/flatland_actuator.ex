defmodule Bardo.Examples.Applications.Flatland.FlatlandActuator do
  @moduledoc """
  Actuator implementation for the Flatland simulation.
  
  This module provides actuators that agents can use to interact
  with the Flatland environment, primarily for movement control.
  """
  
  alias Bardo.AgentManager.Actuator
  
  @behaviour Actuator
  
  @doc """
  Initialize a new actuator for Flatland.
  
  Parameters:
  - id: Actuator ID
  - actuator_type: :two_wheels
  - fanin: Number of input elements
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  """
  @impl Actuator
  def init(id, actuator_type, fanin, cortex_pid, scape_pid, agent_id) do
    state = %{
      id: id,
      actuator_type: actuator_type,
      fanin: fanin,
      cortex_pid: cortex_pid,
      scape_pid: scape_pid,
      agent_id: agent_id,
      is_first_cycle: true
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle a list of incoming signals from the neural network.
  
  This function:
  1. Activates the actuator with signals from the neural network
  2. Sends commands to the scape (simulated world)
  3. Processes responses (fitness, etc.)
  """
  @impl Actuator
  def handle(signals, state) do
    %{
      actuator_type: actuator_type,
      scape_pid: scape_pid,
      agent_id: agent_id,
      is_first_cycle: is_first_cycle
    } = state
    
    # Prepare parameters for the scape
    params = %{
      actuator_type: actuator_type,
      output_vector: signals
    }
    
    # Send an actuate request to the scape
    result = case GenServer.call(scape_pid, {:actuate, agent_id, params}) do
      {:success, response} ->
        check_termination(response, state)
        
      {:error, _reason} ->
        # Just continue on error
        {:ok, %{state | is_first_cycle: false}}
    end
    
    result
  end
  
  # Check if the agent should terminate based on the scape response
  defp check_termination(response, state) do
    %{is_first_cycle: is_first_cycle, cortex_pid: cortex_pid} = state
    
    # Get fitness and misc data from the response
    %{fitness: fitness, misc: misc} = response
    %{energy: energy, state: avatar_state} = misc
    
    # Check if the agent is dead or out of energy
    if avatar_state == :dead or energy <= 0 do
      # Terminate the agent with the final fitness score
      if is_first_cycle do
        # Don't terminate on first cycle, even if agent is dead
        {:ok, %{state | is_first_cycle: false}}
      else
        # Send termination signal to cortex
        send(cortex_pid, {:terminate, fitness})
        {:terminate, fitness}
      end
    else
      # Continue normal operation
      {:ok, %{state | is_first_cycle: false}}
    end
  end
  
  @doc """
  Create a two-wheel actuator configuration.
  
  Parameters:
  - id: Actuator ID
  - fanin: Number of input elements from the neural network
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns an actuator specification map.
  """
  @spec two_wheels(integer(), integer(), atom(), atom()) :: map()
  def two_wheels(id, fanin, cortex_id, scape_name) do
    %{
      id: id,
      name: :flatland_two_wheels,
      module: __MODULE__,
      actuator_type: :two_wheels,
      fanin: fanin,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
end