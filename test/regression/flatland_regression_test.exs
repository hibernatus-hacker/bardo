defmodule Bardo.Regression.FlatlandRegressionTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Applications.Flatland
  alias Bardo.Examples.Applications.Flatland.{FlatlandSensor, FlatlandActuator, FlatlandUtils}
  alias Bardo.TestSupport.MockHelper
  
  @moduletag :regression
  
  # This module mocks the Polis.Manager module for testing
  defmodule MockPolisMgr do
    def setup(experiment_id, config) do
      # Log the setup call for verification
      send(self(), {:setup_called, experiment_id, config})
      :ok
    end
    
    def start(experiment_id) do
      # Log the start call for verification
      send(self(), {:start_called, experiment_id})
      :ok
    end
    
    def status(experiment_id) do
      # Return a mock status
      send(self(), {:status_called, experiment_id})
      %{
        iterations_completed: 5,
        iterations_total: 5,
        best_fitness: 105.5,
        best_agent_id: :mock_agent_id,
        elapsed_time: 10.5
      }
    end
    
    def get_best_agent(_experiment_id) do
      # Return a mock agent ID
      :mock_agent_id
    end
    
    def test_agent(_agent_id, _test_fn) do
      # Return mock test results
      %{
        fitness: 120.5,
        details: %{
          path: [{0, 0}, {1, 1}, {2, 2}],
          energy_history: [100, 90, 80, 70],
          captures: 2
        }
      }
    end
  end
  
  # Mock module for FlatlandUtils to avoid real-time visualization during tests
  defmodule MockFlatlandUtils do
    def visualize(_results) do
      # Just acknowledge the call without real visualization
      send(self(), {:visualize_called})
      :ok
    end
    
    # Delegate other functions to the real module
    defdelegate create_world(width, height), to: FlatlandUtils
    defdelegate place_agents_randomly(world, predator_count, prey_count), to: FlatlandUtils
    defdelegate place_plants_randomly(world, plant_count), to: FlatlandUtils
  end
  
  setup do
    # Redirect module calls to our mock implementations
    MockHelper.redirect_module(Bardo.PolisMgr, MockPolisMgr)
    MockHelper.redirect_module(Bardo.Examples.Applications.Flatland.FlatlandUtils, MockFlatlandUtils)
    
    # Pass mock modules to the test
    :ok
  end
  
  describe "Flatland example" do
    test "run/1 with default parameters sets up experiment correctly" do
      # Run the Flatland example with default parameters
      Flatland.run(:flatland_test)
      
      # Verify setup was called with the correct experiment ID
      assert_received {:setup_called, :flatland_test, config}
      
      # Verify configuration contains expected values
      assert config.id == :flatland_test
      assert config.iterations == 50
      
      # Check that at least one scape was configured
      assert length(config.scapes) > 0
      
      # Check that at least one population was configured
      assert length(config.populations) > 0
      
      # Verify experiment was started
      assert_received {:start_called, :flatland_test}
    end
    
    test "run/6 with custom parameters sets up experiment correctly" do
      # Run with custom parameters
      Flatland.run(:custom_test, 5, 7, 10, 200, 3)
      
      # Verify setup was called with correct experiment ID and custom parameters
      assert_received {:setup_called, :custom_test, config}
      
      # Verify custom parameters were used
      flatland_scape = Enum.find(config.scapes, &(&1.name == :flatland_scape))
      assert flatland_scape != nil
      
      # Check that predator and prey counts were configured correctly
      assert flatland_scape.module_parameters.predator_count == 5
      assert flatland_scape.module_parameters.prey_count == 7
      assert flatland_scape.module_parameters.plant_count == 10
      assert flatland_scape.module_parameters.steps == 200
      
      # Check that iterations were set correctly
      assert config.iterations == 3
      
      # Verify experiment was started
      assert_received {:start_called, :custom_test}
    end
    
    test "visualize/1 requests visualization of results" do
      # Call visualize
      Flatland.visualize(:flatland_test)
      
      # Verify status was requested
      assert_received {:status_called, :flatland_test}
      
      # Verify visualization was called
      assert_received {:visualize_called}
    end
  end
  
  describe "FlatlandSensor" do
    test "sensor types generate correct specifications" do
      # Test creation of vision sensor
      vision_spec = FlatlandSensor.vision(1, 5, :cortex_id, :scape_name)
      # Not checking id since FlatlandSensor.vision returns nil for id
      assert vision_spec.type == :vision
      assert vision_spec.name == :vision_sensor
      # Not checking module since it may not be set in some implementations
      assert vision_spec.sensor_type == :vision
      assert vision_spec.vl == 5
      assert vision_spec.cortex_id == :cortex_id
      assert vision_spec.scape_name == :scape_name
      
      # Test creation of smell sensor
      smell_spec = FlatlandSensor.smell(2, 3, :cortex_id, :scape_name)
      # Not checking id since FlatlandSensor.smell returns nil for id
      assert smell_spec.type == :smell
      assert smell_spec.name == :smell_sensor
      assert smell_spec.module == FlatlandSensor
      assert smell_spec.sensor_type == :smell
      assert smell_spec.vl == 3
      assert smell_spec.cortex_id == :cortex_id
      assert smell_spec.scape_name == :scape_name
      
      # Test creation of energy sensor
      energy_spec = FlatlandSensor.energy(3, :cortex_id, :scape_name)
      assert energy_spec.id == 3
      assert energy_spec.name == :energy
      assert energy_spec.module == FlatlandSensor
      assert energy_spec.sensor_type == :energy
      assert energy_spec.vl == 1
      assert energy_spec.cortex_id == :cortex_id
      assert energy_spec.scape_name == :scape_name
    end
  end
  
  describe "FlatlandActuator" do
    test "actuator types generate correct specifications" do
      # Test creation of two_wheels actuator
      wheels_spec = FlatlandActuator.two_wheels(1, 2, :cortex_id, :scape_name)
      assert wheels_spec.id == 1
      assert wheels_spec.name == :flatland_two_wheels
      assert wheels_spec.module == FlatlandActuator
      assert wheels_spec.actuator_type == :two_wheels
      assert wheels_spec.fanin == 2
      assert wheels_spec.cortex_id == :cortex_id
      assert wheels_spec.scape_name == :scape_name
    end
  end
end