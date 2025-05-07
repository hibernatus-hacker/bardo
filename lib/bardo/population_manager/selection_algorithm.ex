defmodule Bardo.PopulationManager.SelectionAlgorithm do
  @moduledoc """
  The SelectionAlgorithm module is a container for the
  selection_algorithm functions. By keeping all the selection
  functions in this module, it makes it easier for us to later
  add new ones, and then simply reference them by their name.
  """

  alias Bardo.{Models, DB}
  alias Bardo.PopulationManager.{Genotype, GenomeMutator}

  @doc """
  Implementation of the 'hof_competition' selection algorithm.
  """
  @spec hof_competition(Models.specie_id(), [Models.champion()], non_neg_integer()) :: :ok
  def hof_competition(specie_id, remaining_champion_designators, specie_size_limit) do
    s = DB.read(specie_id, :specie)
    shof = Models.get(s, :hall_of_fame)
    shof_ratio = AppConfig.get_env(:shof_ratio)
    eff = AppConfig.get_env(:selection_algorithm_efficiency)
    
    new_gen_ids = if shof_ratio < 1 do
      actives = remaining_champion_designators
      shof_fitness_scaled = fitness_scaled(shof, eff)
      active_fitness_scaled = fitness_scaled(actives, eff)
      tot_fitness_actives = Enum.sum(for {main_fitness, _id} <- active_fitness_scaled, do: main_fitness)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_fitness_scaled, do: main_fitness)
      
      next_generation(specie_id, active_fitness_scaled, shof_fitness_scaled,
                    tot_fitness_actives, tot_fitness_shofs, shof_ratio, specie_size_limit)
    else
      allotments = fitness_scaled(shof, eff)
      tot = Enum.sum(for {main_fitness, _id} <- allotments, do: main_fitness)
      
      choose_winners(specie_id, allotments, tot, [], [], specie_size_limit)
    end
    
    # Insert new agents into active_agents ETS table
    Enum.each(new_gen_ids, fn {:agent, u_id} -> 
      :ets.insert(:active_agents, {u_id, :agent, specie_id}) 
    end)
    
    :ok
  end

  @doc """
  Implementation of the 'hof_rank' selection algorithm.
  """
  @spec hof_rank(Models.specie_id(), [Models.agent_id()], non_neg_integer()) :: :ok
  def hof_rank(specie_id, remaining_champion_designators, specie_size_limit) do
    s = DB.read(specie_id, :specie)
    DB.write(Models.set(s, [{:agent_ids, []}]), :specie)
    
    shof = Models.get(s, :hall_of_fame)
    shof_ratio = AppConfig.get_env(:shof_ratio)
    
    new_gen_ids = if shof_ratio < 1 do
      actives = remaining_champion_designators
      actives_ranked = rank(actives)
      shof_ranked = rank(shof)
      tot_fitness_actives = Enum.sum(for {main_fitness, _id} <- actives_ranked, do: main_fitness)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_ranked, do: main_fitness)
      
      next_generation(specie_id, actives_ranked, shof_ranked, tot_fitness_actives,
                    tot_fitness_shofs, shof_ratio, specie_size_limit)
    else
      shof = Models.get(s, :hall_of_fame)
      allotments = rank(shof)
      tot = Enum.sum(for {val, _id} <- allotments, do: val)
      
      choose_winners(specie_id, allotments, tot, [], [], specie_size_limit)
    end
    
    # Insert new agents into active_agents ETS table
    Enum.each(new_gen_ids, fn {:agent, u_id} -> 
      :ets.insert(:active_agents, {u_id, :agent, specie_id}) 
    end)
    
    :ok
  end

  @doc """
  Implementation of the 'hof_top3' selection algorithm.
  """
  @spec hof_top3(Models.specie_id(), [Models.agent_id()], non_neg_integer()) :: :ok
  def hof_top3(specie_id, _remaining_champion_designators, specie_size_limit) do
    s = DB.read(specie_id, :specie)
    DB.write(Models.set(s, [{:agent_ids, []}]), :specie)
    
    shof = Models.get(s, :hall_of_fame)
    allotments = 
      shof
      |> sort_champs()
      |> Enum.reverse()
      |> Enum.take(3)
      
    tot = Enum.sum(for {val, _id} <- allotments, do: val)
    
    new_gen_ids = choose_winners(specie_id, allotments, tot, [], [], specie_size_limit)
    
    # Insert new agents into active_agents ETS table
    Enum.each(new_gen_ids, fn {:agent, u_id} -> 
      :ets.insert(:active_agents, {u_id, :agent, specie_id}) 
    end)
    
    :ok
  end

  @doc """
  Implementation of the 'hof_efficiency' selection algorithm.
  """
  @spec hof_efficiency(Models.specie_id(), [Models.agent_id()], non_neg_integer()) :: :ok
  def hof_efficiency(specie_id, remaining_champion_designators, specie_size_limit) do
    s = DB.read(specie_id, :specie)
    DB.write(Models.set(s, [{:agent_ids, []}]), :specie)
    
    shof = Models.get(s, :hall_of_fame)
    shof_ratio = AppConfig.get_env(:shof_ratio)
    
    new_gen_ids = if shof_ratio < 1 do
      actives = remaining_champion_designators
      active_neural_eff_scaled = neural_eff_scaled(actives)
      shof_neural_eff_scaled = neural_eff_scaled(shof)
      tot_fitness_actives = Enum.sum(for {main_fitness, _id} <- active_neural_eff_scaled, do: main_fitness)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_neural_eff_scaled, do: main_fitness)
      
      next_generation(specie_id, active_neural_eff_scaled, shof_neural_eff_scaled,
                    tot_fitness_actives, tot_fitness_shofs, shof_ratio, specie_size_limit)
    else
      shof_neural_eff_scaled = neural_eff_scaled(shof)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_neural_eff_scaled, do: main_fitness)
      
      choose_winners(specie_id, shof_neural_eff_scaled, tot_fitness_shofs, [], [], specie_size_limit)
    end
    
    # Insert new agents into active_agents ETS table
    Enum.each(new_gen_ids, fn {:agent, u_id} -> 
      :ets.insert(:active_agents, {u_id, :agent, specie_id}) 
    end)
    
    :ok
  end

  @doc """
  Implementation of the 'hof_random' selection algorithm.
  """
  @spec hof_random(Models.specie_id(), [Models.agent_id()], non_neg_integer()) :: :ok
  def hof_random(specie_id, remaining_champion_designators, specie_size_limit) do
    s = DB.read(specie_id, :specie)
    DB.write(Models.set(s, [{:agent_ids, []}]), :specie)
    
    shof = Models.get(s, :hall_of_fame)
    shof_ratio = AppConfig.get_env(:shof_ratio)
    
    new_gen_ids = if shof_ratio < 1 do
      actives = remaining_champion_designators
      active_random_scaled = random_scaled(actives)
      shof_random_scaled = random_scaled(shof)
      tot_fitness_actives = Enum.sum(for {main_fitness, _id} <- active_random_scaled, do: main_fitness)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_random_scaled, do: main_fitness)
      
      next_generation(specie_id, active_random_scaled, shof_random_scaled, tot_fitness_actives,
                    tot_fitness_shofs, shof_ratio, specie_size_limit)
    else
      shof = Models.get(s, :hall_of_fame)
      shof_random_scaled = random_scaled(shof)
      tot_fitness_shofs = Enum.sum(for {main_fitness, _id} <- shof_random_scaled, do: main_fitness)
      
      choose_winners(specie_id, shof_random_scaled, tot_fitness_shofs, [], [], specie_size_limit)
    end
    
    # Insert new agents into active_agents ETS table
    Enum.each(new_gen_ids, fn {:agent, u_id} -> 
      :ets.insert(:active_agents, {u_id, :agent, specie_id}) 
    end)
    
    :ok
  end

  @doc """
  Choose winners for the next generation based on fitness scores.
  """
  @spec choose_winners(Models.specie_id(), [Models.agent_id()], float(), [Models.agent_id()],
                    [Models.agent_id()], non_neg_integer()) :: [Models.agent_id()]
  def choose_winners(specie_id, _agents, _total_fitness, offspring_acc, reentry_acc, 0) do
    reenter(reentry_acc, specie_id)
    offspring_acc ++ reentry_acc
  end
  
  def choose_winners(specie_id, agents, total_fitness, offspring_acc, reentry_acc, agent_index) do
    try do
      random_index = :rand.uniform(100) / 100 * total_fitness
      case choose_winner(specie_id, agents, random_index, 0) do
        {offspring_id, :offspring} ->
          choose_winners(specie_id, agents, total_fitness, [offspring_id | offspring_acc], 
                       reentry_acc, agent_index - 1)
        
        {agent_id, :reentry} ->
          if agent_id in reentry_acc do
            choose_winners(specie_id, agents, total_fitness, offspring_acc, 
                         reentry_acc, agent_index)
          else
            choose_winners(specie_id, agents, total_fitness, offspring_acc,
                         [agent_id | reentry_acc], agent_index - 1)
          end
      end
    catch
      kind, reason ->
        LogR.error({:selection_algorithm, :choose_winners, :error,
                  "choose winner crashing", [kind, reason]})
        choose_winners(specie_id, agents, total_fitness, offspring_acc, reentry_acc, agent_index)
    end
  end

  # Private helper functions

  defp reenter([], _specie_id), do: :ok
  
  defp reenter([agent_id | reentry_ids], specie_id) do
    LogR.debug({:selection_algorithm, :reenter, :ok, nil, [agent_id]})
    
    s = DB.read(specie_id, :specie)
    shof = Models.get(s, :hall_of_fame)
    
    # Remove agent from hall of fame
    u_shof = Enum.reject(shof, fn c -> Models.get(c, :id) == agent_id end)
    us = Models.set(s, [{:hall_of_fame, u_shof}])
    
    # Update agent's champion_flag
    a = DB.read(agent_id, :agent)
    ua = Models.set(a, [{:champion_flag, [:reentered | Models.get(a, :champion_flag)]}])
    
    # Write updated records to database
    DB.write(us, :specie)
    DB.write(ua, :agent)
    
    reenter(reentry_ids, specie_id)
  end

  defp choose_winner(_specie_id, [{_portion_size, agent_id}], _index, _acc) do
    re_entry_probability = AppConfig.get_env(:re_entry_probability)
    new_winner(re_entry_probability, agent_id)
  end
  
  defp choose_winner(specie_id, [{portion_size, agent_id} | allotments], index, acc) do
    re_entry_probability = AppConfig.get_env(:re_entry_probability)
    
    if index >= acc and index <= (acc + portion_size) do
      new_winner(re_entry_probability, agent_id)
    else
      choose_winner(specie_id, allotments, index, acc + portion_size)
    end
  end

  # Create a mutated copy of an agent
  defp create_mutant_agent_copy(agent_id) do
    agent_clone_id = Genotype.clone_agent(agent_id)
    GenomeMutator.mutate(agent_clone_id)
    agent_clone_id
  end

  # Assign ranks to champions based on their sorted order
  defp assign_rank(champions, ranks, acc \\ [])
  
  defp assign_rank([{_main_fitness, agent_id} | champions], [rank | rank_list], acc) do
    assign_rank(champions, rank_list, [{rank, agent_id} | acc])
  end
  
  defp assign_rank([], [], acc), do: acc

  # Calculate fitness scaled by efficiency
  defp fitness_scaled(champs, eff) do
    Enum.map(champs, fn c -> calc_fitness_scaled(c, eff) end)
  end

  defp calc_fitness_scaled(c, eff) do
    {
      Models.get(c, :fs) * (Models.get(c, :main_fitness) / :math.pow(Models.get(c, :tot_n), eff)),
      Models.get(c, :id)
    }
  end

  # Create the next generation based on active and hall of fame agents
  defp next_generation(specie_id, active_fitness_scaled, shof_fitness_scaled, tot_fitness_actives,
                     tot_fitness_shofs, shof_ratio, specie_size_limit) do
    active_winners = choose_winners(specie_id, active_fitness_scaled, tot_fitness_actives, [], [],
                                  round((1 - shof_ratio) * specie_size_limit))
                                  
    shof_winners = choose_winners(specie_id, shof_fitness_scaled, tot_fitness_shofs, [], [],
                                round(shof_ratio * specie_size_limit))
                                
    active_winners ++ shof_winners
  end

  # Rank champions based on fitness
  defp rank(champs) do
    sorted = sort_champs(champs)
    assign_rank(sorted, Enum.to_list(1..length(champs)))
  end

  # Sort champions by fitness
  defp sort_champs(champs) do
    Enum.sort(
      Enum.map(champs, fn c -> 
        {Models.get(c, :fs) * Models.get(c, :main_fitness), Models.get(c, :id)} 
      end)
    )
  end

  # Scale fitness by neural efficiency
  defp neural_eff_scaled(champs) do
    Enum.map(champs, fn c -> 
      {Models.get(c, :fs) * Models.get(c, :main_fitness) / Models.get(c, :tot_n), Models.get(c, :id)} 
    end)
  end

  # Create either a new offspring or reenter the agent
  defp new_winner(re_entry_probability, agent_id) do
    if :rand.uniform() <= re_entry_probability do
      {agent_id, :reentry}
    else
      a = DB.read(agent_id, :agent)
      offspring_agent_id = create_mutant_agent_copy(agent_id)
      
      # Update parent agent's offspring_ids
      ua = Models.set(a, [{:offspring_ids, [offspring_agent_id | Models.get(a, :offspring_ids)]}])
      DB.write(ua, :agent)
      
      # Update offspring's champion_flag
      offspring_a = DB.read(offspring_agent_id, :agent)
      u_offspring_a = Models.set(offspring_a, [{:champion_flag, [false | Models.get(offspring_a, :champion_flag)]}])
      DB.write(u_offspring_a, :agent)
      
      {offspring_agent_id, :offspring}
    end
  end

  # Random fitness scaling
  defp random_scaled(champs) do
    Enum.map(champs, fn c -> {Models.get(c, :fs) * 1, Models.get(c, :id)} end)
  end
end