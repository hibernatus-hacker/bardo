defmodule Bardo.PopulationManager.MorphologyTest do
  use ExUnit.Case, async: true
  alias Bardo.PopulationManager.Morphology
  alias Bardo.Models
  alias Bardo.TestHelper.ModelHelper

  # Mock module to test the callbacks
  defmodule TestMorphology do
    @behaviour Bardo.PopulationManager.Morphology

    @impl true
    def sensors do
      [
        Models.sensor(%{
          id: nil,
          name: :test_sensor_1,
          type: :test,
          cx_id: nil,
          scape: nil,
          vl: 3,
          fanout_ids: [],
          generation: nil,
          format: nil,
          parameters: nil
        }),
        Models.sensor(%{
          id: nil,
          name: :test_sensor_2,
          type: :test,
          cx_id: nil,
          scape: nil,
          vl: 2,
          fanout_ids: [],
          generation: nil,
          format: nil,
          parameters: nil
        })
      ]
    end

    @impl true
    def actuators do
      [
        Models.actuator(%{
          id: nil,
          name: :test_actuator_1,
          type: :test,
          cx_id: nil,
          scape: nil,
          vl: 1,
          fanin_ids: [],
          generation: nil,
          format: nil,
          parameters: nil
        }),
        Models.actuator(%{
          id: nil,
          name: :test_actuator_2,
          type: :test,
          cx_id: nil,
          scape: nil,
          vl: 2,
          fanin_ids: [],
          generation: nil,
          format: nil,
          parameters: nil
        })
      ]
    end
  end

  describe "get_init_sensors/1" do
    test "returns only the first sensor from the morphology" do
      result = Morphology.get_init_sensors(TestMorphology)
      assert length(result) == 1
      sensor = List.first(result)
      assert ModelHelper.get_field(sensor, :name) == :test_sensor_1
    end
  end

  describe "get_init_actuators/1" do
    test "returns only the first actuator from the morphology" do
      result = Morphology.get_init_actuators(TestMorphology)
      assert length(result) == 1
      actuator = List.first(result)
      assert ModelHelper.get_field(actuator, :name) == :test_actuator_1
    end
  end

  describe "get_sensors/1" do
    test "returns all sensors from the morphology" do
      result = Morphology.get_sensors(TestMorphology)
      assert length(result) == 2
      names = Enum.map(result, fn s -> ModelHelper.get_field(s, :name) end)
      assert :test_sensor_1 in names
      assert :test_sensor_2 in names
    end
  end

  describe "get_actuators/1" do
    test "returns all actuators from the morphology" do
      result = Morphology.get_actuators(TestMorphology)
      assert length(result) == 2
      names = Enum.map(result, fn a -> ModelHelper.get_field(a, :name) end)
      assert :test_actuator_1 in names
      assert :test_actuator_2 in names
    end
  end

  describe "get_substrate_cpps/2" do
    test "returns appropriate substrate connection point processes for iterative plasticity" do
      result = Morphology.get_substrate_cpps(2, :iterative)
      assert length(result) > 0
      
      # Should include cartesian and other CPPs
      names = Enum.map(result, fn cpp -> ModelHelper.get_field(cpp, :name) end)
      assert :cartesian in names
      assert :cartesian_coord_diffs in names
    end
    
    test "returns appropriate substrate connection point processes for none plasticity" do
      result = Morphology.get_substrate_cpps(2, :none)
      assert length(result) > 0
      
      # Should include cartesian and other CPPs but without the extra 3 in vector length
      cartesian = Enum.find(result, fn cpp -> ModelHelper.get_field(cpp, :name) == :cartesian end)
      assert ModelHelper.get_field(cartesian, :vl) == 4 # dimensions * 2 for 2D
    end
  end

  describe "get_substrate_ceps/2" do
    test "returns appropriate substrate connection endpoint processes for different plasticities" do
      iterative_result = Morphology.get_substrate_ceps(2, :iterative)
      assert length(iterative_result) == 1
      assert ModelHelper.get_field(List.first(iterative_result), :name) == :delta_weight
      
      abcn_result = Morphology.get_substrate_ceps(2, :abcn)
      assert length(abcn_result) == 1
      assert ModelHelper.get_field(List.first(abcn_result), :name) == :set_abcn
      
      none_result = Morphology.get_substrate_ceps(2, :none)
      assert length(none_result) == 1
      assert ModelHelper.get_field(List.first(none_result), :name) == :set_weight
    end
  end
end