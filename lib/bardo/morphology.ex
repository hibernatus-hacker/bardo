defmodule Bardo.Morphology do
  @moduledoc """
  Morphology module for the Bardo system.
  This provides stub implementations for testing.
  """
  
  def get_init_sensors(morphology) do
    case morphology do
      _ -> []  # Default empty list for testing
    end
  end
  
  def get_init_actuators(morphology) do
    case morphology do
      _ -> []  # Default empty list for testing
    end
  end
  
  def get_init_substrate_cpps(morphology, _plasticity) do
    case morphology do
      _ -> []  # Default empty list for testing
    end
  end
  
  def get_init_substrate_ceps(morphology, _plasticity) do
    case morphology do
      _ -> []  # Default empty list for testing
    end
  end
end