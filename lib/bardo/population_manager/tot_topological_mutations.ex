defmodule Bardo.PopulationManager.TotTopologicalMutations do
  @moduledoc """
  Since there are many ways to calculate TotMutations, we create the
  tot_topological_mutations module, which can store the different
  functions which can calculate this value.
  """

  alias Bardo.{Models, DB}

  @doc """
  ncount_exponential calculates TotMutations by putting the size of
  the NN to some power Power.
  """
  @spec ncount_exponential(float(), Models.agent_id()) :: pos_integer()
  def ncount_exponential(power, agent_id) do
    a = DB.read(agent_id, :agent)
    cx = DB.read(Models.get(a, :cx_id), :cortex)
    tot_neurons = length(Models.get(cx, :neuron_ids))
    
    tot_mutations = :rand.uniform(round(:math.pow(tot_neurons, power)))
    tot_mutations
  end

  @doc """
  ncount_linear calculates TotMutations by multiplying the size of
  the NN by the value Multiplier.
  """
  @spec ncount_linear(float(), Models.agent_id()) :: float()
  def ncount_linear(multiplier, agent_id) do
    a = DB.read(agent_id, :agent)
    cx = DB.read(Models.get(a, :cx_id), :cortex)
    tot_neurons = length(Models.get(cx, :neuron_ids))
    
    tot_mutations = tot_neurons * multiplier
    tot_mutations
  end
end