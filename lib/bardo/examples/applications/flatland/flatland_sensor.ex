defmodule Bardo.Examples.Applications.Flatland.FlatlandSensor do
  @moduledoc """
  Sensor implementation for the Flatland simulation.
  
  This module provides sensors that agents can use to perceive 
  the Flatland environment, including distance and color sensors.
  """
  
  alias Bardo.AgentManager.Sensor
  
  @behaviour Sensor
  
  @doc """
  Initialize a new sensor for Flatland.
  
  Parameters:
  - id: Sensor ID
  - sensor_type: :distance_scanner or :color_scanner
  - vl: List of angles to scan in radians
  - fanout: Number of output elements
  - cortex_pid: PID of the cortex process
  - scape_pid: PID of the scape process
  - agent_id: ID of the agent
  """
  @impl Sensor
  def init(id, sensor_type, vl, fanout, cortex_pid, scape_pid, agent_id) do
    state = %{
      id: id,
      sensor_type: sensor_type,
      vl: vl,
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
  @impl Sensor
  def read(state) do
    %{
      sensor_type: sensor_type,
      vl: vl,
      scape_pid: scape_pid,
      agent_id: agent_id
    } = state
    
    # Parameters to send to the scape
    params = %{
      sensor_type: sensor_type,
      angles: vl
    }
    
    # Send a sense request to the scape
    case GenServer.call(scape_pid, {:sense, agent_id, params}) do
      {:success, response} ->
        # Process the response based on sensor type
        process_sensor_data(response, sensor_type, state)
        
      {:error, reason} ->
        # Handle error case
        {:ok, generate_default_output(state), state}
    end
  end
  
  # Process sensor data based on sensor type
  defp process_sensor_data(response, sensor_type, state) do
    case sensor_type do
      :distance_scanner ->
        process_distance_data(response, state)
        
      :color_scanner ->
        process_color_data(response, state)
        
      _ ->
        {:ok, generate_default_output(state), state}
    end
  end
  
  # Process distance sensor data
  defp process_distance_data(distances, state) do
    # Normalize distances to range [0.0, 1.0]
    # In flatland, distances are already normalized
    output = Enum.map(distances, fn distance ->
      distance
    end)
    
    {:ok, output, state}
  end
  
  # Process color sensor data
  defp process_color_data(colors, state) do
    # Colors are already in the range [-0.5, 0.5, 1.0]
    # -0.5: plant (green)
    #  0.0: prey (blue)
    #  0.5: predator (red)
    #  1.0: nothing (white)
    output = Enum.map(colors, fn color ->
      color
    end)
    
    {:ok, output, state}
  end
  
  # Generate default output when there's an error or no data
  defp generate_default_output(state) do
    # For both sensor types, default to 1.0 (nothing detected)
    List.duplicate(1.0, length(state.vl))
  end
  
  @doc """
  Create a distance scanner sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - n: Number of rays (angles) to scan
  - fanout: Number of output elements
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec distance_scanner(integer(), integer(), integer(), atom(), atom()) :: map()
  def distance_scanner(id, n, fanout, cortex_id, scape_name) do
    # Calculate angles for rays, evenly distributed
    vl = generate_angles(n)
    
    %{
      id: id,
      name: :flatland_distance_scanner,
      module: __MODULE__,
      sensor_type: :distance_scanner,
      vl: vl,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  @doc """
  Create a color scanner sensor configuration.
  
  Parameters:
  - id: Sensor ID
  - n: Number of rays (angles) to scan
  - fanout: Number of output elements
  - cortex_id: ID of the cortex
  - scape_name: Name of the scape
  
  Returns a sensor specification map.
  """
  @spec color_scanner(integer(), integer(), integer(), atom(), atom()) :: map()
  def color_scanner(id, n, fanout, cortex_id, scape_name) do
    # Calculate angles for rays, evenly distributed
    vl = generate_angles(n)
    
    %{
      id: id,
      name: :flatland_color_scanner,
      module: __MODULE__,
      sensor_type: :color_scanner,
      vl: vl,
      fanout: fanout,
      cortex_id: cortex_id,
      scape_name: scape_name
    }
  end
  
  # Generate evenly distributed angles for scanning
  defp generate_angles(n) do
    angle_step = 2 * :math.pi() / n
    
    Enum.map(0..(n-1), fn i ->
      i * angle_step
    end)
  end
end