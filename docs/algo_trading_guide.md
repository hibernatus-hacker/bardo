# Algorithmic Trading with Bardo

This guide provides comprehensive instructions for training and deploying neural network-based algorithmic trading agents using the Bardo framework.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Training Trading Agents](#training-trading-agents)
4. [Deploying Trading Agents](#deploying-trading-agents)
5. [Continuous Learning](#continuous-learning)
6. [Substrate Encoding](#substrate-encoding)
7. [Broker Integrations](#broker-integrations)
8. [Distributed Training](#distributed-training)

## Overview

The algorithmic trading functionality in Bardo allows you to:

- Train neural network-based trading agents using neuroevolution
- Deploy agents to trade on real or simulated markets
- Enable continuous learning for deployed agents
- Use advanced substrate encoding for efficient network representation
- Connect to various brokers including OANDA (forex) and Gemini (crypto)
- Distribute training across multiple nodes for faster results

## Architecture

The algorithmic trading system consists of the following components:

- **Substrate Encoding**: Efficient neural network representation optimized for market data
- **Trading Sensors**: Convert market data into neural network inputs
- **Trading Actuators**: Convert neural network outputs into trading decisions
- **Agent Loader**: Load and deploy trained agents for trading
- **Continuous Learning**: Update agents based on real-world performance
- **Broker Interfaces**: Connect to trading platforms
- **Distributed Training**: Coordinate training across multiple nodes

## Training Trading Agents

### Basic Training

To train a basic trading agent:

```elixir
# Configure training parameters
training_config = %{
  instrument: "EUR_USD",           # Currency pair to trade
  timeframe: "M15",                # 15-minute candles
  training_period: {~D[2023-01-01], ~D[2023-12-31]},  # Training data period
  population_size: 50,             # Number of agents in population
  generations: 100,                # Number of generations to evolve
  substrate_config: %{             # Neural network configuration
    input_time_points: 60,         # Number of candles as input
    input_price_levels: 20,        # Number of price levels
    input_data_types: 10,          # Number of data types (OHLC, indicators)
    hidden_layers: 2,              # Number of hidden layers
    hidden_neurons_per_layer: 20,  # Neurons per hidden layer
    output_neurons: 3,             # Trading outputs (direction, size, etc.)
  }
}

# Start training
{:ok, experiment_id} = Bardo.Examples.Applications.AlgoTrading.DistributedTraining.start_training(training_config)

# Monitor progress
Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_status(experiment_id)
```

### Running Training via CLI

You can also run training using the Mix task:

```bash
mix run_algo_trading --instrument EUR_USD --timeframe M15 --start-date 2023-01-01 --end-date 2023-12-31 --population 50 --generations 100
```

## Deploying Trading Agents

### Loading and Deploying an Agent

```elixir
# Initialize broker connection
broker_config = %{
  api_key: "your_api_key",
  api_secret: "your_api_secret",
  account_id: "your_account_id",
  live: false  # Use practice/sandbox environment
}

{:ok, broker_state} = Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda.init(broker_config)

# Deploy a trained agent
agent_file = "path/to/trained_agent.json"
deploy_options = %{
  instrument: "EUR_USD",
  risk_per_trade: 1.0,  # Risk 1% per trade
  max_drawdown: 10.0,   # Stop trading if drawdown exceeds 10%
  continuous_learning: true  # Enable continuous learning
}

{:ok, agent_id} = Bardo.Examples.Applications.AlgoTrading.AgentLoader.deploy_agent_from_file(
  agent_file,
  Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda,
  broker_state,
  deploy_options
)

# Monitor the agent's status
{:ok, status} = Bardo.Examples.Applications.AlgoTrading.AgentLoader.get_agent_status(agent_id)
```

### Deploying Multiple Agents (Agent Pool)

```elixir
# Deploy multiple agents as a pool
agents_config = [
  %{
    file_path: "path/to/eurusd_agent.json",
    broker_module: Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda,
    broker_state: oanda_state,
    instrument: "EUR_USD",
    risk_per_trade: 1.0,
    max_drawdown: 10.0,
    continuous_learning: true
  },
  %{
    file_path: "path/to/gbpusd_agent.json",
    broker_module: Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda,
    broker_state: oanda_state,
    instrument: "GBP_USD",
    risk_per_trade: 0.5,
    max_drawdown: 8.0,
    continuous_learning: true
  }
]

{:ok, pool_id} = Bardo.Examples.Applications.AlgoTrading.AgentLoader.create_agent_pool(agents_config)
```

## Continuous Learning

Continuous learning allows agents to adapt to changing market conditions based on real-world performance.

### How It Works

1. Agent collects experiences from real trading
2. After each trade, performance is analyzed
3. If performance improves, the neural network is adjusted
4. Random mutations are added occasionally for exploration
5. The agent continually adapts to new market conditions

### Configuration

```elixir
# Configure continuous learning options
continuous_learning_options = %{
  learning_rate: 0.01,          # Rate of adaptation
  mutation_probability: 0.1,    # Probability of random mutations
  update_frequency: 10,         # Update after every N trades
  max_memory_size: 1000         # Number of experiences to retain
}

# Enable when deploying agent
deploy_options = %{
  instrument: "EUR_USD",
  continuous_learning: true,
  continuous_learning_options: continuous_learning_options
}
```

## Substrate Encoding

Substrate encoding is a powerful neural network representation inspired by HyperNEAT, optimized for processing market data.

### Benefits

- **Geometric interpretation**: Maps market data to a coordinate space
- **Regularized structure**: Provides natural symmetry in the network
- **Improved generalization**: Better performance on unseen market conditions
- **Efficient representation**: Compact encoding of complex patterns

### 3D Space Representation

- **X-axis**: Time (recent to older candles)
- **Y-axis**: Price levels (high to low)
- **Z-axis**: Data types (OHLC, volume, indicators)

### Creating a Substrate Network

```elixir
# Create a substrate-encoded neural network for trading
genotype = Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding.create_substrate_genotype(%{
  input_time_points: 60,         # 60 time points of history
  input_price_levels: 20,        # 20 price levels
  input_data_types: 10,          # 10 data types (OHLC, indicators)
  hidden_layers: 2,              # 2 hidden layers
  hidden_neurons_per_layer: 20,  # 20 neurons per hidden layer
  output_neurons: 3              # 3 outputs (direction, size, etc.)
})
```

## Broker Integrations

Bardo supports multiple broker interfaces:

### OANDA (Forex)

```elixir
# Initialize OANDA broker
oanda_config = %{
  api_key: "your_oanda_api_key",
  account_id: "your_account_id",
  live: false  # Use practice environment
}

{:ok, oanda_state} = Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda.init(oanda_config)

# Get available instruments
{:ok, instruments} = Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda.get_instruments(oanda_state)

# Get historical data
{:ok, historical_data} = Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda.get_historical_data(
  oanda_state,
  "EUR_USD",
  "M15",
  %{count: 500}
)
```

### Gemini (Crypto)

```elixir
# Initialize Gemini broker
gemini_config = %{
  api_key: "your_gemini_api_key",
  api_secret: "your_gemini_api_secret",
  live: false  # Use sandbox environment
}

{:ok, gemini_state} = Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini.init(gemini_config)

# Get available instruments
{:ok, instruments} = Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini.get_instruments(gemini_state)

# Get historical data
{:ok, historical_data} = Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini.get_historical_data(
  gemini_state,
  "BTCUSD",
  "M15",
  %{}
)
```

## Distributed Training

Distributed training allows you to accelerate the training process by utilizing multiple nodes.

### Setting Up a Coordinator

```elixir
# Start a coordinator node
coordinator_config = %{
  node_name: :coordinator,
  port: 9000
}

{:ok, coordinator_pid} = Bardo.Examples.Applications.AlgoTrading.Distributed.Coordinator.start_link(coordinator_config)
```

### Setting Up Training Nodes

```elixir
# Start training nodes
node_config = %{
  node_name: :training_node_1,
  port: 9001,
  coordinator_node: :coordinator@localhost,
  heartbeat_interval: 5000
}

{:ok, node_pid} = Bardo.Examples.Applications.AlgoTrading.Distributed.TrainingNode.start_link(node_config)
```

### Running Distributed Training

```elixir
# Submit a training job to the coordinator
training_config = %{
  instrument: "EUR_USD",
  timeframe: "M15",
  training_period: {~D[2023-01-01], ~D[2023-12-31]},
  population_size: 100,
  generations: 200,
  substrate_config: %{
    input_time_points: 60,
    input_price_levels: 20,
    input_data_types: 10,
    hidden_layers: 2,
    hidden_neurons_per_layer: 20,
    output_neurons: 3
  }
}

{:ok, job_id} = Bardo.Examples.Applications.AlgoTrading.Distributed.Coordinator.submit_job(training_config)

# Get job status
{:ok, status} = Bardo.Examples.Applications.AlgoTrading.Distributed.Coordinator.get_job_status(job_id)
```

## Best Practices

1. **Data Quality**: Ensure you have sufficient historical data for training.
2. **Risk Management**: Always use appropriate risk parameters when deploying agents.
3. **Continuous Learning**: Enable continuous learning for long-running agents to adapt to market changes.
4. **Testing**: Test agents in simulation or practice environments before using real funds.
5. **Monitoring**: Regularly monitor agent performance and be ready to intervene if necessary.
6. **Diversification**: Deploy multiple agents with different strategies and on different instruments.
7. **Validation**: Use proper validation techniques to avoid overfitting during training.

## Conclusion

This guide provides the foundation for training and deploying algorithmic trading agents using the Bardo framework. For more advanced topics and detailed API references, please consult the API documentation.