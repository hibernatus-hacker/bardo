defmodule Bardo.Examples.Applications.Flatland.Predator do
  @moduledoc """
  Predator morphology for the Flatland simulation.
  
  This module defines the neural architecture and sensors/actuators
  for predator agents in the Flatland environment.
  """
  
  alias Bardo.PopulationManager.Morphology
  alias Bardo.Examples.Applications.Flatland.FlatlandSensor
  alias Bardo.Examples.Applications.Flatland.FlatlandActuator
  
  @behaviour Morphology
  
  @doc """
  Initialize the predator morphology.
  
  Returns the sensor and actuator configuration for predator agents.
  """
  @impl Morphology
  def get_phys_config(_owner, cortex_id, scape_name) do
    # Define sensor configurations
    sensors = [
      # Distance scanner with 5 rays
      FlatlandSensor.distance_scanner(1, 5, 5, cortex_id, scape_name),
      
      # Color scanner with 5 rays
      FlatlandSensor.color_scanner(2, 5, 5, cortex_id, scape_name)
    ]
    
    # Define actuator configuration (two-wheel movement)
    actuators = [
      FlatlandActuator.two_wheels(3, 2, cortex_id, scape_name)
    ]
    
    # Return the complete physical configuration
    %{
      sensors: sensors,
      actuators: actuators
    }
  end
  
  @doc """
  Get the parameters required to enter the scape.
  
  For predator agents, we specify the type as :predator.
  """
  @impl Morphology
  def get_scape_params(_owner, _agent_id, _cortex_id, _scape_name) do
    %{
      type: :predator
    }
  end
  
  @doc """
  Generate the initial neuron patterns for the predator.
  
  Returns a template for the neural network architecture.
  """
  @impl Morphology
  def neuron_pattern(_owner, _agent_id, _cortex_id, _neural_interface) do
    # Define the basic features for constructing the neural network
    # These can be expanded based on the needs of the predator's behavior
    %{
      sensor_id_to_idx_map: %{
        1 => {0, 5},    # Distance scanner: neurons 0-4
        2 => {5, 10}    # Color scanner: neurons 5-9
      },
      actuator_id_to_idx_map: %{
        3 => {0, 2}     # Two-wheel actuator: output neurons 0-1
      },
      total_neuron_count: 10, # Total neurons in the network
      output_neuron_count: 2, # Number of output neurons
      bias_as_neuron: true    # Whether to use a bias neuron
    }
  end
end