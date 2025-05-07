defmodule Bardo.TestSupport.TestFunctions do
  @moduledoc """
  Test implementation of Functions module.
  
  This module provides implementations of functions used in tests
  without modifying the actual Functions module.
  """
  
  def cartesian([px], [py]), do: [px, py]
  def cartesian([px], [py], [a, b, c]), do: [a, b, c, px, py]
end