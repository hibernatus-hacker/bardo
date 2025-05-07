defmodule Bardo.PopulationManager.PopulationStatsTest do
  use ExUnit.Case
  
  alias Bardo.PopulationManager.PopulationManager
  alias Bardo.PopulationManager.Genotype
  alias Bardo.Models
  alias Bardo.DB
  
  @population_id {:population, :testps}
  @specie_id {:specie, 0.6767}
  @agent_id {:agent, 0.939392343}
  @agent_id1 {:agent, 0.61634161}
  
  setup do
    # Set up environment
    Application.put_env(:bardo, :min_pimprovement, 0.0)
    Application.put_env(:bardo, :search_params_mut_prob, 0)
    Application.put_env(:bardo, :output_sat_limit, 1)
    Application.put_env(:bardo, :ro_signal, [0.0])
    Application.put_env(:bardo, :fitness_stagnation, false)
    Application.put_env(:bardo, :re_entry_probability, 0.0)
    Application.put_env(:bardo, :shof_ratio, 1)
    Application.put_env(:bardo, :selection_algorithm_efficiency, 1)
    
    # Set up PMP configuration
    Application.put_env(:bardo, :pmp, %{
      data: %{
        op_modes: [:gt, :validation],
        population_id: @population_id,
        polis_id: :mathema,
        survival_percentage: 0.5,
        init_specie_size: 5,
        specie_size_limit: 20,
        generation_limit: 100,
        evaluations_limit: 5000,
        fitness_goal: :inf
      }
    })
    
    # Set up constraints
    Application.put_env(:bardo, :constraints, [
      %{
        data: %{
          morphology: :dpb_w_damping,
          connection_architecture: :recurrent,
          agent_encoding_types: [:neural],
          substrate_plasticities: [:none],
          substrate_linkforms: [:l2l_feedforward],
          neural_afs: [:tanh],
          neural_pfns: [:ojas],
          neural_aggr_fs: [:dot_product],
          tuning_selection_fs: [:dynamic_random],
          tuning_duration_f: {:wsize_proportional, 0.5},
          annealing_parameters: [0.5],
          perturbation_ranges: [1.0],
          heredity_types: [:darwinian],
          mutation_operators: [
            {:mutate_weights, 1},
            {:add_bias, 1},
            {:remove_bias, 1},
            {:mutate_af, 1},
            {:add_outlink, 1},
            {:add_inlink, 1},
            {:add_neuron, 1},
            {:outsplice, 1},
            {:add_sensor, 1},
            {:add_sensorlink, 1},
            {:add_actuator, 1},
            {:add_actuatorlink, 1},
            {:mutate_plasticity_parameters, 1}
          ],
          tot_topological_mutations_fs: [{:ncount_exponential, 0.5}],
          population_evo_alg_f: :generational,
          population_fitness_postprocessor_f: :size_proportional,
          population_selection_f: :hof_competition,
          specie_distinguishers: [:tot_n],
          hof_distinguishers: [:tot_n],
          objectives: [:main_fitness, :inverse_tot_n]
        }
      }
    ])
    
    Application.put_env(:bardo, :runs, 1)
    
    # Initialize test DB
    DB.start_link()
    
    # Create ETS tables
    :ets.new(:population_status, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    :ets.new(:evaluations, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    :ets.new(:active_agents, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    :ets.new(:inactive_agents, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
      
    # Get specie constraint from config
    specie_con = List.last(Application.get_env(:bardo, :constraints))
    
    # Create stat
    stat = Models.stat(%{
      morphology: :dpb_w_damping,
      specie_id: @specie_id,
      avg_neurons: 1.0,
      std_neurons: 1.0,
      avg_fitness: [2.3523],
      std_fitness: [2.324],
      max_fitness: [4.324],
      min_fitness: [1.324],
      avg_diversity: 1,
      evaluations: 10,
      time_stamp: 999999,
      validation_fitness: {0.0, :void}
    })
    
    # Create trace
    trace = Models.trace(%{
      stats: [[stat]],
      tot_evaluations: 10,
      step_size: 400
    })
    
    # Create population
    population = Models.population(%{
      id: @population_id,
      specie_ids: [@specie_id],
      morphologies: nil,
      innovation_factor: nil,
      evo_alg_f: Models.get(specie_con, :population_evo_alg_f),
      selection_f: Models.get(specie_con, :population_selection_f),
      trace: trace
    })
    DB.write(population, :population)
    
    # Create specie
    specie = Models.specie(%{
      id: @specie_id,
      population_id: @population_id,
      fingerprint: :origin,
      constraint: specie_con,
      fitness: nil,
      innovation_factor: {0, 0},
      stats: [[stat]],
      seed_agent_ids: [],
      hof_distinguishers: [:tot_n],
      specie_distinguishers: [:tot_n],
      hall_of_fame: []
    })
    DB.write(specie, :specie)
    
    # Create agents
    Genotype.construct_agent(@specie_id, @agent_id, specie_con)
    Genotype.construct_agent(@specie_id, @agent_id1, specie_con)
    
    # Add agents to active_agents table
    {:agent, u_id} = @agent_id
    {:agent, u_id1} = @agent_id1
    :ets.insert(:active_agents, {u_id, :agent, @specie_id})
    :ets.insert(:active_agents, {u_id1, :agent, @specie_id})
    
    # Update agent fitness values
    agent = DB.read(@agent_id, :agent)
    u_agent = Models.set([{:fitness, [2.4]}, {:fs, 2.5}, {:main_fitness, 2.6}], agent)
    DB.write(u_agent, :agent)
    
    agent1 = DB.read(@agent_id1, :agent)
    u_agent1 = Models.set([{:fitness, [4.4]}, {:fs, 4.4}, {:main_fitness, 4.4}], agent1)
    DB.write(u_agent1, :agent)
    
    # Create champion
    champ = Models.champion(%{
      hof_fingerprint: [1],
      id: @agent_id1,
      fitness: [2.7],
      validation_fitness: 2.8,
      main_fitness: 2.9,
      tot_n: 1,
      generation: 1,
      fs: 3.0
    })
    
    # Update specie with hall_of_fame
    specie = DB.read(@specie_id, :specie)
    u_specie = Models.set({:hall_of_fame, [champ]}, specie)
    DB.write(u_specie, :specie)
    
    # Set evaluations
    :ets.insert(:evaluations, {@specie_id, 32})
    
    # Set up mock for experiment_mgr if not already mocked
    try do
      :meck.new(Bardo.ExperimentManager.ExperimentManagerClient, [])
    rescue
      _ -> :ok  # Mock already exists
    end
    
    on_exit(fn ->
      # Clean up mocks
      try do
        :meck.unload(Bardo.ExperimentManager.ExperimentManagerClient)
      rescue
        _ -> :ok  # Mock already unloaded
      end
    end)
    
    :ok
  end
  
  test "calculate_specie_fitness returns correct fitness statistics" do
    assert {[3.4000000000000004], [1.0000000000000002], [4.4], [2.4]} ==
      PopulationManager.calculate_specie_fitness(@specie_id)
  end
  
  test "calculate_specie_avg_nodes returns correct neuron statistics" do
    assert {1.0, 0.0} == PopulationManager.calculate_specie_avg_nodes(@specie_id)
  end
  
  test "calculate_specie_diversity returns correct diversity" do
    assert 1 == PopulationManager.calculate_specie_diversity(@specie_id)
  end
end