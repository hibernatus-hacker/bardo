defmodule Bardo.Examples.Benchmarks.Dpb.DpbWDamping do
  @moduledoc """
  Morphology for the Double Pole Balancing benchmark with damping.
  
  This morphology defines the sensors and actuators for agents
  solving the DPB problem with damping, which includes
  velocity information in addition to positions.
  """
  
  alias Bardo.PopulationManager.Morphology
  alias Bardo.PopulationManager.ExtendedMorphology
  alias Bardo.Examples.Benchmarks.Dpb.{DpbSensor, DpbActuator}
  alias Bardo.Models
  
  @behaviour Morphology
  @behaviour ExtendedMorphology
  
  @doc """
  List of sensors available to the DPB agent with damping.
  
  Returns models for both position and velocity sensors.
  """
  @impl Morphology
  def sensors do
    [
      # Position sensors
      Models.sensor(%{
        id: nil,
        name: :cart_position,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      Models.sensor(%{
        id: nil,
        name: :pole1_angle,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      Models.sensor(%{
        id: nil,
        name: :pole2_angle,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      
      # Velocity sensors (included with damping)
      Models.sensor(%{
        id: nil,
        name: :cart_velocity,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      Models.sensor(%{
        id: nil,
        name: :pole1_angular_velocity,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      }),
      Models.sensor(%{
        id: nil,
        name: :pole2_angular_velocity,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
  end
  
  @doc """
  List of actuators available to the DPB agent with damping.
  
  Returns a single force actuator model.
  """
  @impl Morphology
  def actuators do
    [
      Models.actuator(%{
        id: nil,
        name: :force,
        type: :dpb,
        cx_id: nil,
        scape: nil,
        vl: 1,
        fanin_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
  end
  
  @doc """
  Get the sensor and actuator configuration for a DPB agent with damping.
  
  Returns a map with :sensors and :actuators keys.
  """
  @impl ExtendedMorphology
  def get_phys_config(_owner, cortex_id, scape_name) do
    %{
      sensors: sensors(cortex_id, scape_name),
      actuators: actuators(cortex_id, scape_name)
    }
  end
  
  @doc """
  Get the parameters required to enter the scape.
  
  Returns a map with parameters for connecting to the DPB scape.
  """
  @impl ExtendedMorphology
  def get_scape_params(_owner, _agent_id, _cortex_id, _scape_name) do
    # Currently, no specific parameters are needed for DPB
    %{}
  end
  
  @doc """
  Define the neuron pattern for DPB networks with damping.
  
  This function specifies how sensors and actuators connect to the neural network.
  """
  @impl ExtendedMorphology
  def neuron_pattern(_owner, _agent_id, _cortex_id, _neural_interface) do
    # Define the sensor to neuron index mapping
    sensor_id_to_idx_map = %{
      1 => {0, 1},    # Cart position
      2 => {1, 2},    # Pole 1 angle
      3 => {2, 3},    # Pole 2 angle
      4 => {3, 4},    # Cart velocity
      5 => {4, 5},    # Pole 1 angular velocity
      6 => {5, 6}     # Pole 2 angular velocity
    }
    
    # Define the actuator to neuron index mapping
    actuator_id_to_idx_map = %{
      7 => {0, 1}     # Force actuator
    }
    
    # Create the neuron pattern
    %{
      sensor_id_to_idx_map: sensor_id_to_idx_map,
      actuator_id_to_idx_map: actuator_id_to_idx_map,
      total_neuron_count: 6,
      output_neuron_count: 1,
      bias_as_neuron: true
    }
  end
  
  @doc """
  Define the sensors for DPB with damping.
  
  With damping includes both position and velocity sensors.
  """
  def sensors(cortex_id, scape_name) do
    [
      # Position sensors
      DpbSensor.cart_position(1, 1, cortex_id, scape_name),
      DpbSensor.pole1_angle(2, 1, cortex_id, scape_name),
      DpbSensor.pole2_angle(3, 1, cortex_id, scape_name),
      
      # Velocity sensors (included with damping)
      DpbSensor.cart_velocity(4, 1, cortex_id, scape_name),
      DpbSensor.pole1_angular_velocity(5, 1, cortex_id, scape_name),
      DpbSensor.pole2_angular_velocity(6, 1, cortex_id, scape_name)
    ]
  end
  
  @doc """
  Define the actuators for DPB with damping.
  
  Returns a list with a single force actuator.
  """
  def actuators(cortex_id, scape_name) do
    [
      # Force actuator with damping
      DpbActuator.with_damping(7, 1, cortex_id, scape_name)
    ]
  end
end