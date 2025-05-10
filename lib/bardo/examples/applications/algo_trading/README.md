# Algorithmic Trading Module

This module provides functionality for algorithmic trading with Bardo neuroevolution.

## Key Components

- **TradingAPI**: High-level API for working with the trading system
- **DataDownloader**: Handles downloading and preprocessing market data
- **AgentTrainer**: Trains agents on historical data
- **TradingSensor/TradingActuator**: Interface with market data and execute trades
- **AgentRepository**: Manages storage and retrieval of trained agents
- **VerificationTools**: Backtesting and verification utilities

## Usage

### Workflow Examples

The main examples are in the examples directory:
- `crypto_trading_workflow.exs` - Basic workflow
- `crypto_trading_workflow_refactored.exs` - Refactored version with better testability

### Creating a Trading Agent

```elixir
# Initialize broker
{:ok, broker_state} = TradingAPI.init_broker(:gemini, api_key, %{api_secret: api_secret})

# Download historical data
{:ok, data_file} = DataDownloader.download_data(Gemini, broker_state, "BTCUSD", %{
  timeframe: "M15",
  start_date: "2023-01-01T00:00:00Z",
  end_date: "2023-06-01T00:00:00Z"
})

# Train an agent
{:ok, agent_info} = AgentTrainer.train_agent("BTCUSD", data_file, %{
  population_size: 50,
  generations: 100
})

# Deploy the agent
{:ok, agent_id} = TradingAPI.deploy_agent(agent_info.agent_path, :gemini, broker_state, %{
  instrument: "BTCUSD",
  risk_per_trade: 1.0
})
```

## Broker Support

Currently supports the following brokers:
- Gemini (cryptocurrency)
- Oanda (forex)

## Testing

The refactored implementation includes proper mocking capabilities for testing.
See the `test/bardo/examples/crypto_workflow_test.exs` file for examples.

## Configuration

Most components accept configuration options as maps. Refer to the module documentation
for detailed parameter descriptions.