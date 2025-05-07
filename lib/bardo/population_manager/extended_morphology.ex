defmodule Bardo.PopulationManager.ExtendedMorphology do
  @moduledoc """
  Defines an extended morphology behavior that builds on the basic Morphology
  behavior by adding additional callbacks needed for complex examples.
  
  This behavior includes additional callbacks used by the DPB, Flatland, and FX examples
  that were not in the basic Morphology behavior.
  """
  
  @doc """
  The get_phys_config callback returns the physical configuration for an agent,
  including its sensors and actuators.
  """
  @callback get_phys_config(owner :: atom(), cortex_id :: atom(), scape_name :: atom()) :: map()
  
  @doc """
  The get_scape_params callback returns the parameters required for an agent
  to enter a scape.
  """
  @callback get_scape_params(owner :: atom(), agent_id :: atom(), cortex_id :: atom(), scape_name :: atom()) :: map()
  
  @doc """
  The neuron_pattern callback defines how sensors and actuators connect to
  the neural network.
  """
  @callback neuron_pattern(owner :: atom(), agent_id :: atom(), cortex_id :: atom(), neural_interface :: atom()) :: map()
end