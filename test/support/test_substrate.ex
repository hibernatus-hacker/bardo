defmodule Bardo.TestSupport.TestSubstrate do
  @moduledoc """
  Test implementation of Substrate functionality.
  
  This module provides a mock implementation of Substrate functions
  for use in testing without redefining the actual Substrate module.
  """
  
  def set_weight(:substrate_pid, _, [4.1940298507462686]), do: :ok
  def set_weight(_, _, _), do: :ok
  
  def set_abcn(:substrate_pid, _, [3.14]), do: :ok
  def set_abcn(_, _, _), do: :ok
  
  def set_iterative(:substrate_pid, _, [4.1940298507462686]), do: :ok
  def set_iterative(_, _, _), do: :ok
end