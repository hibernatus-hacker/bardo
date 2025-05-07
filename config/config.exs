import Config

# Common configuration
config :bardo,
  identifier: :test,
  build_tool: :elixir,
  public_scape: [],
  runs: 20,
  min_pimprovement: 0.0,
  search_params_mut_prob: 0.5,
  output_sat_limit: 1,
  ro_signal: [0.0],
  fitness_stagnation: false,
  population_mgr_efficiency: 1,
  interactive_selection: false,
  re_entry_probability: 0.0,
  shof_ratio: 1,
  selection_algorithm_efficiency: 1,
  
  # Additional parameters for modern Bardo
  activation_function: :sigmoid,
  weight_range: {-1.0, 1.0},
  bias_range: {-1.0, 1.0},
  population_size: 50,
  max_generations: 100,
  mutation_rate: 0.3,
  add_neuron_probability: 0.1,
  add_link_probability: 0.2,
  enable_speciation: true,
  species_distance_threshold: 0.5,
  minimum_species_size: 5

# PMP configuration
config :bardo, :pmp,
  data: %{
    op_modes: [:gt, :validation],
    population_id: :dtm_benchmark_test,
    polis_id: :mathema,
    survival_percentage: 0.5,
    init_specie_size: 10,
    specie_size_limit: 20,
    generation_limit: 100,
    evaluations_limit: 5000,
    fitness_goal: :infinity
  }

# Constraints
config :bardo, :constraints,
  data: %{
    morphology: :dtm_morphology,
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
    perturbation_ranges: [1],
    heredity_types: [:darwinian],
    mutation_operators: [
      {:mutate_weights, 1},
      {:add_bias, 1},
      {:remove_bias, 1},
      {:mutate_af, 1},
      {:add_outlink, 4},
      {:add_inlink, 4},
      {:add_neuron, 4},
      {:outsplice, 4},
      {:add_sensor, 1},
      {:add_actuator, 1},
      {:add_sensorlink, 1},
      {:add_actuatorlink, 1},
      {:mutate_plasticity_parameters, 4},
      {:add_cpp, 1},
      {:add_cep, 1}
    ],
    tot_topological_mutations_fs: [{:ncount_exponential, 0.5}],
    population_evo_alg_f: :generational,
    population_selection_f: :hof_competition,
    specie_distinguishers: [:tot_n],
    hof_distinguishers: [:tot_n]
  }

# Import environment specific config
import_config "#{config_env()}.exs"