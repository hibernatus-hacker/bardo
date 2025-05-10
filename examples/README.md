# Bardo Examples

This directory contains example scripts demonstrating various features and capabilities of the Bardo neuroevolution framework.

## Cryptocurrency Trading Examples

- **crypto_trading_workflow.exs**: Original end-to-end workflow for training and deploying a cryptocurrency trading agent
- **crypto_trading_workflow_2.exs**: Experimental version of cryptocurrency trading workflow
- **crypto_trading_workflow_refactored.exs**: Refactored version with improved testability and separation of concerns

### Running Crypto Trading Examples

```shell
# Basic usage (will use environment variables for API keys)
mix run examples/crypto_trading_workflow_refactored.exs

# With specific arguments
mix run examples/crypto_trading_workflow_refactored.exs BTCUSD 90 YOUR_API_KEY YOUR_API_SECRET
```

### API Key Requirements

Crypto trading examples require Gemini API keys. You can either:
1. Pass them as command-line arguments (as shown above)
2. Set environment variables:
   ```
   export GEMINI_API_KEY=your_key_here
   export GEMINI_API_SECRET=your_secret_here
   ```

## Forex Trading Examples

- **forex_trading_workflow.exs**: End-to-end workflow for training and deploying a forex trading agent
- **forex_trading_workflow_2.exs**: Experimental version of forex trading workflow

## Testing the Examples

The refactored example is designed for better testability. You can write tests for it by mocking the dependencies:

```elixir
# Sample test code
test "workflow succeeds with valid config" do
  # Setup mocks
  mock_deps = %{
    trading_api: MockTradingAPI,
    data_downloader: MockDataDownloader,
    # ... other mocks
  }
  
  # Test configuration
  config = WorkflowManager.new(["BTCUSD", "7", "test_key", "test_secret"])
  
  # Run workflow with mocks
  assert {:ok, results} = WorkflowManager.run(config, mock_deps)
  
  # Assertions
  assert results.agent_info != nil
  # ... more assertions
end
```