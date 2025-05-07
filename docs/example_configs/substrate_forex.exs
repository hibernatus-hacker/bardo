# Substrate-encoded Forex Trading Configuration
# Use this configuration with: Bardo.Examples.Applications.AlgoTrading.run(:my_experiment, config)

alias Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding

# Create a substrate-encoded genotype initializer function
substrate_initializer = fn ->
  SubstrateEncoding.create_substrate_genotype(%{
    input_time_points: 60,     # 60 time points (candles)
    input_price_levels: 20,    # 20 price levels from high to low
    input_data_types: 10,      # 10 different data types (OHLC, indicators, etc.)
    hidden_layers: 3,          # 3 hidden layers
    hidden_neurons_per_layer: 25, # 25 neurons per hidden layer
    output_neurons: 3          # 3 outputs (direction, size, risk)
  })
end

# Create a substrate converter function
substrate_converter = fn price_data, indicators, genotype ->
  # Convert market data to substrate representation
  grid = SubstrateEncoding.convert_price_data_to_substrate(
    price_data, indicators, 60, 20, 10
  )
  
  # Flatten to neuron inputs
  SubstrateEncoding.flatten_substrate_grid(grid, genotype)
end

# Configuration for EURUSD trading with substrate encoding
config = %{
  # Basic experiment settings
  market: :forex,
  symbol: "EURUSD",
  timeframe: 15,               # 15-minute candles
  population_size: 150,        # 150 individuals in population
  generations: 200,            # Run for 200 generations
  data_window: 10000,          # Use 10,000 candles for training
  
  # Substrate encoding
  use_substrate: true,         # Enable substrate encoding
  genotype_initializer: substrate_initializer,
  population_converter: substrate_converter,
  
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
  evaluation_params: %{
    initial_balance: 10000,    # Start with $10,000
    max_drawdown: 30,          # Maximum 30% drawdown allowed
    leverage: 50,              # 50:1 leverage
    commission: 0.0001,        # 0.01% commission per trade
    slippage: 2,               # 2 pips slippage
    spread: 2                  # 2 pips spread
  },
  
  # Training data options
  use_external_data: false,    # Use internal data
  test_period: "last_month"    # Test on the last month of data
}