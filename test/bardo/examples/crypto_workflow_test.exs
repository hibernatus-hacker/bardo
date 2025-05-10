defmodule Bardo.Examples.CryptoWorkflowTest do
  @moduledoc """
  Tests for the refactored cryptocurrency trading workflow example.
  
  These tests demonstrate how to use mocks to test the workflow
  without actual API dependencies.
  """
  
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  # Define mocks for testing
  defmodule MockProgressTracker do
    def start(_steps, _description), do: spawn(fn -> Process.sleep(:infinity) end)
    def update(_pid, _progress), do: :ok
    def simulate(_pid, _steps, _time_ms \\ 1000), do: :ok
    def stop(_pid), do: :ok
  end

  defmodule MockTradingAPI do
    def init_broker(_type, _key, _options), do: {:ok, %{mock: true}}
    def deploy_agent(_path, _type, _state, _options), do: {:ok, "mock_agent_id"}
  end

  defmodule MockDataDownloader do
    def download_data(_module, _state, _instrument, _options) do
      {:ok, "/tmp/mock_data_file.csv"}
    end
  end

  defmodule MockAgentTrainer do
    def train_agent(_instrument, _data_file, _options) do
      {:ok, %{
        agent_id: "mock_agent_1",
        agent_path: "/tmp/mock_agent_1.json",
        fitness: [0.75, 0.80, 0.65]
      }}
    end
  end

  defmodule MockAgentRepository do
    def backup_agents(_instrument), do: {:ok, "/tmp/backup"}
    
    def list_agents(_instrument, _options) do
      {:ok, [
        %{
          id: "mock_agent_1",
          path: "/tmp/mock_agent_1.json",
          file_path: "/tmp/mock_agent_1.json",
          trained_at: "2025-05-10T12:00:00Z",
          performance: 0.75
        }
      ]}
    end
  end

  defmodule MockVerificationTools do
    def run_backtest(_agent_path, _data_file, _options) do
      {:ok, %{
        profit_loss: 1250.0,
        profit_percentage: 12.5,
        win_rate: 0.65,
        max_drawdown: 5.2,
        profit_factor: 1.5
      }}
    end
    
    def compare_agents(_agent_paths, _data_file, _options) do
      {:ok, %{
        comparison: %{
          overall_ranking: [
            %{id: "mock_agent_1", score: 0.85}
          ]
        }
      }}
    end
  end

  # Load workflow module from example script
  # Note: this assumes the WorkflowManager is defined in the script
  Code.require_file("../../examples/crypto_trading_workflow_refactored.exs", __DIR__)

  describe "workflow configuration" do
    test "validate/1 returns error with missing API key" do
      config = %WorkflowManager{api_key: nil, api_secret: "secret"}
      assert {:error, _} = WorkflowManager.validate(config)
    end

    test "validate/1 returns error with missing API secret" do
      config = %WorkflowManager{api_key: "key", api_secret: nil}
      assert {:error, _} = WorkflowManager.validate(config)
    end

    test "validate/1 returns ok with valid config" do
      config = %WorkflowManager{api_key: "key", api_secret: "secret"}
      assert {:ok, ^config} = WorkflowManager.validate(config)
    end
  end

  describe "workflow execution" do
    test "run/2 executes all steps with valid mocks" do
      # Configure workflow
      config = %WorkflowManager{
        instrument: "BTCUSD",
        days_of_history: 7,
        api_key: "test_key",
        api_secret: "test_secret",
        broker_type: :gemini,
        broker_module: Elixir.Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini,
        population_size: 5,
        generations: 3,
        timeframe: "M15",
        live_mode: false
      }
      
      # Setup mocks
      mocks = %{
        trading_api: MockTradingAPI,
        data_downloader: MockDataDownloader,
        agent_trainer: MockAgentTrainer,
        agent_repository: MockAgentRepository,
        verification_tools: MockVerificationTools,
        progress_tracker: MockProgressTracker
      }
      
      # Capture output to keep test logs clean
      output = capture_io(fn ->
        # Run workflow with mocks
        {:ok, result} = WorkflowManager.run(config, mocks)
        
        # Verify result structure
        assert result.data_file == "/tmp/mock_data_file.csv"
        assert result.agent_info.agent_id == "mock_agent_1"
        assert result.agent_id == "mock_agent_id"
        assert result.performance.profit_loss == 1250.0
      end)
      
      # Verify expected output messages
      assert output =~ "Workflow completed successfully!"
    end
    
    test "run/2 handles broker initialization failures" do
      # Configure workflow
      config = %WorkflowManager{
        instrument: "BTCUSD",
        days_of_history: 7,
        api_key: "test_key",
        api_secret: "test_secret",
        broker_type: :gemini,
        broker_module: Elixir.Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini,
        population_size: 5,
        generations: 3,
        timeframe: "M15",
        live_mode: false
      }
      
      # Create failing mock
      failing_trading_api = %{
        init_broker: fn(_type, _key, _options) -> 
          {:error, "API connection failed"}
        end
      }
      
      # Setup mocks with the failing one
      mocks = %{
        trading_api: failing_trading_api,
        data_downloader: MockDataDownloader,
        agent_trainer: MockAgentTrainer,
        agent_repository: MockAgentRepository,
        verification_tools: MockVerificationTools,
        progress_tracker: MockProgressTracker
      }
      
      # Capture output to keep test logs clean
      output = capture_io(fn ->
        # Run workflow with failing mock
        result = WorkflowManager.run(config, mocks)
        assert {:error, "broker_initialization", "API connection failed"} = result
      end)
      
      # Verify expected failure message
      assert output =~ "Workflow failed"
      assert output =~ "broker_initialization"
    end
  end
end