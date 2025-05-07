defmodule TestFlatland do
  @moduledoc """
  A minimal implementation of the Sector behaviour for testing.
  """
  
  @behaviour Bardo.ScapeManager.Sector
  
  # Initialize the test flatland with default values
  @impl Bardo.ScapeManager.Sector
  def init(_mod) do
    # Create a minimal state for testing
    state = %{
      width: 50,
      height: 50,
      avatars: %{},
      avatar_age: 0
    }
    
    {:ok, state}
  end
  
  # Handle a new agent entering the environment
  @impl Bardo.ScapeManager.Sector
  def enter(agent_id, params, state) do
    # Create a basic avatar for the agent
    new_avatars = Map.put(state.avatars, agent_id, %{
      id: agent_id,
      type: :test,
      x: :rand.uniform(state.width),
      y: :rand.uniform(state.height)
    })
    
    {:success, %{state | avatars: new_avatars}}
  end
  
  # Handle an agent leaving the environment
  @impl Bardo.ScapeManager.Sector
  def leave(agent_id, _params, state) do
    # Remove the avatar associated with the agent
    new_avatars = Map.delete(state.avatars, agent_id)
    
    {:ok, %{state | avatars: new_avatars}}
  end
  
  # Handle sensor operations
  @impl Bardo.ScapeManager.Sector
  def sense(agent_id, _params, _sensor_pid, state) do
    # Return random sensory data
    result = [
      :rand.uniform(),
      :rand.uniform(),
      :rand.uniform()
    ]
    
    {result, state}
  end
  
  # Handle actuator operations
  @impl Bardo.ScapeManager.Sector
  def actuate(agent_id, _function, _params, state) do
    # Return success with random fitness data
    result = {[1.0], 0}
    
    {result, state}
  end
  
  # Remove an agent (optional callback)
  def remove(agent_id, state) do
    # Remove the avatar and return it
    avatar = Map.get(state.avatars, agent_id)
    new_avatars = Map.delete(state.avatars, agent_id)
    
    {avatar, %{state | avatars: new_avatars}}
  end
  
  # Insert an agent (optional callback)
  def insert(agent_id, params, state) do
    # Create a basic avatar for the agent
    new_avatars = Map.put(state.avatars, agent_id, %{
      id: agent_id,
      type: :test,
      x: :rand.uniform(state.width),
      y: :rand.uniform(state.height)
    })
    
    {:ok, %{state | avatars: new_avatars}}
  end
end