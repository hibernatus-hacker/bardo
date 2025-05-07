defmodule Bardo.AgentManager.Substrate do
  @moduledoc """
  Substrate is the module responsible for managing the connectivity between neurodes
  in a neural network. It enables patterns of connectivity to be established based on
  geometric coordinates of neurodes, allowing complex neural architectures to be developed.
  """
  
  require Logger
  
  @doc """
  Sets the synaptic weight between two neurodes.
  """
  @spec set_weight(pid(), pid(), [float()]) :: :ok
  def set_weight(substrate_pid, cep_pid, weights) do
    send(substrate_pid, {:set_weight, cep_pid, weights})
    :ok
  end
  
  @doc """
  Sets the activation bias, and connectivity expression between neurodes.
  """
  @spec set_abcn(pid(), pid(), [float()]) :: :ok
  def set_abcn(substrate_pid, cep_pid, values) do
    send(substrate_pid, {:set_abcn, cep_pid, values})
    :ok
  end
  
  @doc """
  Sets weight updates iteratively.
  """
  @spec set_iterative(pid(), pid(), [float()]) :: :ok
  def set_iterative(substrate_pid, cep_pid, values) do
    send(substrate_pid, {:set_iterative, cep_pid, values})
    :ok
  end
end