defmodule Bardo.TestSupport.TestNeuron do
  @moduledoc """
  Test implementation of Neuron functionality.
  
  This module provides a mock implementation of Neuron functions
  for use in testing without redefining the actual Neuron module.
  """
  
  def forward(:from_pid, _, [3.14, 6.28]), do: :ok
  def forward(:from_pid, _, [1.3, 2.4, 1.3, 3.14, 6.28]), do: :ok
  def forward(_, _, _), do: :ok
end