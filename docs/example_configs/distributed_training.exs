# Distributed Training Configuration
# Use this with: Bardo.Examples.Applications.AlgoTrading.DistributedTraining.start_distributed_training/3

alias Bardo.Examples.Applications.AlgoTrading.DistributedTraining

# Step 1: Start the appropriate Elixir nodes
# On primary node: iex --name primary@hostname -S mix
# On worker nodes: iex --name worker1@hostname -S mix
#                  iex --name worker2@hostname -S mix
#                  iex --name worker3@hostname -S mix

# Step 2: Connect the nodes
# On primary node:
# Node.connect(:'worker1@hostname')
# Node.connect(:'worker2@hostname')
# Node.connect(:'worker3@hostname')

# Step 3: Configure the experiment
experiment_id = :distributed_forex_experiment

# Base configuration for the experiment
experiment_config = %{
  # Market settings
  market: :forex,
  symbol: "EURUSD",
  timeframe: 15,               # 15-minute candles
  
  # Population settings
  population_size: 600,        # 600 individuals (will be divided among islands)
  generations: 200,            # Run for 200 generations
  data_window: 10000,          # Use 10,000 candles for training
  
  # Evolution parameters
  mutation_rate: 0.1,          # Base mutation rate
  mutation_operators: [
    {:mutate_weights, :gaussian, 0.4},  # 40% chance of weight mutation
    {:add_neuron, 0.1},                 # 10% chance to add a neuron
    {:add_connection, 0.2},             # 20% chance to add a connection
    {:remove_connection, 0.05},         # 5% chance to remove a connection
    {:remove_neuron, 0.03}              # 3% chance to remove a neuron
  ],
  selection_algorithm: "TournamentSelectionAlgorithm",
  tournament_size: 5,          # Tournament size for selection
  elite_fraction: 0.1,         # Keep top 10% unchanged
  
  # Evaluation parameters
  fitness_function: :sharpe_ratio, # Optimize for risk-adjusted returns
  
  # Optional: Use substrate encoding on some islands
  use_substrate: true,         # Enable substrate encoding
  
  # Testing
  test_period: "last_month"    # Test on the last month of data
}

# Distribution options
distribution_options = [
  # List of nodes to use
  nodes: [
    :'primary@hostname',  # This node
    :'worker1@hostname',  # Additional worker nodes
    :'worker2@hostname',
    :'worker3@hostname'
  ],
  
  # Number of islands (population subgroups)
  islands: 6,  # Can be different from number of nodes
  
  # Migration frequency (in generations)
  migration_interval: 10,
  
  # Percent of population to migrate between islands
  migration_rate: 0.1,
  
  # Fault tolerance: automatically migrate islands if a node fails
  auto_recovery: true,
  
  # Custom island configurations
  island_configs: [
    # Island 0: High exploration
    %{
      mutation_rate: 0.2,         # Higher mutation rate
      tournament_size: 3,         # Lower selection pressure
      use_substrate: true         # Use substrate encoding
    },
    
    # Island 1: Standard parameters
    %{
      mutation_rate: 0.1,
      tournament_size: 5,
      use_substrate: true
    },
    
    # Island 2: High exploitation
    %{
      mutation_rate: 0.05,        # Lower mutation rate
      tournament_size: 7,         # Higher selection pressure
      elite_fraction: 0.2,        # More elitism
      use_substrate: true
    },
    
    # Island 3: High exploration, no substrate
    %{
      mutation_rate: 0.2,
      tournament_size: 3,
      use_substrate: false
    },
    
    # Island 4: Standard parameters, no substrate
    %{
      mutation_rate: 0.1,
      tournament_size: 5,
      use_substrate: false
    },
    
    # Island 5: High exploitation, no substrate
    %{
      mutation_rate: 0.05,
      tournament_size: 7,
      elite_fraction: 0.2,
      use_substrate: false
    }
  ]
]

# Step 4: Start distributed training
#{:ok, experiment_id} = DistributedTraining.start_distributed_training(
#  experiment_id,
#  experiment_config,
#  distribution_options
#)

# Step 5: Monitor progress
# :timer.sleep(60000)  # Wait a minute
# DistributedTraining.get_training_status(experiment_id)

# Step 6: Get results when finished
# {:ok, best_agent} = DistributedTraining.get_best_agent(experiment_id)

# Step 7: Stop training early if needed
# DistributedTraining.stop_distributed_training(experiment_id)