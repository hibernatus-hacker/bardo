defmodule Bardo.Examples.Applications.FxTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Applications.Fx
  alias Bardo.Examples.Applications.Fx.FxMorphology
  
  describe "configure/4" do
    test "creates a valid experiment configuration" do
      config = Fx.configure(:fx_test, 50, 5000, 25)
      
      # Check basic configuration
      assert config.id == :fx_test
      assert config.backup_frequency == 5
      assert config.iterations == 25
      
      # Check scape configuration
      assert length(config.scapes) == 1
      scape = Enum.at(config.scapes, 0)
      assert scape.name == :fx_scape
      assert scape.type == :private
      assert scape.module_parameters.window_size == 5000
      
      # Check population configuration
      assert length(config.populations) == 1
      population = Enum.at(config.populations, 0)
      assert population.id == :fx_population
      assert population.size == 50
      assert population.morphology == FxMorphology
      
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
      
      assert Enum.any?(population.mutation_operators, fn op -> 
        case op do
          {:add_neuron, _} -> true
          _ -> false
        end
      end)
    end
    
    test "uses default values when parameters are not provided" do
      config = Fx.configure(:fx_default_test)
      
      # Check that defaults are applied
      assert config.id == :fx_default_test
      
      population = Enum.at(config.populations, 0)
      assert population.size == 50  # Default
      
      scape = Enum.at(config.scapes, 0)
      assert scape.module_parameters.window_size == 5000  # Default
      
      assert config.iterations == 50  # Default
    end
  end
  
  # Mock PolisMgr and ExperimentManagerClient for run tests
  defmodule MockPolisMgr do
    def setup(config) do
      send(self(), {:setup_called, config.id})
      {:ok, %{id: config.id}}
    end
  end
  
  defmodule MockExperimentManagerClient do
    def start(experiment_id) do
      send(self(), {:start_called, experiment_id})
      :ok
    end
  end
  
  describe "run/4 using mocks" do
    test "sets up and starts the experiment" do
      # Save original modules
      _original_polis_mgr = Bardo.PolisMgr
      _original_exp_mgr_client = Bardo.ExperimentManager.ExperimentManagerClient
      
      # Replace with mocks
      :code.unstick_mod(Bardo.PolisMgr)
      :code.purge(Bardo.PolisMgr)
      :code.delete(Bardo.PolisMgr)
      Code.eval_string("""
        defmodule Bardo.PolisMgr do
          def setup(config) do
            send(self(), {:setup_called, config.id})
            {:ok, %{id: config.id}}
          end
        end
      """)
      
      :code.unstick_mod(Bardo.ExperimentManager.ExperimentManagerClient)
      :code.purge(Bardo.ExperimentManager.ExperimentManagerClient)
      :code.delete(Bardo.ExperimentManager.ExperimentManagerClient)
      Code.eval_string("""
        defmodule Bardo.ExperimentManager.ExperimentManagerClient do
          def start(experiment_id) do
            send(self(), {:start_called, experiment_id})
            :ok
          end
        end
      """)
      
      # Run the test
      Fx.run(:fx_run_test, 20, 1000, 10)
      
      # Check if the right functions were called
      assert_received {:setup_called, :fx_run_test}
      assert_received {:start_called, :fx_run_test}
      
      # Restore original modules (cleanup)
      :code.unstick_mod(Bardo.PolisMgr)
      :code.purge(Bardo.PolisMgr)
      :code.delete(Bardo.PolisMgr)
      :code.unstick_mod(Bardo.ExperimentManager.ExperimentManagerClient)
      :code.purge(Bardo.ExperimentManager.ExperimentManagerClient)
      :code.delete(Bardo.ExperimentManager.ExperimentManagerClient)
    end
  end
  
  # Test for FX Morphology
  describe "FxMorphology" do
    test "returns correct physical configuration" do
      phys_config = FxMorphology.get_phys_config(:owner, :cortex_1, :scape_1)
      
      # Check sensors
      assert length(phys_config.sensors) == 3
      
      pci_sensor = Enum.find(phys_config.sensors, fn s -> s.name == :pci end)
      assert pci_sensor.sensor_type == :pci
      assert pci_sensor.params.dimension == 10
      assert pci_sensor.fanout == 100
      
      pli_sensor = Enum.find(phys_config.sensors, fn s -> s.name == :pli end)
      assert pli_sensor.sensor_type == :pli
      assert pli_sensor.params.lookback == 20
      assert pli_sensor.fanout == 20
      
      internal_sensor = Enum.find(phys_config.sensors, fn s -> s.name == :internals end)
      assert internal_sensor.sensor_type == :internals
      assert internal_sensor.fanout == 5
      
      # Check actuators
      assert length(phys_config.actuators) == 1
      
      trade_actuator = Enum.at(phys_config.actuators, 0)
      assert trade_actuator.name == :trade
      assert trade_actuator.actuator_type == :trade
      assert trade_actuator.fanin == 1
    end
    
    test "neuron pattern creates correct mapping" do
      # Create a mock neural interface
      neural_interface = %{
        sensors: [
          %{id: 1, fanout: 100},  # PCI
          %{id: 2, fanout: 20},   # PLI
          %{id: 3, fanout: 5}     # Internals
        ],
        actuators: [
          %{id: 1, fanin: 1}      # Trade
        ]
      }
      
      pattern = FxMorphology.neuron_pattern(:owner, :agent_1, :cortex_1, neural_interface)
      
      # Total inputs should be sum of all sensor outputs
      assert pattern.total_neuron_count == 125  # 100 + 20 + 5
      
      # Output count should match actuator inputs
      assert pattern.output_neuron_count == 1
      
      # Check sensor mapping
      assert pattern.sensor_id_to_idx_map[1] == {0, 100}     # PCI
      assert pattern.sensor_id_to_idx_map[2] == {100, 120}   # PLI
      assert pattern.sensor_id_to_idx_map[3] == {120, 125}   # Internals
      
      # Check actuator mapping
      assert pattern.actuator_id_to_idx_map[1] == {0, 1}     # Trade
    end
  end
end