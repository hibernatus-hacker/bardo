defmodule Bardo.Examples.Benchmarks.Dpb.DpbSensor do
  @moduledoc """
  Sensor implementation for the Double Pole Balancing (DPB) benchmark.
  
  This module provides sensors that agents can use to perceive
  the state of the cart and poles in the pole balancing simulation.
  """
  
  alias Bardo.AgentManager.Sensor
  
  @behaviour Sensor
  
  @doc """
  Initialize a new sensor for the DPB simulation.
  
  This is the implementation of the Sensor behavior's init/1 callback.
  """
  @impl Sensor
  def init(params) do
    state = %{
      id: nil,
      sensor_type: Map.get(params, :sensor_type, :cart_position),
      fanout: 1,
      cortex_pid: nil,
      scape_pid: nil,
      agent_id: nil
    }
    
    {:ok, state}
  end
  
  @doc """
  Process sensory data based on sensor type.
  
  This is the implementation of the Sensor behavior's percept/2 callback.
  """
  @impl Sensor
  def percept(state, data) do
    %{sensor_type: sensor_type} = state
    
    # Extract and validate the sensory input
    value = case sensor_type do
      :cart_position ->
        # Cart position data should be between -2.4 and 2.4
        validate_range(data, -2.4, 2.4)
        
      :pole1_angle ->
        # Pole angle data should be between -0.6 and 0.6 radians
        validate_range(data, -0.6, 0.6)
        
      :pole2_angle ->
        # Pole angle data should be between -0.6 and 0.6 radians
        validate_range(data, -0.6, 0.6)
        
      :cart_velocity ->
        # Cart velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      :pole1_angular_velocity ->
        # Angular velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      :pole2_angular_velocity ->
        # Angular velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      _ ->
        # Default case for unknown sensor types
        0.0
    end
    
    # Return the processed sensory input
    {:ok, [value], state}
  end
  
  @doc """
  Send a sensing request to the scape.
  
  This is the implementation of the Sensor behavior's sense/2 callback.
  """
  @impl Sensor
  def sense(state, _processed_input) do
    %{
      sensor_type: sensor_type,
      scape_pid: _scape_pid,
      agent_id: _agent_id
    } = state
    
    # Request data from the scape
    _sense_params = %{
      sensor_type: sensor_type
    }
    
    # Send a sense request to the scape directly for the behavior implementation
    # In a real implementation, we would process the response
    # For now, just return a default value
    {:ok, [0.0], state}
  end
  
  @doc """
  Initialize a new sensor for the DPB simulation.
  
  Parameters:
  - id: Sensor ID
  - sensor_type: :cart_position, :pole1_angle, :pole2_angle, :cart_velocity, 
                :pole1_angular_velocity, or :pole2_angular_velocity
  - fanout: Number of output elements (typically 1)
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  """
  # Legacy init function for compatibility
  def init(id, sensor_type, fanout, cortex_pid, scape_pid, agent_id) do
    state = %{
      id: id,
      sensor_type: sensor_type,
      fanout: fanout,
      cortex_pid: cortex_pid,
      scape_pid: scape_pid,
      agent_id: agent_id
    }
    
    {:ok, state}
  end
  
  @doc """
  Read data from the sensor.
  
  This function sends a sensing request to the scape and processes the response.
  """
  # Legacy read function for compatibility
  def read(state) do
    %{
      sensor_type: sensor_type,
      scape_pid: scape_pid,
      agent_id: agent_id
    } = state
    
    # Request data from the scape
    sense_params = %{
      sensor_type: sensor_type
    }
    
    # Send a sense request to the scape
    case GenServer.call(scape_pid, {:sense, agent_id, sense_params}) do
      {:success, response, _} ->
        # Process the sensor data
        percept(sensor_type, response, state)
        
      {:error, _reason} ->
        # Return a default output on error
        {:ok, generate_default_output(state), state}
    end
  end
  
  # Process the sensor data based on sensor type
  defp percept(sensor_type, data, state) do
    # Extract and validate the sensory input
    value = case sensor_type do
      :cart_position ->
        # Cart position data should be between -2.4 and 2.4
        validate_range(data, -2.4, 2.4)
        
      :pole1_angle ->
        # Pole angle data should be between -0.6 and 0.6 radians
        validate_range(data, -0.6, 0.6)
        
      :pole2_angle ->
        # Pole angle data should be between -0.6 and 0.6 radians
        validate_range(data, -0.6, 0.6)
        
      :cart_velocity ->
        # Cart velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      :pole1_angular_velocity ->
        # Angular velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      :pole2_angular_velocity ->
        # Angular velocity (no specific range, but we'll normalize it)
        validate_range(data, -10.0, 10.0)
        
      _ ->
        # Default case for unknown sensor types
        0.0
    end
    
    # Return the processed sensory input
    {:ok, [value], state}
  end
  
  # Validate and normalize a value to be within a given range
  defp validate_range(value, min_val, max_val) do
    # Ensure the value is a number
    value = if is_number(value), do: value, else: 0.0
    
    # Clamp to the specified range
    clamped = min(max(value, min_val), max_val)
    
    # Normalize to the range [-1, 1]
    range = max_val - min_val
    (clamped - min_val) / (range / 2) - 1.0
  end
  
  # Generate default output when there's an error or no data
  defp generate_default_output(_state) do
    # Default is neutral (centered) value
    [0.0]
  end
  
  @doc """
  Create a cart position sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec cart_position(integer(), integer(), atom(), atom()) :: map()
  def cart_position(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_cart_position,
      module: __MODULE__,
      sensor_type: :cart_position,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a pole1 angle sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec pole1_angle(integer(), integer(), atom(), atom()) :: map()
  def pole1_angle(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_pole1_angle,
      module: __MODULE__,
      sensor_type: :pole1_angle,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a pole2 angle sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec pole2_angle(integer(), integer(), atom(), atom()) :: map()
  def pole2_angle(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_pole2_angle,
      module: __MODULE__,
      sensor_type: :pole2_angle,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a cart velocity sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec cart_velocity(integer(), integer(), atom(), atom()) :: map()
  def cart_velocity(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_cart_velocity,
      module: __MODULE__,
      sensor_type: :cart_velocity,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a pole1 angular velocity sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec pole1_angular_velocity(integer(), integer(), atom(), atom()) :: map()
  def pole1_angular_velocity(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_pole1_angular_velocity,
      module: __MODULE__,
      sensor_type: :pole1_angular_velocity,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a pole2 angular velocity sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - fanout: Number of output elements (typically 1)
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec pole2_angular_velocity(integer(), integer(), atom(), atom()) :: map()
  def pole2_angular_velocity(id, fanout, cortex_id, scape_name) do
    %{
      id: id,
      name: :dpb_pole2_angular_velocity,
      module: __MODULE__,
      sensor_type: :pole2_angular_velocity,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
end