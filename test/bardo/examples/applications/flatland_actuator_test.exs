defmodule Bardo.Examples.Applications.FlatlandActuatorTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Applications.Flatland.FlatlandActuator
  
  # Define a mock GenServer to simulate a scape process
  defmodule MockScape do
    use GenServer

    def start_link do
      GenServer.start_link(__MODULE__, %{})
    end
    
    def init(_) do
      {:ok, %{}}
    end
    
    # Simulate actuating (handling wheel movements)
    def handle_call({:actuate, _agent_id, params}, _from, state) do
      %{actuator_type: :two_wheels, output_vector: output_vector} = params
      
      # Determine response based on wheel values
      [left, right] = output_vector
      
      if left > 0.5 and right > 0.5 do
        # High energy
        response = %{
          fitness: [1000.0, "prey_1"],
          misc: %{
            energy: 1000.0,
            state: :live
          }
        }
        {:reply, {:success, response}, state}
      else
        # Low energy
        response = %{
          fitness: [5.0],
          misc: %{
            energy: 5.0,
            state: :live
          }
        }
        {:reply, {:success, response}, state}
      end
    end
    
    # Simulate error case
    def handle_call({:actuate, _agent_id, %{actuator_type: :unknown}}, _from, state) do
      {:reply, {:error, "Unknown actuator type"}, state}
    end
    
    # Simulate agent death
    def handle_call({:actuate, _agent_id, %{actuator_type: :two_wheels, output_vector: [0, 0]}}, _from, state) do
      response = %{
        fitness: [0.0],
        misc: %{
          energy: 0.0,
          state: :dead
        }
      }
      {:reply, {:success, response}, state}
    end
  end
  
  describe "init/7" do
    test "initializes actuator state correctly" do
      {:ok, state} = FlatlandActuator.init(
        1, 
        :two_wheels,
        2,
        self(),
        self(),
        "agent_1"
      )
      
      assert state.id == 1
      assert state.actuator_type == :two_wheels
      assert state.fanin == 2
      assert state.cortex_pid == self()
      assert state.scape_pid == self()
      assert state.agent_id == "agent_1"
      assert state.is_first_cycle == true
    end
  end
  
  describe "handle/2 with two_wheels actuator" do
    setup do
      {:ok, scape_pid} = MockScape.start_link()
      
      state = %{
        id: 1,
        actuator_type: :two_wheels,
        fanin: 2,
        cortex_pid: self(),
        scape_pid: scape_pid,
        agent_id: "agent_1",
        is_first_cycle: true
      }
      
      %{state: state}
    end
    
    test "handles wheel movements correctly - normal case", %{state: state} do
      # Move forward moderately
      output_vector = [0.3, 0.3]
      {:ok, new_state} = FlatlandActuator.handle(output_vector, state)
      
      # Should process wheel movement and update state
      assert new_state.is_first_cycle == false
      
      # Ensure no termination message was sent
      refute_received {:terminate, _}
    end
    
    test "handles wheel movements correctly - high energy case", %{state: state} do
      # Move forward fast
      output_vector = [0.9, 0.9]
      {:ok, new_state} = FlatlandActuator.handle(output_vector, state)
      
      # Should process wheel movement and update state
      assert new_state.is_first_cycle == false
      
      # Ensure no termination message was sent
      refute_received {:terminate, _}
    end
    
    test "handles agent death correctly - terminates agent", %{state: state} do
      # No movement - simulates death
      output_vector = [0.0, 0.0]
      
      # Initially it should not terminate (first cycle)
      {:ok, new_state} = FlatlandActuator.handle(output_vector, state)
      assert new_state.is_first_cycle == false
      refute_received {:terminate, _}
      
      # On second cycle it should terminate
      {:terminate, fitness} = FlatlandActuator.handle(output_vector, new_state)
      assert is_list(fitness)
      
      # Ensure termination message was sent
      assert_received {:terminate, _}
    end
  end
  
  describe "actuator factory functions" do
    test "two_wheels creates correct specification" do
      spec = FlatlandActuator.two_wheels(1, 2, :cortex_1, :scape_1)
      
      assert spec.id == 1
      assert spec.name == :flatland_two_wheels
      assert spec.module == FlatlandActuator
      assert spec.actuator_type == :two_wheels
      assert spec.fanin == 2
      assert spec.cortex_id == :cortex_1
      assert spec.scape_name == :scape_1
    end
  end
end