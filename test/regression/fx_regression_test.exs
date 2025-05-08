defmodule Bardo.Regression.FxRegressionTest do
  use ExUnit.Case, async: true
  
  alias Bardo.Examples.Applications.Fx
  alias Bardo.Examples.Applications.Fx.{FxSensor, FxActuator, FxMorphology}
  alias Bardo.TestSupport.MockHelper
  
  @moduletag :regression
  
  # Mock module for experiment management
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
        iterations_completed: 25,
        iterations_total: 25,
        best_fitness: [1500.5],
        best_agent_id: :mock_agent_id,
        elapsed_time: 120.5
      }
    end
    
    def get_best_agent(_experiment_id) do
      # Return a mock agent ID
      :mock_agent_id
    end
    
    def test_agent(_agent_id, _test_fn) do
      # Return mock test results for a trading strategy
      %{
        fitness: [2200.5],
        details: %{
          trades: [
            %{entry_price: 1.2050, exit_price: 1.2150, profit: 100},
            %{entry_price: 1.2200, exit_price: 1.2100, profit: -100},
            %{entry_price: 1.2150, exit_price: 1.2350, profit: 200}
          ],
          balance_history: [10000, 10100, 10000, 10200],
          win_rate: 0.66,
          profit_factor: 3.0,
          drawdown: 100
        }
      }
    end
  end
  
  # Mock module for file system operations to avoid real file operations
  defmodule MockFile do
    def exists?(path) do
      # Mock existence of FX data files
      String.ends_with?(path, ["EURUSD15.csv", "EURUSD15.txt"])
    end
    
    def read!("priv/fx_tables/EURUSD15.csv") do
      # Return a minimal mock data set for testing
      """
      date,time,open,high,low,close,volume
      20250101,000000,1.2000,1.2010,1.1990,1.2005,100
      20250101,001500,1.2005,1.2020,1.2000,1.2015,120
      20250101,003000,1.2015,1.2025,1.2010,1.2020,110
      20250101,004500,1.2020,1.2030,1.2015,1.2025,130
      """
    end
    
    def stream!("priv/fx_tables/EURUSD15.csv") do
      read!("priv/fx_tables/EURUSD15.csv")
      |> String.split("\n", trim: true)
      |> Stream.map(& &1)
    end
  end
  
  setup do
    # Redirect module calls to our mock implementations
    MockHelper.redirect_module(Bardo.PolisMgr, MockPolisMgr)
    MockHelper.override_function(File, :exists?, &MockFile.exists?/1)
    MockHelper.override_function(File, :read!, &MockFile.read!/1)
    MockHelper.override_function(File, :stream!, &MockFile.stream!/1)
    
    :ok
  end
  
  describe "Fx example" do
    test "run/1 with default parameters sets up experiment correctly" do
      # Run the FX example with default parameters
      Fx.run(:fx_test)
      
      # Verify setup was called with the correct experiment ID
      assert_received {:setup_called, :fx_test, config}
      
      # Verify configuration contains expected values
      assert config.id == :fx_test
      assert config.iterations == 50
      
      # Check that at least one scape was configured
      assert length(config.scapes) > 0
      
      # Check that at least one population was configured
      assert length(config.populations) > 0
      
      # Verify experiment was started
      assert_received {:start_called, :fx_test}
    end
    
    test "run/4 with custom parameters sets up experiment correctly" do
      # Run with custom parameters
      Fx.run(:custom_test, 20, 1000, 15)
      
      # Verify setup was called with correct experiment ID and custom parameters
      assert_received {:setup_called, :custom_test, config}
      
      # Verify custom parameters were used
      fx_scape = Enum.find(config.scapes, &(&1.name == :fx_scape))
      assert fx_scape != nil
      
      # Check that window size was configured correctly
      assert fx_scape.module_parameters.window_size == 1000
      
      # Check that population size and iterations were set correctly
      population = Enum.at(config.populations, 0)
      assert population.size == 20
      assert config.iterations == 15
      
      # Verify experiment was started
      assert_received {:start_called, :custom_test}
    end
    
    test "test_best_agent/1 retrieves and tests the best agent" do
      # Call test_best_agent
      result = Fx.test_best_agent(:fx_test)
      
      # Verify that result includes trading metrics
      assert is_map(result)
      assert is_map(result.details)
      assert is_list(result.details.trades)
      assert is_list(result.details.balance_history)
      assert is_number(result.details.win_rate)
      assert is_number(result.details.profit_factor)
      assert is_number(result.details.drawdown)
      
      # Verify our mock data is coming through
      assert result.details.win_rate == 0.66
      assert result.details.profit_factor == 3.0
    end
    
    test "configure/4 creates a valid experiment configuration" do
      # Create configuration directly
      config = Fx.configure(:config_test, 35, 2000, 30)
      
      # Verify basic configuration
      assert config.id == :config_test
      assert config.backup_frequency == 5
      assert config.iterations == 30
      
      # Check scape configuration
      assert length(config.scapes) == 1
      scape = Enum.at(config.scapes, 0)
      assert scape.name == :fx_scape
      assert scape.type == :private
      assert scape.module_parameters.window_size == 2000
      
      # Check population configuration
      assert length(config.populations) == 1
      population = Enum.at(config.populations, 0)
      assert population.id == :fx_population
      assert population.size == 35
      assert population.morphology == FxMorphology
      
      # Check selection algorithm
      assert population.selection_algorithm == "TournamentSelectionAlgorithm"
      assert population.tournament_size == 5
      assert population.elite_fraction == 0.1
      
      # Check mutation operators
      has_weight_mutation = Enum.any?(population.mutation_operators, fn op -> 
        case op do
          {:mutate_weights, :gaussian, _} -> true
          _ -> false
        end
      end)
      
      has_add_neuron = Enum.any?(population.mutation_operators, fn op -> 
        case op do
          {:add_neuron, _} -> true
          _ -> false
        end
      end)
      
      assert has_weight_mutation
      assert has_add_neuron
    end
  end
  
  describe "FxSensor" do
    test "sensor types generate correct specifications" do
      # Test creation of price chart input (PCI) sensor
      pci_spec = FxSensor.pci(1, 10, :cortex_id, :scape_name)
      assert pci_spec.id == 1
      assert pci_spec.name == :pci
      assert pci_spec.module == FxSensor
      assert pci_spec.sensor_type == :pci
      assert pci_spec.params.dimension == 10
      assert pci_spec.vl == 10
      assert pci_spec.cortex_id == :cortex_id
      assert pci_spec.scape_name == :scape_name
      
      # Test creation of price level input (PLI) sensor
      pli_spec = FxSensor.pli(2, 20, :cortex_id, :scape_name)
      assert pli_spec.id == 2
      assert pli_spec.name == :pli
      assert pli_spec.module == FxSensor
      assert pli_spec.sensor_type == :pli
      assert pli_spec.params.lookback == 20
      assert pli_spec.vl == 20
      assert pli_spec.cortex_id == :cortex_id
      assert pli_spec.scape_name == :scape_name
      
      # Test creation of internals sensor
      internals_spec = FxSensor.internals(3, :cortex_id, :scape_name)
      assert internals_spec.id == 3
      assert internals_spec.name == :internals
      assert internals_spec.module == FxSensor
      assert internals_spec.sensor_type == :internals
      assert internals_spec.vl == 5
      assert internals_spec.cortex_id == :cortex_id
      assert internals_spec.scape_name == :scape_name
    end
  end
  
  describe "FxActuator" do
    test "actuator types generate correct specifications" do
      # Test creation of trade actuator
      trade_spec = FxActuator.trade(1, 1, :cortex_id, :scape_name)
      assert trade_spec.id == 1
      assert trade_spec.name == :trade
      assert trade_spec.module == FxActuator
      assert trade_spec.actuator_type == :trade
      assert trade_spec.fanin == 1
      assert trade_spec.cortex_id == :cortex_id
      assert trade_spec.scape_name == :scape_name
    end
  end
  
  describe "FxMorphology" do
    test "morphology provides correct physical configuration" do
      # Test physical configuration
      config = FxMorphology.get_phys_config(:owner, :cortex_id, :scape_name)
      
      # Check sensors
      assert length(config.sensors) == 3
      
      pci_sensor = Enum.find(config.sensors, fn s -> s.name == :pci end)
      assert pci_sensor != nil
      assert pci_sensor.sensor_type == :pci
      
      pli_sensor = Enum.find(config.sensors, fn s -> s.name == :pli end)
      assert pli_sensor != nil
      assert pli_sensor.sensor_type == :pli
      
      internal_sensor = Enum.find(config.sensors, fn s -> s.name == :internals end)
      assert internal_sensor != nil
      assert internal_sensor.sensor_type == :internals
      
      # Check actuators
      assert length(config.actuators) == 1
      
      trade_actuator = Enum.at(config.actuators, 0)
      assert trade_actuator.name == :trade
      assert trade_actuator.actuator_type == :trade
    end
    
    test "neuron pattern creates correct mapping" do
      # Create a test neural interface
      neural_interface = %{
        sensors: [
          %{id: 1, fanout: 10}, # PCI
          %{id: 2, fanout: 20}, # PLI
          %{id: 3, fanout: 5}   # Internals
        ],
        actuators: [
          %{id: 1, fanin: 1}    # Trade
        ]
      }
      
      pattern = FxMorphology.neuron_pattern(:owner, :agent_id, :cortex_id, neural_interface)
      
      # Check total neuron count
      assert pattern.total_neuron_count == 35  # 10 + 20 + 5
      
      # Check output count
      assert pattern.output_neuron_count == 1
      
      # Check sensor mapping
      assert pattern.sensor_id_to_idx_map[1] == {0, 10}     # PCI
      assert pattern.sensor_id_to_idx_map[2] == {10, 30}    # PLI
      assert pattern.sensor_id_to_idx_map[3] == {30, 35}    # Internals
      
      # Check actuator mapping
      assert pattern.actuator_id_to_idx_map[1] == {0, 1}    # Trade
    end
  end
end