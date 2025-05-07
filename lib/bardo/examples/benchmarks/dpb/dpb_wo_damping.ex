defmodule Bardo.Examples.Benchmarks.Dpb.DpbWoDamping do
  @moduledoc """
  Morphology for the Double Pole Balancing benchmark without damping.
  
  This morphology defines the sensors and actuators for agents
  solving the DPB problem without damping, which only includes
  position information but not velocities.
  """
  
  alias Bardo.PopulationManager.Morphology
  alias Bardo.PopulationManager.ExtendedMorphology
  alias Bardo.Examples.Benchmarks.Dpb.{DpbSensor, DpbActuator}
  
  @behaviour Morphology
  @behaviour ExtendedMorphology
  
  @doc """
  Returns a list of sensors for the morphology.
  
  Required by the Morphology behaviour.
  """
  @impl Morphology
  def sensors do
    [
      %{
        id: :cart_position,
        type: :dpb_sensor,
        vl: 1,
        parameters: %{sensor_type: :position}
      },
      %{
        id: :pole1_angle,
        type: :dpb_sensor,
        vl: 1,
        parameters: %{sensor_type: :angle1}
      },
      %{
        id: :pole2_angle,
        type: :dpb_sensor,
        vl: 1,
        parameters: %{sensor_type: :angle2}
      }
    ]
  end

  @doc """
  Returns a list of actuators for the morphology.
  
  Required by the Morphology behaviour.
  """
  @impl Morphology
  def actuators do
    [
      %{
        id: :force,
        type: :dpb_actuator,
        vl: 1,
        parameters: %{actuator_type: :force}
      }
    ]
  end
  
  @doc """
  Get the sensor and actuator configuration for a DPB agent without damping.
  
  Returns a map with :sensors and :actuators keys.
  """
  @impl ExtendedMorphology
  def get_phys_config(_owner, cortex_id, scape_name) do
    %{
      sensors: sensors_config(cortex_id, scape_name),
      actuators: actuators_config(cortex_id, scape_name)
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
  Define the neuron pattern for DPB networks without damping.
  
  This function specifies how sensors and actuators connect to the neural network.
  """
  @impl ExtendedMorphology
  def neuron_pattern(_owner, _agent_id, _cortex_id, _neural_interface) do
    # Define the sensor to neuron index mapping
    sensor_id_to_idx_map = %{
      1 => {0, 1},    # Cart position
      2 => {1, 2},    # Pole 1 angle
      3 => {2, 3}     # Pole 2 angle
    }
    
    # Define the actuator to neuron index mapping
    actuator_id_to_idx_map = %{
      4 => {0, 1}     # Force actuator
    }
    
    # Create the neuron pattern
    %{
      sensor_id_to_idx_map: sensor_id_to_idx_map,
      actuator_id_to_idx_map: actuator_id_to_idx_map,
      total_neuron_count: 3,
      output_neuron_count: 1,
      bias_as_neuron: true
    }
  end
  
  @doc """
  Define the sensors for DPB without damping.
  
  Without damping only includes position sensors, not velocity sensors.
  """
  def sensors_config(cortex_id, scape_name) do
    [
      # Position sensors only (no velocity sensors)
      DpbSensor.cart_position(1, 1, cortex_id, scape_name),
      DpbSensor.pole1_angle(2, 1, cortex_id, scape_name),
      DpbSensor.pole2_angle(3, 1, cortex_id, scape_name)
    ]
  end
  
  @doc """
  Define the actuators for DPB without damping.
  
  Returns a list with a single force actuator.
  """
  def actuators_config(cortex_id, scape_name) do
    [
      # Force actuator without damping
      DpbActuator.without_damping(4, 1, cortex_id, scape_name)
    ]
  end
end