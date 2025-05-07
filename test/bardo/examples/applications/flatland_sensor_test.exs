defmodule Bardo.Examples.Applications.FlatlandSensorTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Applications.Flatland.FlatlandSensor
  
  # Define a mock GenServer to simulate a scape process
  defmodule MockScape do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, %{})
    end
    
    def init(_) do
      {:ok, %{}}
    end
    
    # Simulate sensing of distance
    def handle_call({:sense, _agent_id, %{sensor_type: :distance_scanner, angles: angles}}, _from, state) do
      # Return dummy distance values: distance is proportional to angle
      distances = Enum.map(angles, fn angle -> 
        abs(angle) / (2 * :math.pi()) # Normalize to [0, 1]
      end)
      
      {:reply, {:success, distances}, state}
    end
    
    # Simulate sensing of color
    def handle_call({:sense, _agent_id, %{sensor_type: :color_scanner, angles: angles}}, _from, state) do
      # Return dummy color values: red for right, green for left
      colors = Enum.map(angles, fn angle -> 
        cond do
          angle > 0 -> 0.5  # Red (predator)
          angle < 0 -> -0.5 # Green (plant)
          true -> 0.0       # Blue (prey)
        end
      end)
      
      {:reply, {:success, colors}, state}
    end
    
    # Simulate error case
    def handle_call({:sense, _agent_id, %{sensor_type: :unknown}}, _from, state) do
      {:reply, {:error, "Unknown sensor type"}, state}
    end
  end
  
  describe "init/7" do
    test "initializes distance scanner state correctly" do
      {:ok, state} = FlatlandSensor.init(
        1, 
        :distance_scanner,
        [0.0, 0.5, 1.0], 
        3,
        self(),
        self(),
        "agent_1"
      )
      
      assert state.id == 1
      assert state.sensor_type == :distance_scanner
      assert state.vl == [0.0, 0.5, 1.0]
      assert state.fanout == 3
      assert state.cortex_pid == self()
      assert state.scape_pid == self()
      assert state.agent_id == "agent_1"
    end
    
    test "initializes color scanner state correctly" do
      {:ok, state} = FlatlandSensor.init(
        2, 
        :color_scanner,
        [0.0, 0.5, 1.0], 
        3,
        self(),
        self(),
        "agent_1"
      )
      
      assert state.id == 2
      assert state.sensor_type == :color_scanner
      assert state.vl == [0.0, 0.5, 1.0]
      assert state.fanout == 3
    end
  end
  
  describe "read/1 with distance scanner" do
    setup do
      {:ok, scape_pid} = MockScape.start_link()
      
      state = %{
        id: 1,
        sensor_type: :distance_scanner,
        vl: [0.0, :math.pi()/2, :math.pi()],
        fanout: 3,
        cortex_pid: self(),
        scape_pid: scape_pid,
        agent_id: "agent_1"
      }
      
      %{state: state}
    end
    
    test "reads and processes distance data correctly", %{state: state} do
      {:ok, output, _new_state} = FlatlandSensor.read(state)
      
      assert length(output) == 3
      # Our mock returns distances proportional to angle
      assert_in_delta Enum.at(output, 0), 0.0, 0.001
      assert_in_delta Enum.at(output, 1), 0.25, 0.001
      assert_in_delta Enum.at(output, 2), 0.5, 0.001
    end
  end
  
  describe "read/1 with color scanner" do
    setup do
      {:ok, scape_pid} = MockScape.start_link()
      
      state = %{
        id: 2,
        sensor_type: :color_scanner,
        vl: [-:math.pi()/2, 0.0, :math.pi()/2],
        fanout: 3,
        cortex_pid: self(),
        scape_pid: scape_pid,
        agent_id: "agent_1"
      }
      
      %{state: state}
    end
    
    test "reads and processes color data correctly", %{state: state} do
      {:ok, output, _new_state} = FlatlandSensor.read(state)
      
      assert length(output) == 3
      # Our mock returns color values based on angle sign
      assert_in_delta Enum.at(output, 0), -0.5, 0.001  # Green (plant)
      assert_in_delta Enum.at(output, 1), 0.0, 0.001   # Blue (prey)
      assert_in_delta Enum.at(output, 2), 0.5, 0.001   # Red (predator)
    end
  end
  
  describe "read/1 with unknown sensor" do
    setup do
      {:ok, scape_pid} = MockScape.start_link()
      
      state = %{
        id: 3,
        sensor_type: :unknown,
        vl: [0.0],
        fanout: 1,
        cortex_pid: self(),
        scape_pid: scape_pid,
        agent_id: "agent_1"
      }
      
      %{state: state}
    end
    
    test "handles error gracefully", %{state: state} do
      {:ok, output, _new_state} = FlatlandSensor.read(state)
      
      # Should return a default value
      assert length(output) == 1
      assert Enum.at(output, 0) == 1.0  # Default value for unknown sensor
    end
  end
  
  describe "sensor factory functions" do
    test "distance_scanner creates correct specification" do
      spec = FlatlandSensor.distance_scanner(1, 5, 5, :cortex_1, :scape_1)
      
      assert spec.id == 1
      assert spec.name == :flatland_distance_scanner
      assert spec.module == FlatlandSensor
      assert spec.sensor_type == :distance_scanner
      assert length(spec.vl) == 5  # 5 angles
      assert spec.fanout == 5
      assert spec.cortex_id == :cortex_1
      assert spec.scape_name == :scape_1
    end
    
    test "color_scanner creates correct specification" do
      spec = FlatlandSensor.color_scanner(2, 5, 5, :cortex_1, :scape_1)
      
      assert spec.id == 2
      assert spec.name == :flatland_color_scanner
      assert spec.module == FlatlandSensor
      assert spec.sensor_type == :color_scanner
      assert length(spec.vl) == 5  # 5 angles
      assert spec.fanout == 5
      assert spec.cortex_id == :cortex_1
      assert spec.scape_name == :scape_1
    end
    
    test "angles are evenly distributed" do
      spec = FlatlandSensor.distance_scanner(1, 4, 4, :cortex_1, :scape_1)
      
      # 4 angles should be at 0, π/2, π, 3π/2
      assert length(spec.vl) == 4
      assert_in_delta Enum.at(spec.vl, 0), 0.0, 0.001
      assert_in_delta Enum.at(spec.vl, 1), :math.pi()/2, 0.001
      assert_in_delta Enum.at(spec.vl, 2), :math.pi(), 0.001
      assert_in_delta Enum.at(spec.vl, 3), 3*:math.pi()/2, 0.001
    end
  end
end