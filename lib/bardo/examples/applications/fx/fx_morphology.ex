defmodule Bardo.Examples.Applications.Fx.FxMorphology do
  @moduledoc """
  Morphology for the Forex (FX) trading application.
  
  This module defines the physical configuration for forex trading agents,
  including sensors for price data and actuators for executing trades.
  """
  
  alias Bardo.PopulationManager.Morphology
  alias Bardo.Examples.Applications.Fx.{FxSensor, FxActuator}
  
  @behaviour Morphology
  
  @doc """
  Get the sensor and actuator configuration for an FX trading agent.
  
  Returns a map with :sensors and :actuators keys.
  """
  @impl Morphology
  def get_phys_config(_owner, cortex_id, scape_name) do
    %{
      sensors: sensors(cortex_id, scape_name),
      actuators: actuators(cortex_id, scape_name)
    }
  end
  
  @doc """
  Get the parameters required to enter the scape.
  
  Returns a map with parameters for connecting to the FX scape.
  """
  @impl Morphology
  def get_scape_params(_owner, _agent_id, _cortex_id, _scape_name) do
    # Currently, no specific parameters are needed for the FX scape
    %{}
  end
  
  @doc """
  Define the neuron pattern for FX trading networks.
  
  This function specifies how sensors and actuators connect to the neural network.
  """
  @impl Morphology
  def neuron_pattern(_owner, _agent_id, _cortex_id, neural_interface) do
    # Extract fanout and fanin from neural interface
    sensors = neural_interface.sensors
    actuators = neural_interface.actuators
    
    # Calculate total inputs from all sensors
    sensor_fanout = Enum.reduce(sensors, 0, fn sensor, acc -> 
      sensor.fanout + acc 
    end)
    
    # Calculate total outputs for all actuators
    actuator_fanin = Enum.reduce(actuators, 0, fn actuator, acc -> 
      actuator.fanin + acc 
    end)
    
    # Define the sensor to neuron index mapping
    sensor_id_to_idx_map = create_sensor_mapping(sensors, 0)
    
    # Define the actuator to neuron index mapping
    actuator_id_to_idx_map = %{1 => {0, actuator_fanin}}
    
    # Create the neuron pattern
    %{
      sensor_id_to_idx_map: sensor_id_to_idx_map,
      actuator_id_to_idx_map: actuator_id_to_idx_map,
      total_neuron_count: sensor_fanout,
      output_neuron_count: actuator_fanin,
      bias_as_neuron: true
    }
  end
  
  @doc """
  Define the sensors for FX trading agents.
  
  Returns a list of sensor specifications.
  """
  def sensors(cortex_id, scape_name) do
    [
      # PCI (Price Chart Image) sensor
      # A 2D grid representation of price movement
      %{
        id: 1,
        name: :pci,
        module: FxSensor,
        sensor_type: :pci,
        params: %{
          dimension: 10,    # 10x10 grid
          timeframe: 30     # 30 time periods
        },
        fanout: 100,        # 10x10 = 100 outputs
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # PLI (Price List Information) sensor
      # A normalized vector of recent prices
      %{
        id: 2,
        name: :pli,
        module: FxSensor,
        sensor_type: :pli,
        params: %{
          lookback: 20       # 20 time periods of history
        },
        fanout: 20,          # 20 outputs (one per time period)
        cortex_id: cortex_id,
        scape_name: scape_name
      },
      
      # Internals sensor
      # Current trading position information
      %{
        id: 3,
        name: :internals,
        module: FxSensor,
        sensor_type: :internals,
        params: %{},
        fanout: 5,           # 5 outputs for trading state information
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    ]
  end
  
  @doc """
  Define the actuators for FX trading agents.
  
  Returns a list of actuator specifications.
  """
  def actuators(cortex_id, scape_name) do
    [
      # Trade actuator
      # Executes trading decisions (-1=short, 0=no position, 1=long)
      %{
        id: 1,
        name: :trade,
        module: FxActuator,
        actuator_type: :trade,
        fanin: 1,           # 1 input for trading decision
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    ]
  end
  
  # Helper function to create sensor ID to neuron index mapping
  defp create_sensor_mapping(sensors, start_idx) do
    Enum.reduce(sensors, {%{}, start_idx}, fn sensor, {map, idx} ->
      end_idx = idx + sensor.fanout
      updated_map = Map.put(map, sensor.id, {idx, end_idx})
      {updated_map, end_idx}
    end)
    |> elem(0)  # Return just the map
  end
end