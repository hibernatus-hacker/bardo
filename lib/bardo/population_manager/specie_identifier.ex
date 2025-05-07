defmodule Bardo.PopulationManager.SpecieIdentifier do
  @moduledoc """
  The specie_identifier module is a container for the
  specie_identifier functions. By keeping all the identifier
  functions in this module, it makes it easier for us to later
  add new ones, and then simply reference them by their name.
  """

  alias Bardo.{Models, DB}

  @doc """
  Identifies species based on the number of neurons.
  """
  @spec tot_n(Models.agent_id()) :: non_neg_integer()
  def tot_n(agent_id) do
    agent = DB.read(agent_id, :agent)
    
    agent
    |> Models.get(:pattern)
    |> Enum.flat_map(fn {_layer_id, n_ids} -> n_ids end)
    |> length()
  end
end