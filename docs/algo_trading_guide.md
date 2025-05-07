# Algorithmic Trading with Bardo

This guide explains how to use Bardo's algorithmic trading capabilities to develop, train, and deploy neural network-based trading strategies.

## Table of Contents

1. [Introduction](#introduction)
2. [Architecture Overview](#architecture-overview)
3. [Substrate Encoding](#substrate-encoding)
4. [Distributed Training](#distributed-training)
5. [Live Trading](#live-trading)
6. [Continuous Learning](#continuous-learning)
7. [Example Workflows](#example-workflows)
8. [Advanced Topics](#advanced-topics)

## Introduction

Bardo's algorithmic trading module provides a complete framework for developing neural network-based trading strategies using neuroevolution. This approach allows you to:

1. Evolve neural networks that can process market data and make trading decisions
2. Use advanced encoding techniques (like substrate encoding) for better pattern recognition
3. Distribute training across multiple nodes for faster results
4. Deploy trained agents to live markets with risk management
5. Implement continuous learning for adaptive agents

The system is highly modular and extensible, allowing you to customize each component for your specific needs.

## Architecture Overview

The algorithmic trading module consists of several key components:

- **Market Simulators**: Simulate market environments for training
- **Broker Interfaces**: Connect to external trading platforms
- **Neural Network Encoding**: Methods for representing market data to neural networks
- **Distributed Training**: Tools for parallel evolution across multiple nodes
- **Live Agents**: Deployable agents that can trade real markets
- **Performance Analytics**: Tools for evaluating trading strategies

These components work together to create a complete pipeline from strategy development to live trading:

```
Market Data → Neural Network → Trading Decisions → Execution → Performance Evaluation → Evolution
```

## Substrate Encoding

Substrate encoding is a powerful technique for representing market data in a geometric space that neural networks can more easily process. It provides several advantages over traditional vector-based inputs:

- Better pattern recognition
- More efficient representation of complex data
- Improved generalization to new market conditions
- Natural regularization of network structure

### How Substrate Encoding Works

Substrate encoding maps market data into a 3D coordinate space:

- X-axis: Time (from recent to older candles)
- Y-axis: Price levels (from high to low)
- Z-axis: Data types (OHLC, volume, indicators)

Neurons are then placed at specific coordinates in this space, and connections are established based on geometric rules and evolved weights.

### Using Substrate Encoding

To use substrate encoding in your trading strategy:

```elixir
# Create a substrate-encoded genotype
genotype = Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding.create_substrate_genotype(%{
  input_time_points: 60,    # 60 time periods of data
  input_price_levels: 20,   # 20 price levels
  input_data_types: 10,     # 10 different data types
  hidden_layers: 2,         # 2 hidden layers
  hidden_neurons_per_layer: 20, # 20 neurons per hidden layer
  output_neurons: 3         # 3 outputs (direction, size, risk)
})

# Convert market data to substrate representation
grid = Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding.convert_price_data_to_substrate(
  price_data,    # List of price candles
  indicators,    # Map of technical indicators
  60, 20, 10     # Dimensions matching the genotype
)

# Flatten to neuron inputs
inputs = Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding.flatten_substrate_grid(
  grid, genotype
)

# Activate the neural network with the inputs
{:ok, outputs} = Bardo.AgentManager.Cortex.activate(cortex, inputs)
```

## Distributed Training

Distributed training allows you to leverage multiple machines or nodes to speed up the evolutionary process. This is especially valuable for algorithmic trading, where the search space is large and evaluation can be computationally intensive.

### Key Concepts

1. **Island-based Evolution**: Population is divided into "islands" that evolve independently
2. **Migration**: Periodically, the best individuals migrate between islands
3. **Node Distribution**: Islands can be distributed across multiple physical or virtual machines
4. **Fault Tolerance**: The system can recover from node failures by migrating islands

### Setting Up Distributed Training

To set up distributed training:

1. Connect the nodes (this is a standard Erlang distribution setup)
2. Define your experiment configuration
3. Start distributed training

```elixir
# Start distributed training
{:ok, experiment_id} = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.start_distributed_training(
  :my_trading_experiment,  # Unique experiment ID
  %{                       # Configuration options
    market: :forex,
    symbol: "EURUSD",
    timeframe: 15,
    population_size: 500,  # Will be divided across islands
    generations: 200,
    mutation_rate: 0.1,
    elite_fraction: 0.1,
    tournament_size: 5
  },
  [
    nodes: [:node1@host, :node2@host, :node3@host],  # Nodes to use
    islands: 6,            # Number of islands (population subgroups)
    migration_interval: 10, # How often to migrate individuals between islands
    migration_rate: 0.1     # Percentage of population to migrate
  ]
)

# Check training status
status = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_training_status(experiment_id)

# Get the best agent when training is complete
{:ok, best_agent} = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_best_agent(experiment_id)

# Stop training early if needed
Bardo.Examples.Applications.AlgoTrading.DistributedTraining.stop_distributed_training(experiment_id)
```

## Live Trading

Once you have trained a successful trading strategy, you can deploy it to live markets using the LiveAgent module.

### Setting Up a Live Agent

```elixir
# Start a live trading agent
{:ok, agent_id} = Bardo.Examples.Applications.AlgoTrading.LiveAgent.start_link(
  :my_trading_agent,    # Agent ID
  best_agent,           # Trained neural network genotype
  Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader,  # Broker module
  %{                    # Broker configuration
    symbol: "EURUSD",
    timeframe: 15,
    account_id: "12345678",
    api_key: "your_api_key",
    api_url: "http://localhost:5000"
  },
  [                    # Agent options
    risk_params: %{
      risk_per_trade: 0.01,  # 1% risk per trade
      max_drawdown: 0.10,    # 10% maximum drawdown
      stop_loss: 0.02,       # 2% stop loss
      take_profit: 0.04      # 4% take profit
    },
    substrate_encoding: true,  # Use substrate encoding
    adaptation_enabled: false  # Start without continuous learning
  ]
)

# Get agent status
status = Bardo.Examples.Applications.AlgoTrading.LiveAgent.get_status(agent_id)

# Update risk parameters
Bardo.Examples.Applications.AlgoTrading.LiveAgent.update_risk_params(agent_id, %{
  risk_per_trade: 0.005,  # Reduce risk to 0.5%
  max_drawdown: 0.05      # Reduce max drawdown to 5%
})

# Close all positions and stop the agent
Bardo.Examples.Applications.AlgoTrading.LiveAgent.close_all_positions(agent_id)
Bardo.Examples.Applications.AlgoTrading.LiveAgent.stop_agent(agent_id)
```

### Deploying Multiple Agents

For robustness and diversification, you can deploy multiple agents from the same training:

```elixir
# Start a fleet of trading agents
{:ok, agent_ids} = Bardo.Examples.Applications.AlgoTrading.LiveAgent.start_agent_fleet(
  :my_trading_experiment,  # Experiment ID
  Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader,  # Broker module
  [                        # List of broker configurations
    %{symbol: "EURUSD", timeframe: 15, account_id: "12345678"},
    %{symbol: "GBPUSD", timeframe: 15, account_id: "12345678"},
    %{symbol: "USDJPY", timeframe: 15, account_id: "12345678"}
  ],
  [
    nodes: [:node1@host, :node2@host],  # Distribute agents across nodes
    adaptation_enabled: true             # Enable continuous learning
  ]
)

# Get performance reports from all agents
fleet_performance = Bardo.Examples.Applications.AlgoTrading.LiveAgent.get_fleet_performance(agent_ids)
```

## Continuous Learning

One of the most powerful features of the Bardo trading system is continuous learning. This allows agents to adapt to changing market conditions after deployment.

### How Continuous Learning Works

1. The agent collects and stores its trading experience
2. Periodically, it adjusts its neural network based on recent performance
3. Successful trading patterns are reinforced
4. Unsuccessful patterns are modified

This creates an agent that can adapt to changing market conditions and continue improving its strategy after deployment.

### Enabling Continuous Learning

```elixir
# Enable continuous learning for an agent
Bardo.Examples.Applications.AlgoTrading.LiveAgent.enable_continuous_learning(
  agent_id,
  0.01,  # Learning rate (how quickly the agent adapts)
  10     # Update interval (apply updates every 10 trades)
)
```

## Example Workflows

Here are some example workflows for common algorithmic trading tasks:

### Basic Training and Testing

```elixir
# Run a simple forex trading experiment
mix run_algo_trading --market forex --symbol EURUSD --timeframe 15 --generations 100 --population 100

# Test the best agent on out-of-sample data
mix run_algo_trading --test --test-period last_month
```

### Advanced Training with Substrate Encoding

```elixir
# Start an IEx session
iex -S mix

# Configure experiment with substrate encoding
config = %{
  market: :forex,
  symbol: "EURUSD",
  timeframe: 15,
  population_size: 100,
  generations: 100,
  use_substrate: true,  # Enable substrate encoding
  input_time_points: 60,
  input_price_levels: 20,
  input_data_types: 10
}

# Run the experiment
Bardo.Examples.Applications.AlgoTrading.run(:substrate_experiment, config)

# Test the best agent
Bardo.Examples.Applications.AlgoTrading.test_best_agent(:substrate_experiment)
```

### Distributed Training on Multiple Nodes

```elixir
# Start an Elixir node with a name
iex --name trainer@hostname -S mix

# Connect to other nodes
Node.connect(:'node1@hostname')
Node.connect(:'node2@hostname')
Node.connect(:'node3@hostname')

# Verify connections
Node.list()

# Start distributed training
{:ok, experiment_id} = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.start_distributed_training(
  :distributed_experiment,
  %{
    market: :forex,
    symbol: "EURUSD",
    timeframe: 15,
    population_size: 500,
    generations: 200
  }
)

# Monitor progress
:timer.sleep(60000)  # Wait a minute
Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_training_status(experiment_id)
```

### Live Trading Deployment

```elixir
# Get the best agent from a completed experiment
{:ok, best_agent} = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_best_agent(:distributed_experiment)

# Export agent for deployment
Bardo.Examples.Applications.AlgoTrading.LiveAgent.export_agents(:distributed_experiment, "agents.json", 5)

# Import agents on another system
{:ok, agents} = Bardo.Examples.Applications.AlgoTrading.LiveAgent.import_agents("agents.json")
best_agent = List.first(agents)

# Start a live trading agent
{:ok, agent_id} = Bardo.Examples.Applications.AlgoTrading.LiveAgent.start_link(
  :live_agent,
  best_agent,
  Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader,
  %{
    symbol: "EURUSD",
    timeframe: 15,
    account_id: "12345678",
    api_key: "your_api_key",
    api_url: "http://localhost:5000"
  }
)

# Enable continuous learning
Bardo.Examples.Applications.AlgoTrading.LiveAgent.enable_continuous_learning(agent_id)

# Monitor performance
:timer.sleep(3600000)  # Wait an hour
Bardo.Examples.Applications.AlgoTrading.LiveAgent.get_status(agent_id)
```

## Advanced Topics

### Custom Market Simulators

You can create custom market simulators by implementing the `PrivateScape` behavior:

```elixir
defmodule MyCustomMarketSimulator do
  @behaviour Bardo.AgentManager.PrivateScape
  
  # Implement required callbacks
  @impl Bardo.AgentManager.PrivateScape
  def init(params) do
    # Initialize your simulator
  end
  
  @impl Bardo.AgentManager.PrivateScape
  def sense(params, state) do
    # Process sensor requests
  end
  
  @impl Bardo.AgentManager.PrivateScape
  def actuate(function, params, agent_id, state) do
    # Process actuator requests
  end
  
  @impl Bardo.AgentManager.PrivateScape
  def terminate(reason, state) do
    # Clean up resources
  end
end
```

### Custom Broker Interfaces

To connect to different trading platforms, implement the `BrokerInterface` behavior:

```elixir
defmodule MyCustomBroker do
  @behaviour Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  
  # Implement required callbacks for the broker interface
  @impl Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  def connect(params) do
    # Connect to the broker
  end
  
  @impl Bardo.Examples.Applications.AlgoTrading.Brokers.BrokerInterface
  def disconnect(params) do
    # Disconnect from the broker
  end
  
  # Implement other required callbacks...
end
```

### Custom Fitness Functions

You can create custom fitness functions to optimize for specific trading objectives:

```elixir
# Sharpe ratio optimization
def sharpe_ratio_fitness(trading_results) do
  profit_loss = Map.get(trading_results, :profit_loss, 0.0)
  drawdown = Map.get(trading_results, :max_drawdown, 100.0)
  win_rate = Map.get(trading_results, :win_rate, 0.0)
  sharpe = Map.get(trading_results, :sharpe_ratio, 0.0)
  
  # Prioritize Sharpe ratio but also consider other metrics
  [
    sharpe * 100,             # Primary objective: risk-adjusted return
    profit_loss,              # Secondary objective: absolute return
    -drawdown * 5,            # Penalize drawdown
    win_rate * 50             # Reward consistency
  ]
end
```

### Custom Neural Network Architectures

You can experiment with different neural network architectures by customizing the substrate encoding:

```elixir
# Create a deeper network with more hidden layers
genotype = Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding.create_substrate_genotype(%{
  input_time_points: 60,
  input_price_levels: 20,
  input_data_types: 10,
  hidden_layers: 5,           # More hidden layers
  hidden_neurons_per_layer: 30, # More neurons per layer
  output_neurons: 5           # More outputs for finer control
})
```

### Ensemble Trading Strategies

You can implement ensemble strategies that combine multiple neural networks:

```elixir
# Start multiple agents with different strategies
{:ok, agent_ids} = Bardo.Examples.Applications.AlgoTrading.LiveAgent.start_agent_fleet(
  :ensemble_experiment,
  broker_module,
  [broker_config, broker_config, broker_config]  # Same config for all agents
)

# Create an ensemble strategy that aggregates their decisions
# This would be a custom module you implement
Bardo.Examples.Applications.AlgoTrading.Ensemble.start_ensemble(
  :ensemble_strategy,
  agent_ids,
  broker_module,
  broker_config,
  %{aggregation_method: :weighted_vote}
)
```

## Frequently Asked Questions

### Will the agent adapt to changing market conditions?

Yes, if you enable continuous learning. The agent will collect its trading experience and periodically adjust its neural network to improve performance.

### How much data is needed for training?

For most forex pairs, at least 1-2 years of historical data is recommended. More complex strategies may require more data.

### Can I use this for high-frequency trading?

The current implementation is designed for medium to low-frequency trading (minutes to hours). High-frequency trading would require custom optimizations.

### How do I handle broker-specific requirements?

Implement a custom broker interface that handles the specific requirements of your broker.

### Is this ready for production use?

This is primarily research and development software. Proper risk management and extensive testing are essential before deploying any trading system with real money.

## Conclusion

Bardo's algorithmic trading module provides a powerful platform for developing, training, and deploying neural network-based trading strategies. With features like substrate encoding, distributed training, and continuous learning, it offers advanced capabilities for tackling the challenges of financial markets.

Remember that trading involves significant risk. Always start with small positions, implement proper risk management, and continuously monitor your trading systems when deployed to live markets.