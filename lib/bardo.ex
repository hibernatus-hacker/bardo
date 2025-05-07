defmodule Bardo do
  @moduledoc """
  Bardo is a powerful and friendly neuroevolution library for Elixir.
  
  It's based on a topology and parameter evolving universal learning network
  originally created by Gene Sher as DXNN system in Erlang.
  
  This module serves as the main entry point for library functionality.
  """

  @doc """
  Returns the library version.
  """
  @spec version() :: String.t()
  def version do
    "0.1.0"
  end
  
  @doc """
  A simple function to say hello. Used in tests.
  """
  @spec hello() :: atom()
  def hello do
    :world
  end
end