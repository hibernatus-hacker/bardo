defmodule Bardo.MorphologyTest do
  @moduledoc """
  Tests for the Morphology module.
  
  Note: To run these tests, you need to have all dependencies installed:
  
  ```
  mix deps.get
  ```
  
  The tests require a proper database setup as defined in config/test.exs.
  """
  
  use ExUnit.Case, async: true
  alias Bardo.Morphology
  alias Bardo.Models
  alias Bardo.TestHelper.ModelHelper
  alias Bardo.Utils

  # For tests that need a mock DB
  setup do
    # Ensure all tests have a clean state
    on_exit(fn ->
      # Clean up any test data
      :ok
    end)
    :ok
  end

  describe "new/1" do
    test "creates a new morphology with default values" do
      morphology = Morphology.new()
      
      assert Map.has_key?(morphology, :id)
      assert String.starts_with?(morphology.id, "morph_")
      assert morphology.name == "Generic Morphology"
      assert morphology.description == "A generic neural network morphology"
      assert morphology.dimensions == 2
      assert morphology.inputs == 1
      assert morphology.outputs == 1
      assert morphology.hidden_layers == [3]
      assert morphology.activation_functions == [:sigmoid]
      assert morphology.substrate_type == :cartesian
      assert morphology.connection_pattern == :feedforward
      assert morphology.plasticity == :none
      assert length(morphology.sensors) == 1
      assert length(morphology.actuators) == 1
      assert is_map(morphology.parameters)
    end

    test "creates a new morphology with custom values" do
      custom_values = %{
        name: "Custom Morphology",
        description: "A custom neural network morphology",
        dimensions: 3,
        inputs: 5,
        outputs: 2,
        hidden_layers: [10, 5],
        activation_functions: [:relu, :tanh],
        substrate_type: :hypercube,
        connection_pattern: :recurrent,
        plasticity: :iterative,
        parameters: %{learning_rate: 0.01}
      }
      
      morphology = Morphology.new(custom_values)
      
      assert Map.has_key?(morphology, :id)
      assert String.starts_with?(morphology.id, "morph_")
      assert morphology.name == "Custom Morphology"
      assert morphology.description == "A custom neural network morphology"
      assert morphology.dimensions == 3
      assert morphology.inputs == 5
      assert morphology.outputs == 2
      assert morphology.hidden_layers == [10, 5]
      assert morphology.activation_functions == [:relu, :tanh]
      assert morphology.substrate_type == :hypercube
      assert morphology.connection_pattern == :recurrent
      assert morphology.plasticity == :iterative
      assert morphology.parameters == %{learning_rate: 0.01}
    end
    
    test "creates custom sensors and actuators when provided" do
      custom_sensor = Models.sensor(%{
        name: :custom_sensor,
        type: :vision,
        vl: 100
      })
      
      custom_actuator = Models.actuator(%{
        name: :custom_actuator,
        type: :motor,
        vl: 4
      })
      
      custom_values = %{
        sensors: [custom_sensor],
        actuators: [custom_actuator]
      }
      
      morphology = Morphology.new(custom_values)
      
      assert length(morphology.sensors) == 1
      assert length(morphology.actuators) == 1
      
      sensor = List.first(morphology.sensors)
      actuator = List.first(morphology.actuators)
      
      assert ModelHelper.get_field(sensor, :name) == :custom_sensor
      assert ModelHelper.get_field(sensor, :type) == :vision
      assert ModelHelper.get_field(sensor, :vl) == 100
      
      assert ModelHelper.get_field(actuator, :name) == :custom_actuator
      assert ModelHelper.get_field(actuator, :type) == :motor
      assert ModelHelper.get_field(actuator, :vl) == 4
    end
  end

  describe "add_sensor/2" do
    test "adds a sensor to a morphology" do
      morphology = Morphology.new()
      initial_sensor_count = length(morphology.sensors)
      
      new_sensor = Models.sensor(%{
        name: :new_sensor,
        type: :vision,
        vl: 50
      })
      
      updated_morphology = Morphology.add_sensor(morphology, new_sensor)
      
      assert length(updated_morphology.sensors) == initial_sensor_count + 1
      assert List.first(updated_morphology.sensors) == new_sensor
    end
  end

  describe "add_actuator/2" do
    test "adds an actuator to a morphology" do
      morphology = Morphology.new()
      initial_actuator_count = length(morphology.actuators)
      
      new_actuator = Models.actuator(%{
        name: :new_actuator,
        type: :motor,
        vl: 3
      })
      
      updated_morphology = Morphology.add_actuator(morphology, new_actuator)
      
      assert length(updated_morphology.actuators) == initial_actuator_count + 1
      assert List.first(updated_morphology.actuators) == new_actuator
    end
  end

  describe "neuron_count/1" do
    test "calculates the correct neuron count for simple morphology" do
      morphology = Morphology.new(%{
        inputs: 2,
        hidden_layers: [3],
        outputs: 1
      })
      
      assert Morphology.neuron_count(morphology) == 6 # 2 + 3 + 1
    end
    
    test "calculates the correct neuron count for complex morphology" do
      morphology = Morphology.new(%{
        inputs: 5,
        hidden_layers: [10, 7, 4],
        outputs: 2
      })
      
      assert Morphology.neuron_count(morphology) == 28 # 5 + 10 + 7 + 4 + 2
    end
  end

  describe "get_init_sensors/1" do
    test "returns the first sensor from the morphology" do
      custom_sensor1 = Models.sensor(%{
        name: :sensor1,
        type: :vision,
        vl: 10
      })
      
      custom_sensor2 = Models.sensor(%{
        name: :sensor2,
        type: :audio,
        vl: 5
      })
      
      morphology = Morphology.new(%{
        sensors: [custom_sensor1, custom_sensor2]
      })
      
      result = Morphology.get_init_sensors(morphology)
      
      assert length(result) == 1
      sensor = List.first(result)
      assert ModelHelper.get_field(sensor, :name) == :sensor1
    end
    
    test "returns empty list for morphology with no sensors" do
      # Create a morphology and then explicitly set empty sensors
      morphology = %{Morphology.new() | sensors: []}
      
      result = Morphology.get_init_sensors(morphology)
      
      assert result == []
    end
  end

  describe "get_sensors/1" do
    test "returns all sensors from the morphology" do
      custom_sensor1 = Models.sensor(%{
        name: :sensor1,
        type: :vision,
        vl: 10
      })
      
      custom_sensor2 = Models.sensor(%{
        name: :sensor2,
        type: :audio,
        vl: 5
      })
      
      morphology = Morphology.new(%{
        sensors: [custom_sensor1, custom_sensor2]
      })
      
      result = Morphology.get_sensors(morphology)
      
      assert length(result) == 2
      names = Enum.map(result, fn s -> ModelHelper.get_field(s, :name) end)
      assert :sensor1 in names
      assert :sensor2 in names
    end
  end

  describe "get_init_actuators/1" do
    test "returns the first actuator from the morphology" do
      custom_actuator1 = Models.actuator(%{
        name: :actuator1,
        type: :motor,
        vl: 3
      })
      
      custom_actuator2 = Models.actuator(%{
        name: :actuator2,
        type: :gripper,
        vl: 1
      })
      
      morphology = Morphology.new(%{
        actuators: [custom_actuator1, custom_actuator2]
      })
      
      result = Morphology.get_init_actuators(morphology)
      
      assert length(result) == 1
      actuator = List.first(result)
      assert ModelHelper.get_field(actuator, :name) == :actuator1
    end
    
    test "returns empty list for morphology with no actuators" do
      # Create a morphology and then explicitly set empty actuators
      morphology = %{Morphology.new() | actuators: []}
      
      result = Morphology.get_init_actuators(morphology)
      
      assert result == []
    end
  end

  describe "get_actuators/1" do
    test "returns all actuators from the morphology" do
      custom_actuator1 = Models.actuator(%{
        name: :actuator1,
        type: :motor,
        vl: 3
      })
      
      custom_actuator2 = Models.actuator(%{
        name: :actuator2,
        type: :gripper,
        vl: 1
      })
      
      morphology = Morphology.new(%{
        actuators: [custom_actuator1, custom_actuator2]
      })
      
      result = Morphology.get_actuators(morphology)
      
      assert length(result) == 2
      names = Enum.map(result, fn a -> ModelHelper.get_field(a, :name) end)
      assert :actuator1 in names
      assert :actuator2 in names
    end
  end

  describe "get_substrate_cpps/1" do
    test "returns appropriate CPPs for iterative plasticity" do
      morphology = Morphology.new(%{
        dimensions: 2,
        plasticity: :iterative
      })
      
      result = Morphology.get_substrate_cpps(morphology)
      assert length(result) > 0
      
      # Should include cartesian and other CPPs
      names = Enum.map(result, fn cpp -> ModelHelper.get_field(cpp, :name) end)
      assert :cartesian in names
      assert :cartesian_coord_diffs in names
    end
    
    test "returns appropriate CPPs for none plasticity" do
      morphology = Morphology.new(%{
        dimensions: 2,
        plasticity: :none
      })
      
      result = Morphology.get_substrate_cpps(morphology)
      assert length(result) > 0
      
      # Should include cartesian but with different VL
      cartesian = Enum.find(result, fn cpp -> ModelHelper.get_field(cpp, :name) == :cartesian end)
      assert ModelHelper.get_field(cartesian, :vl) == 4 # dimensions * 2 for 2D
    end
    
    test "directly accepts dimensions and plasticity" do
      # Test with dimensions and plasticity directly
      result = Morphology.get_substrate_cpps(3, :none)
      assert length(result) > 0
      
      names = Enum.map(result, fn cpp -> ModelHelper.get_field(cpp, :name) end)
      assert :cartesian in names
      
      # Should include spherical in 3D
      assert :spherical in names
    end
  end

  describe "get_substrate_ceps/1" do
    test "returns appropriate CEPs for different plasticities" do
      iterative = Morphology.new(%{plasticity: :iterative})
      iterative_result = Morphology.get_substrate_ceps(iterative)
      assert length(iterative_result) == 1
      assert ModelHelper.get_field(List.first(iterative_result), :name) == :delta_weight
      
      abcn = Morphology.new(%{plasticity: :abcn})
      abcn_result = Morphology.get_substrate_ceps(abcn)
      assert length(abcn_result) == 1
      assert ModelHelper.get_field(List.first(abcn_result), :name) == :set_abcn
      
      none = Morphology.new(%{plasticity: :none})
      none_result = Morphology.get_substrate_ceps(none)
      assert length(none_result) == 1
      assert ModelHelper.get_field(List.first(none_result), :name) == :set_weight
    end
    
    test "directly accepts dimensions and plasticity" do
      # Test with dimensions and plasticity directly
      result = Morphology.get_substrate_ceps(2, :iterative)
      assert length(result) == 1
      assert ModelHelper.get_field(List.first(result), :name) == :delta_weight
    end
  end

  describe "get_phys_config/3" do
    test "creates proper physical configuration for sensors and actuators" do
      morphology = Morphology.new(%{
        inputs: 3,
        outputs: 2
      })
      
      cortex_id = "cx_test"
      scape_name = :test_scape
      
      result = Morphology.get_phys_config(morphology, cortex_id, scape_name)
      
      assert is_map(result)
      assert Map.has_key?(result, :sensors)
      assert Map.has_key?(result, :actuators)
      
      # Check sensors configuration
      sensors = result.sensors
      assert length(sensors) == 1
      sensor = List.first(sensors)
      assert sensor.name == :default_sensor
      assert sensor.fanout == 3
      assert sensor.cortex_id == cortex_id
      assert sensor.scape_name == scape_name
      
      # Check actuators configuration
      actuators = result.actuators
      assert length(actuators) == 1
      actuator = List.first(actuators)
      assert actuator.name == :default_actuator
      assert actuator.fanin == 2
      assert actuator.cortex_id == cortex_id
      assert actuator.scape_name == scape_name
    end
  end

  describe "neuron_pattern/4" do
    test "creates proper neuron pattern for neural network" do
      morphology = Morphology.new(%{
        inputs: 3,
        outputs: 2
      })
      
      agent_id = "agent_test"
      cortex_id = "cx_test"
      
      # Create a neural interface that would come from the sensors/actuators
      neural_interface = %{
        sensors: [
          %{id: "sensor1", fanout: 3}
        ],
        actuators: [
          %{id: "actuator1", fanin: 2}
        ]
      }
      
      result = Morphology.neuron_pattern(morphology, agent_id, cortex_id, neural_interface)
      
      assert is_map(result)
      assert Map.has_key?(result, :sensor_id_to_idx_map)
      assert Map.has_key?(result, :actuator_id_to_idx_map)
      assert Map.has_key?(result, :total_neuron_count)
      assert Map.has_key?(result, :output_neuron_count)
      
      # Verify mappings
      assert result.sensor_id_to_idx_map["sensor1"] == {0, 3}
      assert result.actuator_id_to_idx_map["actuator1"] == {0, 2}
      
      # Verify counts
      assert result.total_neuron_count == 3
      assert result.output_neuron_count == 2
      
      # Verify bias setting
      assert result.bias_as_neuron == true
    end
  end
end