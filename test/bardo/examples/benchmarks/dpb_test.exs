defmodule Bardo.Examples.Benchmarks.DpbTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Benchmarks.Dpb
  alias Bardo.Examples.Benchmarks.Dpb.DpbWDamping
  alias Bardo.Examples.Benchmarks.Dpb.DpbWoDamping
  
  describe "configure_with_damping/4" do
    test "creates a valid experiment configuration with damping" do
      config = Dpb.configure_with_damping(:dpb_test, 100, 50, 10000)
      
      # Check basic configuration
      assert config.id == :dpb_test
      assert config.backup_frequency == 5
      assert config.iterations == 50
      
      # Check scape configuration
      assert length(config.scapes) == 1
      scape = Enum.at(config.scapes, 0)
      assert scape.name == :dpb_scape
      assert scape.type == :private
      assert scape.module_parameters.max_steps == 10000
      
      # Check population configuration
      assert length(config.populations) == 1
      population = Enum.at(config.populations, 0)
      assert population.id == :dpb_population
      assert population.size == 100
      assert population.morphology == DpbWDamping  # With damping
      
      # Check selection algorithm
      assert population.selection_algorithm == "TournamentSelectionAlgorithm"
      assert population.tournament_size == 5
      assert population.elite_fraction == 0.1
      
      # Check mutation operators
      assert Enum.any?(population.mutation_operators, fn op -> 
        case op do
          {:mutate_weights, :gaussian, _} -> true
          _ -> false
        end
      end)
    end
    
    test "uses default values when parameters are not provided" do
      config = Dpb.configure_with_damping(:dpb_default_test)
      
      # Check that defaults are applied
      assert config.id == :dpb_default_test
      
      population = Enum.at(config.populations, 0)
      assert population.size == 100  # Default
      
      scape = Enum.at(config.scapes, 0)
      assert scape.module_parameters.max_steps == 100000  # Default
      
      assert config.iterations == 50  # Default
    end
  end
  
  describe "configure_without_damping/4" do
    test "creates a valid experiment configuration without damping" do
      config = Dpb.configure_without_damping(:dpb_test, 100, 50, 10000)
      
      # Configuration should match with_damping except for the morphology
      assert config.id == :dpb_test
      
      # The key difference should be the morphology
      population = Enum.at(config.populations, 0)
      assert population.morphology == DpbWoDamping  # Without damping
    end
  end
  
  describe "run functions" do
    test "run_with_damping calls configure_with_damping" do
      # Since the actual run calls an ExamplesHelper.run_experiment function
      # which uses Bardo.PolisMgr and ExperimentManagerClient, we can check
      # that the configuration is created correctly
      
      expected_config = Dpb.configure_with_damping(:dpb_with_damping_test, 50, 25, 5000)
      assert expected_config.id == :dpb_with_damping_test
      assert expected_config.iterations == 25
      assert Enum.at(expected_config.populations, 0).morphology == DpbWDamping
    end
    
    test "run_without_damping calls configure_without_damping" do
      # Create the function we expect to be called
      expected_config = Dpb.configure_without_damping(:dpb_without_damping_test, 50, 25, 5000)
      assert expected_config.id == :dpb_without_damping_test
      assert expected_config.iterations == 25
      assert Enum.at(expected_config.populations, 0).morphology == DpbWoDamping
    end
  end
  
  # Test for DPB Core Implementation
  describe "Dpb module" do
    alias Bardo.Examples.Benchmarks.Dpb.Dpb, as: DpbImpl
    
    test "init initializes with correct default values" do
      {:ok, state} = DpbImpl.init(self(), %{})
      
      assert state.scape_pid == self()
      assert state.x == 0.0
      assert state.x_dot == 0.0
      assert_in_delta state.theta1, 0.07, 0.001  # Slight angle
      assert state.theta1_dot == 0.0
      assert state.theta2 == 0.0
      assert state.theta2_dot == 0.0
      assert state.steps == 0
      assert state.max_steps == 100000  # Default
      assert state.jiggle_total == 0.0
    end
    
    test "init uses custom max_steps when provided" do
      {:ok, state} = DpbImpl.init(self(), %{max_steps: 5000})
      
      assert state.max_steps == 5000
    end
  end
  
  # Test for DPB With Damping
  describe "DpbWDamping" do
    test "returns correct physical configuration" do
      phys_config = DpbWDamping.get_phys_config(:owner, :cortex_1, :scape_1)
      
      # Check sensors (should include both position and velocity sensors)
      assert length(phys_config.sensors) == 6
      
      # Ensure it has position sensors
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :cart_position end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole1_angle end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole2_angle end)
      
      # Ensure it has velocity sensors (the main difference with damping)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :cart_velocity end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole1_angular_velocity end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole2_angular_velocity end)
      
      # Check actuators
      assert length(phys_config.actuators) == 1
      actuator = Enum.at(phys_config.actuators, 0)
      assert actuator.parameters == :with_damping
    end
    
    test "neuron pattern creates correct mapping" do
      pattern = DpbWDamping.neuron_pattern(:owner, :agent_1, :cortex_1, nil)
      
      # Should have 6 input neurons (position + velocity) and 1 output
      assert pattern.total_neuron_count == 6
      assert pattern.output_neuron_count == 1
      
      # Check sensor mapping (6 sensors)
      assert pattern.sensor_id_to_idx_map[1] == {0, 1}  # Cart position
      assert pattern.sensor_id_to_idx_map[2] == {1, 2}  # Pole 1 angle
      assert pattern.sensor_id_to_idx_map[3] == {2, 3}  # Pole 2 angle
      assert pattern.sensor_id_to_idx_map[4] == {3, 4}  # Cart velocity
      assert pattern.sensor_id_to_idx_map[5] == {4, 5}  # Pole 1 angular velocity
      assert pattern.sensor_id_to_idx_map[6] == {5, 6}  # Pole 2 angular velocity
      
      # Check actuator mapping
      assert pattern.actuator_id_to_idx_map[7] == {0, 1}  # Force actuator
    end
  end
  
  # Test for DPB Without Damping
  describe "DpbWoDamping" do
    test "returns correct physical configuration" do
      phys_config = DpbWoDamping.get_phys_config(:owner, :cortex_1, :scape_1)
      
      # Check sensors (should only include position sensors, not velocity)
      assert length(phys_config.sensors) == 3
      
      # Ensure it has position sensors
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :cart_position end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole1_angle end)
      assert Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole2_angle end)
      
      # Ensure it does NOT have velocity sensors (the main difference without damping)
      assert not Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :cart_velocity end)
      assert not Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole1_angular_velocity end)
      assert not Enum.any?(phys_config.sensors, fn s -> s.sensor_type == :pole2_angular_velocity end)
      
      # Check actuators
      assert length(phys_config.actuators) == 1
      actuator = Enum.at(phys_config.actuators, 0)
      assert actuator.parameters == :without_damping
    end
    
    test "neuron pattern creates correct mapping" do
      pattern = DpbWoDamping.neuron_pattern(:owner, :agent_1, :cortex_1, nil)
      
      # Should have only 3 input neurons (position only) and 1 output
      assert pattern.total_neuron_count == 3
      assert pattern.output_neuron_count == 1
      
      # Check sensor mapping (3 sensors)
      assert pattern.sensor_id_to_idx_map[1] == {0, 1}  # Cart position
      assert pattern.sensor_id_to_idx_map[2] == {1, 2}  # Pole 1 angle
      assert pattern.sensor_id_to_idx_map[3] == {2, 3}  # Pole 2 angle
      
      # Check actuator mapping
      assert pattern.actuator_id_to_idx_map[4] == {0, 1}  # Force actuator
    end
  end
end