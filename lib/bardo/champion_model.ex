defmodule Bardo.Models.Champion do
  @moduledoc """
  A module for creating and manipulating champion models.
  """
  
  @doc """
  Create a champion model.
  Takes a map with champion data and returns a model
  that can be stored in the database.
  """
  def champion(data), do: %{data: data}
end