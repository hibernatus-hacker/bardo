# Application Examples

This directory contains complex, real-world application examples of the Bardo framework. These examples demonstrate how to apply neuroevolution to solve practical problems.

## Flatland Predator-Prey Simulation

The Flatland simulation is a multi-agent environment where predator and prey agents evolve simultaneously in a 2D world. This demonstrates competitive co-evolution and emergent behaviors.

### Running Flatland

```elixir
# Basic run
Bardo.Examples.Applications.Flatland.run(
  :flatland_experiment,  # Experiment ID
  5,                     # Number of iterations
  5,                     # Number of populations
  20,                    # Evaluation count per agent
  100,                   # Maximum simulation time
  3                      # Complexity level
)
```

### Key Features

- Multi-agent simulation with competitive co-evolution
- Sensor-based perception of the environment
- Emergent behaviors and strategies
- Visualization of evolved behaviors

## Forex (FX) Trading

The FX trading example demonstrates how to evolve neural networks for financial trading on forex markets using historical data.

### Running FX Trading

```elixir
# Train a trading agent
Bardo.Examples.Applications.Fx.run(
  :fx_experiment,  # Experiment ID
  5,               # Number of iterations
  500,             # Number of time steps to evaluate
  3                # Complexity level
)

# Test the best evolved agent
Bardo.Examples.Applications.Fx.test_best_agent(:fx_experiment)
```

### Key Features

- Market data processing and feature extraction
- Risk management and position sizing
- Performance metrics for trading strategies
- Backtesting on historical data

## Algorithmic Trading

The algorithmic trading module is a more comprehensive trading framework that supports multiple markets, brokers, and advanced features for real-world trading applications.

See the [Algorithmic Trading README](algo_trading/README.md) for details.

### Key Components

- **Data Downloaders**: Download and process market data from various sources
- **Brokers**: Interface with real brokers like Gemini and Oanda
- **Agent Serialization**: Save and load trained agents
- **Distributed Training**: Train agents across multiple machines
- **Live Trading**: Deploy trained agents for actual trading

### Running Algorithmic Trading

```bash
# Run the algorithmic trading examples
mix run_algo_trading
```

## Common Application Features

These applications share several important features:

1. **Real-world Interfaces**: Connect to external systems and data
2. **Data Processing**: Handle and transform domain-specific data
3. **Evaluation Metrics**: Use domain-appropriate metrics for fitness evaluation
4. **Agent Deployment**: Methods for deploying and using trained agents
5. **Visualization**: Tools for understanding agent behavior and performance

## Creating Your Own Applications

To create your own application using Bardo:

1. Define appropriate sensor and actuator modules for your domain
2. Create a domain-specific fitness function
3. Design a suitable neural network morphology
4. Set up data processing and evaluation methods
5. Implement deployment and persistence mechanisms

For more information, see the [Advanced Documentation](../../../docs/advanced.md) and the source code of these examples.