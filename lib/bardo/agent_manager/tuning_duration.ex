defmodule Bardo.AgentManager.TuningDuration do
  @moduledoc """
  The TuningDuration module contains all the tuning duration functions,
  functions which calculate how long the tuning phase must run. The
  tuning duration function sets the max_attempts value, with the
  function format being as follows: - Input: Neuron_Ids,
  AgentGeneration - Output: Max_Attempts. The tuning duration
  function can output a constant, which is what we used thus far.
  It can output a value that is proportional to the number of neurons
  composing the NN, or it can produce a value based on the number of
  all neurons in the population.
  
  NOTE: When creating tuning duration functions that take into account
  NN's size, we must ensure that this factor skews the fitness towards
  producing smaller NN systems, not larger. We do not want to reward
  neural bloating. For example, if we create a tuning duration function
  which uses the following equation: MaxAttempts = 100 * TotNeurons, we
  will be giving an incentive for the NNs to bloat. Since just be adding
  one extra neuron, the NN has 100 extra tries to improve its fitness,
  chances are that it will be a bit more fit than its better counterparts
  which did not get as many attempts.
  
  The nsize_proportional and wsize_proportional functions have their
  exponential power parameters set to 0.5, and thus take the
  square root of the number of neurons and weights respectively. Thus,
  the NN systems which have a larger number of weights or neurons to
  optimize, will have a larger number of chances, but just barely.
  
  Hopefully, this approach will not overwrite and undermine the fitness
  function, still push towards more concise topologies, while at the same
  time provide for a few more optimization attempts to the larger
  NN based agents, which need them due to having that many more synaptic
  weight permutations which can be explored.
  """
  
  alias Bardo.Functions
  alias Bardo.DB
  alias Bardo.Models
  
  @doc """
  Returns the preset const max_attempts value.
  """
  @spec const(integer(), [Models.neuron_id()], integer()) :: integer()
  def const(parameter, _n_ids, _generation) do
    parameter # ConstMaxAttempts
  end
  
  @doc """
  Calculates the max_attempts value based on the individual agent's parameters,
  in this case the max_attempts is proportional to the agent's number of weights
  belonging to the neurons which were added or mutated within the last 3 generations.
  """
  @spec wsize_proportional(float(), [Models.neuron_id()], integer()) :: integer()
  def wsize_proportional(parameter, n_ids, generation) do
    power = parameter
    active_n_ids = extract_rec_gen_nids(n_ids, generation, 3, [])
    tot_active_neuron_weights = extract_nweight_count(active_n_ids, 0)
    round(10 + Functions.sat(:math.pow(tot_active_neuron_weights, power), 100.0, 0.0))
  end
  
  @doc """
  Calculates the max_attempts to be proportional to the number of neurons
  which were within the last 3 generations mutated or added to the NN.
  """
  @spec nsize_proportional(float(), [Models.neuron_id()], integer()) :: integer()
  def nsize_proportional(parameter, n_ids, generation) do
    power = parameter
    tot_neurons = length(extract_rec_gen_nids(n_ids, generation, 3, []))
    round(20 + Functions.sat(:math.pow(tot_neurons, power), 100.0, 0.0))
  end
  
  # Internal functions
  
  # Extracts the NIds of all neurons whose age is lower or equal to the AgeLimit.
  @spec extract_rec_gen_nids([Models.neuron_id()], integer(), integer(), [Models.neuron_id()]) :: [Models.neuron_id()]
  defp extract_rec_gen_nids([n_id | n_ids], generation, age_limit, acc) do
    n = DB.read(n_id, :neuron)
    neuron_gen = Models.get(n, :generation)
    
    if neuron_gen >= (generation - age_limit) do
      extract_rec_gen_nids(n_ids, generation, age_limit, [n_id | acc])
    else
      extract_rec_gen_nids(n_ids, generation, age_limit, acc)
    end
  end
  
  defp extract_rec_gen_nids([], _generation, _age_limit, acc), do: acc
  
  # Counts the number of weights in total belonging to the list of neuron ids
  # that the function was called with.
  @spec extract_nweight_count([Models.neuron_id()], integer()) :: integer()
  defp extract_nweight_count([n_id | rec_gen_n_ids], acc) do
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(n, :input_idps)
    tot_weights = Enum.sum(for {_i_id, weights} <- input_idps, do: length(weights))
    extract_nweight_count(rec_gen_n_ids, tot_weights + acc)
  end
  
  defp extract_nweight_count([], acc), do: acc
end