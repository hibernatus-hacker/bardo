defmodule Bardo.PopulationManager.GenomeMutator do
  @moduledoc """
  The genome_mutator is responsible for mutating genotypes. It uses
  various mutation operators to modify a genotype, and return a mutant
  of the genotype. Specifically, the mutation operators
  include both topological and parametric mutations. The topological
  mutations mutate the structure of a genotype by adding, or
  removing, neurons, connections, sensors, and actuators.
  The parametric mutations mutate the parameters of the genotype, such as
  the weights and the plasticity parameters. In a multi-objective
  optimization, bias mutation is performed on the bias parameters of
  the neural network, thus changing the biasing of the NN from one
  objective to another, while preserving overall proficiency.
  
  Technically, we do not need every one of these mutation operators; the
  following list will be enough for a highly versatile complexifying
  topology and weight evolving artificial neural network (TWEANN) system:
  mutate_weights, add_bias, remove_bias, mutate_af, add_neuron, splice
  (just one of them), add_inlink, add_outlink, add_sensorlink,
  add_actuatorlink, add_sensor, and add_actuator. Note that this
  combination of MOs can convert any NN topology A into a NN topology B,
  given that A is contained (smaller, and simpler in a sense) within B.
  """
  
  alias Bardo.PopulationManager.Genotype
  
  @doc """
  Applies mutation operators to a genotype based on probabilities.
  
  ## Parameters
  
  - `genotype` - The genotype to mutate
  - `opts` - Options controlling mutation probabilities
  
  ## Options
  
  - `:add_neuron_probability` - Probability of adding a neuron (default: 0.1)
  - `:add_link_probability` - Probability of adding a connection (default: 0.2)
  - `:mutate_weights_probability` - Probability of mutating weights (default: 0.8)
  
  ## Examples
  
      iex> genotype = Bardo.PopulationManager.Genotype.new()
      iex> mutated = Bardo.PopulationManager.GenomeMutator.simple_mutate(genotype)
  """
  def simple_mutate(genotype, opts \\ %{}) do
    # Default probabilities
    add_neuron_prob = Map.get(opts, :add_neuron_probability, 0.1)
    add_link_prob = Map.get(opts, :add_link_probability, 0.2)
    mutate_weights_prob = Map.get(opts, :mutate_weights_probability, 0.8)
    
    # Apply mutations based on probabilities
    genotype
    |> maybe_add_neuron(add_neuron_prob)
    |> maybe_add_link(add_link_prob)
    |> maybe_mutate_weights(mutate_weights_prob)
  end
  
  # Apply a mutation with a certain probability
  defp maybe_apply(genotype, mutation_fun, probability) do
    if :rand.uniform() < probability do
      mutation_fun.(genotype)
    else
      genotype
    end
  end
  
  # Maybe add a neuron
  defp maybe_add_neuron(genotype, probability) do
    maybe_apply(genotype, &add_neuron/1, probability)
  end
  
  # Maybe add a link
  defp maybe_add_link(genotype, probability) do
    maybe_apply(genotype, &add_link/1, probability)
  end
  
  # Maybe mutate weights
  defp maybe_mutate_weights(genotype, probability) do
    maybe_apply(genotype, &perturb_weights/1, probability)
  end
  
  # Add a neuron by splitting a connection
  defp add_neuron(genotype) do
    # If no connections, just return the genotype
    if map_size(genotype.connections) == 0 do
      genotype
    else
      # Select a random connection
      {conn_id, connection} = Enum.random(genotype.connections)
      
      # Create a new hidden neuron
      genotype = Genotype.add_neuron(genotype, :hidden)
      new_neuron_id = "neuron_#{genotype.next_neuron_id - 1}"
      
      # Remove the old connection
      connections = Map.delete(genotype.connections, conn_id)
      
      # Add two new connections
      # Input to new neuron with weight 1.0
      genotype = %{genotype | connections: connections}
      genotype = Genotype.add_connection(genotype, connection.from_id, new_neuron_id, 1.0)
      
      # New neuron to output with the original weight
      genotype = Genotype.add_connection(genotype, new_neuron_id, connection.to_id, connection.weight)
      
      genotype
    end
  end
  
  # Add a random link between unconnected neurons
  defp add_link(genotype) do
    # Get all neuron IDs
    neuron_ids = Map.keys(genotype.neurons)
    
    # If less than 2 neurons, just return the genotype
    if length(neuron_ids) < 2 do
      genotype
    else
      # Try up to 5 times to find a valid connection
      try_add_link(genotype, 5)
    end
  end
  
  # Try to add a link up to n times
  defp try_add_link(genotype, 0), do: genotype
  defp try_add_link(genotype, tries) do
    # Get all neuron IDs by layer
    input_ids = Genotype.get_layer_neuron_ids(genotype, :input)
    bias_ids = Genotype.get_layer_neuron_ids(genotype, :bias)
    hidden_ids = Genotype.get_layer_neuron_ids(genotype, :hidden)
    output_ids = Genotype.get_layer_neuron_ids(genotype, :output)
    
    # Possible sources (input, bias, hidden)
    source_ids = input_ids ++ bias_ids ++ hidden_ids
    
    # Possible targets (hidden, output)
    target_ids = hidden_ids ++ output_ids
    
    # If no valid sources or targets, return the genotype
    if source_ids == [] or target_ids == [] do
      genotype
    else
      # Select random source and target
      from_id = Enum.random(source_ids)
      to_id = Enum.random(target_ids)
      
      # Check if connection already exists
      existing = Enum.any?(genotype.connections, fn {_id, conn} -> 
        conn.from_id == from_id and conn.to_id == to_id
      end)
      
      if existing do
        # Try again
        try_add_link(genotype, tries - 1)
      else
        # Create new connection with random weight
        weight = :rand.uniform() * 2 - 1 # Weight between -1 and 1
        Genotype.add_connection(genotype, from_id, to_id, weight)
      end
    end
  end
  
  # Mutate weights with Gaussian perturbations
  defp perturb_weights(genotype) do
    # Mutate each weight with a small Gaussian noise
    connections = 
      Enum.map(genotype.connections, fn {id, connection} ->
        if :rand.uniform() < 0.1 do
          # 10% chance of completely random weight
          new_weight = :rand.uniform() * 2 - 1 # Between -1 and 1
          {id, %{connection | weight: new_weight}}
        else
          # 90% chance of small perturbation
          perturbation = :rand.normal() * 0.1 # Gaussian with standard deviation 0.1
          new_weight = connection.weight + perturbation
          
          # Limit weight to a reasonable range
          new_weight = max(-5.0, min(5.0, new_weight))
          
          {id, %{connection | weight: new_weight}}
        end
      end)
      |> Map.new()
    
    # Return genotype with updated connections
    %{genotype | connections: connections}
  end

  alias Bardo.{Models, Utils, DB}
  alias Bardo.TuningSelection

  @sat_limit :math.pi() * 2
  @delta_multiplier :math.pi() * 2
  @es_mutators [:mutate_tuning_selection, 
                :mutate_tuning_annealing, 
                :mutate_tot_topological_mutations, 
                :mutate_heredity_type]

  @doc """
  The function mutate first updates the generation of the agent to be
  mutated, then calculates the number of mutation operators to be
  applied to it by executing the tot_topological_mutations:TTMName/2
  function, and then finally runs the apply_mutators/2 function, which
  mutates the agent. Once the agent is mutated, the function updates
  its fingerprint by executing genotype:update_finrgerprint/1.
  """
  @spec mutate(Models.agent_id()) :: :ok
  def mutate(agent_id) do
    Utils.random_seed()
    mutate_search_parameters(agent_id)
    
    a = DB.read(agent_id, :agent)
    {ttm_name, parameter} = Models.get(a, :tot_topological_mutations_f)
    tot_mutations = apply(Bardo.PopulationManager.TotTopologicalMutations, ttm_name, [parameter, agent_id])
    
    old_generation = Models.get(a, :generation)
    new_generation = old_generation + 1
    
    DB.write(Models.set(a, [{:generation, new_generation}]), :agent)
    apply_mutators(agent_id, tot_mutations)
    Genotype.update_fingerprint(agent_id)
  end

  @doc """
  The mutate_tuning_selection function checks if there are any other
  than the currently used tuning selection functions available in the
  agent's constraint. If there is, then it chooses a random one from
  this list, and sets the agent's tuning_selection_f to it. If there
  are no other tuning selection functions, then it exits with an error.
  """
  @spec mutate_tuning_selection(Models.agent_id()) :: :ok | false
  def mutate_tuning_selection(agent_id) do
    a = DB.read(agent_id, :agent)
    
    tuning_selection_functions = 
      Models.get(Models.get(a, :constraint), :tuning_selection_fs) -- 
      [Models.get(a, :tuning_selection_f)]
      
    case tuning_selection_functions do
      [] -> 
        false
      _other_functions -> 
        ua = Models.set(a, [{:tuning_selection_f, new_tsf(tuning_selection_functions)}])
        DB.write(ua, :agent)
    end
  end

  @doc """
  The mutate_annealing_parameter function checks if there are any
  other than the currently used tuning annealing parameters available
  in the agent's constraint. If there is, then it chooses a random one
  from this list, and sets the agent's annealing_parameter to it. If
  there are no other tuning annealing parameters, then it exits with
  an error.
  """
  @spec mutate_tuning_annealing(Models.agent_id()) :: :ok | false
  def mutate_tuning_annealing(agent_id) do
    a = DB.read(agent_id, :agent)
    
    tuning_annealing_params = 
      Models.get(Models.get(a, :constraint), :annealing_parameters) -- 
      [Models.get(a, :annealing_parameter)]
    
    case tuning_annealing_params do
      [] -> 
        false
      _other_params -> 
        new_tap = Enum.random(tuning_annealing_params)
        ua = Models.set(a, [{:annealing_parameter, new_tap}])
        DB.write(ua, :agent)
    end
  end

  @doc """
  The mutate_tot_topological_mutations function checks if there are
  any other than the currently used tuning tot topological mutation
  functions available in the agent's constraint. If there is, then it
  chooses a random one from this list, and sets the agent's
  tot_topological_mutations_f to it. If there are no other functions
  that can calculate tot topological mutations, then it exits with an
  error.
  """
  @spec mutate_tot_topological_mutations(Models.agent_id()) :: :ok | false
  def mutate_tot_topological_mutations(agent_id) do
    a = DB.read(agent_id, :agent)
    
    tot_topological_mutations = 
      Models.get(Models.get(a, :constraint), :tot_topological_mutations_fs) -- 
      [Models.get(a, :tot_topological_mutations_f)]
    
    case tot_topological_mutations do
      [] -> 
        false
      _other_functions -> 
        new_ttf = Enum.random(tot_topological_mutations)
        ua = Models.set(a, [{:tot_topological_mutations_f, new_ttf}])
        DB.write(ua, :agent)
    end
  end

  @doc """
  The mutate_heredity_type function checks if there are any other
  heredity types in the agent's constraint record. If any other than
  the one currently used by the agent are present, the agent exchanges
  the heredity type it currently uses to a random one from the remaining
  list. If no other heredity types are available, the mutation operator
  exits with an error, and the neuroevolutionary system tries another
  mutation operator.
  """
  @spec mutate_heredity_type(Models.agent_id()) :: :ok | false
  def mutate_heredity_type(agent_id) do
    a = DB.read(agent_id, :agent)
    
    heredity_type_pool = 
      Models.get(Models.get(a, :constraint), :heredity_types) -- 
      [Models.get(a, :heredity_type)]
    
    case heredity_type_pool do
      [] -> 
        false
      _other_types -> 
        new_ht = Enum.random(heredity_type_pool)
        ua = Models.set(a, [{:heredity_type, new_ht}])
        DB.write(ua, :agent)
    end
  end

  @doc """
  The mutate_weights function accepts the AgentId parameter, extracts
  the NN's cortex, and then chooses a random neuron belonging to the NN
  with a uniform distribution probability. Then the neuron's input_idps
  list is extracted, and the function perturb_idps/1 is used to
  perturb/mutate the weights. Once the InputIdPs have been perturbed,
  the agent's evolutionary history, EvoHist is updated to include the
  successfully applied mutate_weights mutation operator. Then the
  updated Agent and the updated neuron are written to the database.
  """
  @spec mutate_weights(Models.agent_id()) :: :ok
  def mutate_weights(agent_id) do
    a = DB.read(agent_id, :agent)
    cx_id = Models.get(a, :cx_id)
    cx = DB.read(cx_id, :cortex)
    n_ids = Models.get(cx, :neuron_ids)
    generation = Models.get(a, :generation)
    
    [perturbation_range, perturbation_qty, annealing_param, tuning_selection_func] = 
      Models.get(a, [:perturbation_range, :perturbation_qty, :annealing_parameter, :tuning_selection_f])
    
    perturbed_n_ids = case perturbation_qty do
      :multiple ->
        # Multiple Neurons Perturbed
        chosen_n_id_ps = apply(TuningSelection, tuning_selection_func, 
                             [n_ids, generation, perturbation_range, annealing_param])
        
        Enum.map(chosen_n_id_ps, fn {n_id, spread} -> 
          mutate_weights(n_id, spread) 
        end)
        
        Enum.map(chosen_n_id_ps, fn {n_id, _spread} -> n_id end)
      
      :single ->
        # One Neuron Perturbed
        n_id = Enum.random(n_ids)
        n = DB.read(n_id, :neuron)
        input_idps = Models.get(n, :input_idps)
        u_input_idps = perturb_idps(input_idps)
        
        DB.write(Models.set(n, [{:input_idps, u_input_idps}]), :neuron)
        n_id
    end
    
    evo_hist = Models.get(a, :evo_hist)
    u_evo_hist = [{:mutate_weights, perturbed_n_ids} | evo_hist]
    ua = Models.set(a, [{:evo_hist, u_evo_hist}])
    
    DB.write(ua, :agent)
  end

  @doc """
  The add_bias function is called with the AgentId parameter. The
  function first extracts the neuron_ids list from the cortex element
  and chooses a random neuron from the id list. After the neuron is
  read from the database, we check whether input_idps and
  input_idps_modulation lists already have bias, and we randomly
  generate a value 1 or 2. If the value 1 is generated and the
  input_idps list does not have a bias, it is added. If the value 2 is
  generated, and the input_idps_modulation does not have a bias, it is
  added. Otherwise an error is returned.
  """
  @spec add_bias(Models.agent_id()) :: :ok | false
  def add_bias(agent_id) do
    a = DB.read(agent_id, :agent)
    cx_id = Models.get(a, :cx_id)
    cx = DB.read(cx_id, :cortex)
    n_ids = Models.get(cx, :neuron_ids)
    n_id = Enum.random(n_ids)
    generation = Models.get(a, :generation)
    
    n = DB.read(n_id, :neuron)
    [si_idps, mi_idps] = Models.get(n, [:input_idps, :input_idps_modulation])
    {pf_name, _nl_parameters} = Models.get(n, :pf)
    
    case check_bias(si_idps, mi_idps, pf_name) do
      {_, false, true, 2} ->
        # Add bias to modulation inputs
        u_mi_idps = do_add_bias(mi_idps, pf_name)
        un = Models.set(n, [{:input_idps_modulation, u_mi_idps}, {:generation, generation}])
        evo_hist = Models.get(a, :evo_hist)
        u_evo_hist = [{{:add_bias, :m}, n_id} | evo_hist]
        ua = Models.set(a, [{:evo_hist, u_evo_hist}])
        DB.write(un, :neuron)
        DB.write(ua, :agent)
        
      {true, _, _, _} ->
        # Neuron already has a bias in input_idps
        false
        
      {false, _, _, _} ->
        # Add bias to synaptic inputs
        u_si_idps = do_add_bias(si_idps, pf_name)
        un = Models.set(n, [{:input_idps, u_si_idps}, {:generation, generation}])
        evo_hist = Models.get(a, :evo_hist)
        u_evo_hist = [{{:add_bias, :s}, n_id} | evo_hist]
        ua = Models.set(a, [{:evo_hist, u_evo_hist}])
        DB.write(un, :neuron)
        DB.write(ua, :agent)
    end
  end

  @doc """
  The remove_bias function is called with the AgentId parameter. The
  function first extracts the neuron_ids list from the cortex element
  and chooses a random neuron from the id list. After the neuron is
  read from the database, we check whether input_idps and
  input_idps_modulation lists already have bias, and we randomly
  generate a value 1 or 2. If the value 1 is generated and the
  input_idps list has a bias, it is removed. If the value 2 is
  generated, and the input_idps_modulation has a bias, it is removed.
  Otherwise an error is returned.
  """
  @spec remove_bias(Models.agent_id()) :: :ok | false
  def remove_bias(agent_id) do
    a = DB.read(agent_id, :agent)
    cx_id = Models.get(a, :cx_id)
    cx = DB.read(cx_id, :cortex)
    n_ids = Models.get(cx, :neuron_ids)
    n_id = Enum.random(n_ids)
    generation = Models.get(a, :generation)
    
    n = DB.read(n_id, :neuron)
    [si_idps, mi_idps] = Models.get(n, [:input_idps, :input_idps_modulation])
    {pf_name, _nl_parameters} = Models.get(n, :pf)
    
    case check_bias(si_idps, mi_idps, pf_name) do
      {_, true, true, 2} ->
        # Remove modulatory bias
        u_mi_idps = Keyword.delete(mi_idps, :bias)
        un = Models.set(n, [{:input_idps_modulation, u_mi_idps}, {:generation, generation}])
        evo_hist = Models.get(a, :evo_hist)
        u_evo_hist = [{{:remove_bias, :m}, n_id} | evo_hist]
        ua = Models.set(a, [{:evo_hist, u_evo_hist}])
        DB.write(un, :neuron)
        DB.write(ua, :agent)
        
      {false, _, _, _} ->
        # Neuron does not have a bias in input_idps
        false
        
      {true, _, _, _} ->
        # Remove synaptic bias
        u_si_idps = Keyword.delete(si_idps, :bias)
        un = Models.set(n, [{:input_idps, u_si_idps}, {:generation, generation}])
        evo_hist = Models.get(a, :evo_hist)
        u_evo_hist = [{{:remove_bias, :s}, n_id} | evo_hist]
        ua = Models.set(a, [{:evo_hist, u_evo_hist}])
        DB.write(un, :neuron)
        DB.write(ua, :agent)
    end
  end

  @doc """
  The mutate_af function chooses a random neuron, and then changes its
  currently used activation function into another one available from the
  neural_afs list of the agent's constraint record.
  """
  @spec mutate_af(Models.agent_id()) :: :ok | false
  def mutate_af(agent_id) do
    a = DB.read(agent_id, :agent)
    cx_id = Models.get(a, :cx_id)
    cx = DB.read(cx_id, :cortex)
    n_ids = Models.get(cx, :neuron_ids)
    n_id = Enum.random(n_ids)
    generation = Models.get(a, :generation)
    
    n = DB.read(n_id, :neuron)
    af = Models.get(n, :af)
    
    activation_functions = 
      Models.get(Models.get(a, :constraint), :neural_afs) -- [af]
    
    case activation_functions do
      [] ->
        false
      _other_functions ->
        new_af = Enum.random(activation_functions)
        un = Models.set(n, [{:af, new_af}, {:generation, generation}])
        evo_hist = Models.get(a, :evo_hist)
        u_evo_hist = [{:mutate_af, n_id} | evo_hist]
        ua = Models.set(a, [{:evo_hist, u_evo_hist}])
        DB.write(un, :neuron)
        DB.write(ua, :agent)
    end
  end

  @doc """
  The link_from_element_to_element first calculates what type
  of link is going to be established (neuron to neuron, sensor to neuron,
  or neuron to actuator), and then calls the specific linking function
  based on that.
  """
  @spec link_from_element_to_element(non_neg_integer(), Models.neuron_id() | Models.sensor_id(),
                                   Models.actuator_id() | Models.neuron_id()) :: :ok
  def link_from_element_to_element(generation, from_element_id, to_element_id) do
    case {from_element_id, to_element_id} do
      {{:neuron, _from_sid}, {:neuron, _to_sid}} ->
        link_from_neuron_to_neuron(generation, from_element_id, to_element_id)
        
      {{:sensor, _from_sid}, {:neuron, _to_sid}} ->
        link_from_sensor_to_neuron(generation, from_element_id, to_element_id)
        
      {{:neuron, _from_nid}, {:actuator, _to_aid}} ->
        # Extract the IDs for the elements
        from_neuron_id = from_element_id
        to_actuator_id = to_element_id
        
        # Update the neuron's outputs
        from_n = DB.read(from_neuron_id, :neuron)
        u_from_n = link_from_neuron(from_n, to_actuator_id, generation)
        DB.write(u_from_n, :neuron)
        
        # Update the actuator's inputs with the neuron connection
        to_a = DB.read(to_actuator_id, :actuator)
        _from_ovl = 1  # Output vector length for neurons is 1
        
        # Add the input connection to the actuator
        input_idps = Models.get(to_a, :input_idps)
        weight = 0.0
        plasticity = []
        
        # Only add if the neuron is not already connected
        u_input_idps = 
          if from_neuron_id in Enum.map(input_idps, fn {id, _} -> id end) do
            input_idps
          else
            [{from_neuron_id, [{weight, plasticity}]} | input_idps]
          end
          
        # Update the actuator
        u_to_a = Models.set(to_a, [
          {:input_idps, u_input_idps},
          {:generation, generation}
        ])
        
        DB.write(u_to_a, :actuator)
    end
  end

  @doc """
  The link_from_neuron_to_neuron establishes a link from neuron with
  id FromNeuronId, to a neuron with id ToNeuronId. The function then
  calls link_from_neuron, which establishes the link on the
  FromNeuronId's side. The updated neuron associated with the
  FromNeuronId is then written to database.
  """
  @spec link_from_neuron_to_neuron(non_neg_integer(), Models.neuron_id(), Models.actuator_id() |
                                Models.neuron_id()) :: :ok
  def link_from_neuron_to_neuron(generation, from_neuron_id, to_neuron_id) do
    # From Part
    from_n = DB.read(from_neuron_id, :neuron)
    u_from_n = link_from_neuron(from_n, to_neuron_id, generation)
    DB.write(u_from_n, :neuron)
    
    # To Part - We read it afterwards, in case it's the same element
    to_n = DB.read(to_neuron_id, :neuron)
    from_ovl = 1
    u_to_n = link_to_neuron(from_neuron_id, from_ovl, to_n, generation)
    DB.write(u_to_n, :neuron)
  end

  @doc """
  The function link_from_sensor_to_neuron establishes a connection from
  the sensor with id FromSensorId, and the neuron with id ToNeuronId.
  """
  @spec link_from_sensor_to_neuron(non_neg_integer(), Models.sensor_id(),
                                 {:neuron, {atom() | float(), float()}}) :: :ok
  def link_from_sensor_to_neuron(generation, from_sensor_id, to_neuron_id) do
    # From Part
    from_s = DB.read(from_sensor_id, :sensor)
    u_from_s = link_from_sensor(from_s, to_neuron_id, generation)
    DB.write(u_from_s, :sensor)
    
    # To Part
    to_n = DB.read(to_neuron_id, :neuron)
    from_ovl = Models.get(from_s, :vl)
    u_to_n = link_to_neuron(from_sensor_id, from_ovl, to_n, generation)
    DB.write(u_to_n, :neuron)
  end

  # Private functions

  # Mutate search parameters of an agent
  defp mutate_search_parameters(agent_id) do
    _a = DB.read(agent_id, :agent)
    mutators = @es_mutators
    
    case Enum.random(mutators) do
      :mutate_tuning_selection -> 
        mutate_tuning_selection(agent_id)
      :mutate_tuning_annealing -> 
        mutate_tuning_annealing(agent_id)
      :mutate_tot_topological_mutations -> 
        mutate_tot_topological_mutations(agent_id)
      :mutate_heredity_type -> 
        mutate_heredity_type(agent_id)
    end
  end

  # Apply a number of random mutations to an agent
  defp apply_mutators(_agent_id, 0), do: :ok
  
  defp apply_mutators(agent_id, tot_mutations) do
    mutation_operators = get_mutation_operators(agent_id)
    mutation_operator = Enum.random(mutation_operators)
    
    case apply(Bardo.PopulationManager.GenomeMutator, mutation_operator, [agent_id]) do
      false -> 
        apply_mutators(agent_id, tot_mutations)
      _ -> 
        apply_mutators(agent_id, tot_mutations - 1)
    end
  end
  
  # Get the available mutation operators for an agent
  defp get_mutation_operators(agent_id) do
    a = DB.read(agent_id, :agent)
    Models.get(a, :mutation_operators)
  end

  # Create a perturbed (mutated) version of the input_idps
  defp perturb_idps(input_idps) do
    Enum.map(input_idps, fn {id, weight_p_list} ->
      {id, perturb_weight_p_list(weight_p_list)}
    end)
  end

  # Perturb the weights in a weight parameter list
  defp perturb_weight_p_list(weight_p_list) do
    Enum.map(weight_p_list, fn {w, p} ->
      {perturb_weight(w), p}
    end)
  end

  # Apply a perturbation to a single weight
  defp perturb_weight(w) do
    Utils.sat(w + :rand.normal() * @delta_multiplier, @sat_limit)
  end

  # Link from a neuron to another element
  defp link_from_neuron(neuron, to_id, generation) do
    [output_ids, ro_ids, n_id] = Models.get(neuron, [:output_ids, :ro_ids, :id])
    
    # Check if the link already exists
    if to_id in output_ids do
      neuron
    else
      case to_id do
        {:neuron, {to_li, _to_uid}} ->
          {_neuron_type, {from_li, _from_uid}} = n_id
          # If a recursive connection, add to ro_ids
          u_ro_ids = if to_li <= from_li, do: [to_id | ro_ids], else: ro_ids
          Models.set(neuron, [
            {:output_ids, [to_id | output_ids]}, 
            {:ro_ids, u_ro_ids}, 
            {:generation, generation}
          ])
        _ ->
          Models.set(neuron, [
            {:output_ids, [to_id | output_ids]}, 
            {:generation, generation}
          ])
      end
    end
  end

  # Link to a neuron from another element
  defp link_to_neuron(from_id, from_ovl, neuron, generation) do
    {pf_name, _nl_parameters} = Models.get(neuron, :pf)
    input_idps = Models.get(neuron, :input_idps)
    
    # Don't establish duplicate links
    if Keyword.has_key?(input_idps, from_id) do
      neuron
    else
      weights_p = Genotype.create_neural_weights_p(pf_name, from_ovl, [])
      u_input_idps = [{from_id, weights_p} | input_idps]
      Models.set(neuron, [
        {:input_idps, u_input_idps}, 
        {:generation, generation}
      ])
    end
  end

  # Link from a sensor to another element
  defp link_from_sensor(sensor, to_id, generation) do
    fanout_ids = Models.get(sensor, :fanout_ids)
    
    # Don't establish duplicate links
    if to_id in fanout_ids do
      sensor
    else
      Models.set(sensor, [
        {:fanout_ids, [to_id | fanout_ids]}, 
        {:generation, generation}
      ])
    end
  end

  # Check if a neuron has bias in its input connections
  defp check_bias(si_idps, mi_idps, pf_name) do
    si_has_bias = Keyword.has_key?(si_idps, :bias)
    mi_has_bias = Keyword.has_key?(mi_idps, :bias)
    is_plasticity = pf_name != :none
    
    # Choose randomly between synaptic and modulatory inputs for bias
    choice = :rand.uniform(2)
    
    {si_has_bias, mi_has_bias, is_plasticity, choice}
  end

  # Add bias to input connections
  defp do_add_bias(idps, pf_name) do
    weights_p = Genotype.create_neural_weights_p(pf_name, 1, [])
    [{:bias, weights_p} | idps]
  end

  # Select a new tuning selection function
  defp new_tsf(tuning_selection_functions) do
    Enum.random(tuning_selection_functions)
  end
  
  # Specialization of mutate_weights for a single neuron with spread
  defp mutate_weights(n_id, spread) do
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(n, :input_idps)
    u_input_idps = perturb_idps(input_idps, spread)
    DB.write(Models.set(n, [{:input_idps, u_input_idps}]), :neuron)
  end
  
  # Perturb idps with a specific spread value
  defp perturb_idps(input_idps, spread) do
    Enum.map(input_idps, fn {id, weight_p_list} ->
      {id, perturb_weight_p_list(weight_p_list, spread)}
    end)
  end
  
  # Perturb weight list with a specific spread value
  defp perturb_weight_p_list(weight_p_list, spread) do
    Enum.map(weight_p_list, fn {w, p} ->
      {perturb_weight(w, spread), p}
    end)
  end
  
  # Perturb a single weight with a specific spread
  defp perturb_weight(w, spread) do
    Utils.sat(w + :rand.normal() * @delta_multiplier * spread, @sat_limit)
  end
end