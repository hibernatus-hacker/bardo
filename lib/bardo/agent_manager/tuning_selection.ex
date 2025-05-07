defmodule Bardo.AgentManager.TuningSelection do
  @moduledoc """
  The TuningSelection module contains all the tuning selection functions,
  which accept as input four parameters:
  1. All NIds belonging to the NN.
  2. The agent's generation, which is the number of topological
     mutation phases that it has undergone.
  3. The perturbation range, the multiplier of math:pi(), which when
     used produces the spread value.
  4. The annealing parameter, which is used to indicate how the
     perturbation range decays with the age of the neuron to which synaptic
     weight perturbation is applied.
     
  It makes less sense to perturb the more stable elements of the NN system, 
  less so than those elements which have just recently been added to the NN system, 
  and which still need to be tuned and modified to work well with the already existing
  larger system. The concept is that of simulated annealing.
  
  We gather all these selection functions in their own module because there
  are many ways to select neurons which should be perturbed in local
  search during the tuning phase. This makes it easier for us to add new
  selection functions later on, and see if a new function can improve
  the performance.
  
  The tuning selection function must not only select the neuron ids for
  synaptic perturbation, but also compute the perturbation intensity,
  the available range of the perturbation intensity, from which the
  neuron will then randomly generate a weight perturbation value. Thus,
  the selection_function creates a list of tuples rather than simply a
  list of neuron ids. The selection_function outputs a list of the
  following form: [{NId, Spread},...], where NId is the neuron id, and
  Spread is the spread above and below 0, the value within which the
  neuron generates the actual perturbation. The Spread equals the
  perturbation_range value if there is no annealing, if annealing is
  present (annealing_parameter =< 1), then the Spread is further
  modified. The annealing factor must scale the Spread, proportional to
  the age of the neuron whose synaptic weights are to be perturbed. In
  tuning selection algorithms, the spread value is calculated as follows:
  
  `Spread = PerurbationRange * math:pi() * math:pow(AnnealingParam, NAge)`
  
  When AnnealingParameter = 1, there is no annealing. But when the
  AnnealingParameter is set to a number lower than 1, then annealing is
  exponentially proportional to the neuron's age.
  """
  
  alias Bardo.{DB, Models}
  
  @doc """
  The dynamic selection function randomly selects an age limit for
  its neuron id pool. The age limit is chosen by executing
  math:sqrt(1/rand:uniform()), which creates a value between 1 and
  infinity. Using this function there is 75% that the number will be
  =< 2, 25% that it will be >= 2, 11% that it will be >= 3...Every time
  this selection function is executed, the AgeLimit is generated anew,
  thus different times it will produce different neuron id pools for
  tuning.
  """
  @spec dynamic([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def dynamic(ids, agent_generation, perturbation_range, annealing_parameter) do
    chosen_idps(ids, agent_generation, perturbation_range, annealing_parameter)
  end
  
  @doc """
  dyanimic_random selection function composes the neuron id pool the
  same way as the dynamic/4 selection function, but after this id pool
  is generated, this selection function extracts ids from it randomly
  with a probability of 1/math:sqrt(Tot_Neurons). Thus the probability
  of a neuron being selected from this pool is proportional to the
  number of ids in that pool. If through chance no ids are selected,
  then the first element in the id pool is automatically selected, and
  given the highest spread.
  """
  @spec dynamic_random([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def dynamic_random(ids, agent_generation, perturbation_range, annealing_parameter) do
    chosen_idps = chosen_idps(ids, agent_generation, perturbation_range, annealing_parameter)
    mutation_p = 1 / :math.sqrt(length(chosen_idps))
    choose_random_idps(mutation_p, chosen_idps)
  end
  
  @doc """
  active selection algorithm composes a neuron id pool from all
  neurons who are younger than 3 generations.
  """
  @spec active([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def active(ids, agent_generation, perturbation_range, annealing_parameter) do
    extract_cur_gen_idps(ids, agent_generation, 3, perturbation_range, annealing_parameter, [])
  end
  
  @doc """
  active_random is a selection algorithm that composes an id pool by
  first creating a list of all neurons who are younger than 3
  generations, and then composing a sub list from it by randomly
  choosing elements from this list with a probability of
  1/math:sqrt(Tot_Neurons).
  """
  @spec active_random([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def active_random(ids, agent_generation, perturbation_range, annealing_parameter) do
    chosen_idps = case extract_cur_gen_idps(ids, agent_generation, 3, perturbation_range, annealing_parameter, []) do
      [] ->
        [id | _] = ids
        [{id, perturbation_range * :math.pi()}]
      extracted_idps ->
        extracted_idps
    end
    
    mutation_p = 1 / :math.sqrt(length(chosen_idps))
    choose_random_idps(mutation_p, chosen_idps)
  end
  
  @doc """
  current is a selection algorithm that returns a list of all neurons
  which have been added to the NN, or affected by mutation, during the
  last generation.
  """
  @spec current([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def current(ids, agent_generation, perturbation_range, annealing_parameter) do
    case extract_cur_gen_idps(ids, agent_generation, 0, perturbation_range, annealing_parameter, []) do
      [] ->
        [id | _] = ids
        [{id, perturbation_range * :math.pi()}]
      idps ->
        idps
    end
  end
  
  @doc """
  current_random composes the list of tuples in the same way as
  current does, but then composes a sublist by randomly selecting
  elements from that list with a probability of
  1/math:sqrt(Tot_Neurons), and returning that to the caller.
  """
  @spec current_random([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def current_random(ids, agent_generation, perturbation_range, annealing_parameter) do
    chosen_idps = current(ids, agent_generation, perturbation_range, annealing_parameter)
    mutation_p = 1 / :math.sqrt(length(chosen_idps))
    choose_random_idps(mutation_p, chosen_idps)
  end
  
  @doc """
  all returns a list of tuples composed of all ids (and their spread
  values) belonging to the NN, to the caller.
  """
  @spec all([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def all(ids, agent_generation, perturbation_range, annealing_parameter) do
    extract_cur_gen_idps(ids, agent_generation, agent_generation, perturbation_range, annealing_parameter, [])
  end
  
  @doc """
  all_random first composes a list of tuples from NIds and their
  spreads, and then creates a sublist by choosing each element with a
  probability of 1/math:sqrt(Tot_neurons).
  """
  @spec all_random([{:actuator | :neuron, {float()}}], integer(), float(), float()) ::
    [{Models.neuron_id(), float()}]
  def all_random(ids, agent_generation, perturbation_range, annealing_parameter) do
    chosen_idps = extract_cur_gen_idps(ids, agent_generation, agent_generation, perturbation_range, annealing_parameter, [])
    mutation_p = 1 / :math.sqrt(length(chosen_idps))
    choose_random_idps(mutation_p, chosen_idps)
  end
  
  # Internal functions
  
  defp chosen_idps(ids, agent_generation, perturbation_range, annealing_p) do
    age_limit = :math.sqrt(1 / :rand.uniform())
    
    case extract_cur_gen_idps(ids, agent_generation, age_limit, perturbation_range, annealing_p, []) do
      [] ->
        [id | _] = ids
        [{id, perturbation_range * :math.pi()}]
      extracted_idps ->
        extracted_idps
    end
  end
  
  # choose_random_idps accepts a mutation probability parameter and a
  # list of tuples composed of neuron ids and their spreads, and then
  # selects from this list randomly with a probability MutationP,
  # composing a new sub list.
  defp choose_random_idps(mutation_p, idps) do
    case choose_random_idps(idps, mutation_p, []) do
      [] ->
        {id, spread} = Enum.at(idps, :rand.uniform(length(idps)) - 1)
        [{id, spread}]
      acc ->
        acc
    end
  end
  
  defp choose_random_idps([{id, spread} | idps], mutation_p, acc) do
    u_acc = if :rand.uniform() < mutation_p do
      [{id, spread} | acc]
    else
      acc
    end
    
    choose_random_idps(idps, mutation_p, u_acc)
  end
  
  defp choose_random_idps([], _mutation_p, acc), do: acc
  
  # The extract_cur_gen_idps composes an id pool from neurons and
  # actuators who are younger than the AgeLimit parameter. This is
  # calculated by comparing the generation when they were created or
  # touched by mutation, with that of the agent which ages with every
  # topological mutation phase. Id pool accumulates not just the neurons
  # but also the spread which will be used for the synaptic weight
  # perturbation. The spread is calculated by multiplying the
  # perturbation_range variable by math:pi(), and then multiplied by the
  # annealing factor which is math:pow(AnnealingParameter, Age).
  # Annealing parameter is less than 1, thus the greater the age of the
  # neuron, the lower the Spread will be.
  defp extract_cur_gen_idps([id | ids], generation, age_limit, pr, ap, acc) do
    gen = case id do
      {:neuron, _} ->
        n = DB.read(id, :neuron)
        Models.get(n, :generation)
      {:actuator, _} ->
        a = DB.read(id, :actuator)
        Models.get(a, :generation)
    end
    
    if gen >= (generation - age_limit) do
      age = generation - gen
      spread = pr * :math.pi() * :math.pow(ap, age)
      extract_cur_gen_idps(ids, generation, age_limit, pr, ap, [{id, spread} | acc])
    else
      extract_cur_gen_idps(ids, generation, age_limit, pr, ap, acc)
    end
  end
  
  defp extract_cur_gen_idps([], _generation, _age_limit, _pr, _ap, acc), do: acc
end