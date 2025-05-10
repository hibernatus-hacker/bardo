# Forex Trading Workflow Example
#
# This script demonstrates a complete end-to-end workflow for algorithmic trading with Bardo:
# 1. Download historical data from OANDA
# 2. Train a trading agent on the data
# 3. Evaluate the agent's performance
# 4. Deploy the agent for live trading
#
# Usage: mix run examples/forex_trading_workflow.exs [instrument] [days_of_history] [api_key] [account_id]
#   instrument: Currency pair to trade (default: EUR_USD)
#   days_of_history: Number of days of historical data to use (default: 7)
#   api_key: OANDA API key (required for data download and live trading)
#   account_id: OANDA account ID (required for data download and live trading)

require Logger

alias Bardo.Examples.Applications.AlgoTrading.TradingAPI
alias Bardo.Examples.Applications.AlgoTrading.DataDownloader
alias Bardo.Examples.Applications.AlgoTrading.AgentTrainer
alias Bardo.Examples.Applications.AlgoTrading.AgentRepository
alias Bardo.Examples.Applications.AlgoTrading.VerificationTools

defmodule ForexWorkflow do
  @moduledoc """
  A module to orchestrate the forex trading workflow.
  """

  defmodule Config do
    @moduledoc """
    Configuration for the forex trading workflow.
    """
    defstruct [
      :instrument,
      :days_of_history,
      :api_key,
      :account_id,
      :population_size,
      :generations,
      :timeframe,
      :broker_state
    ]

    def new(args) do
      instrument = Enum.at(args, 0, "EUR_USD")
      days_of_history = parse_days(Enum.at(args, 1))
      api_key = Enum.at(args, 2, System.get_env("OANDA_API_KEY"))
      account_id = Enum.at(args, 3, System.get_env("OANDA_ACCOUNT_ID"))

      %__MODULE__{
        instrument: instrument,
        days_of_history: days_of_history,
        api_key: api_key,
        account_id: account_id,
        population_size: 5,     # Default: 50
        generations: 3,         # Default: 100
        timeframe: "M15"        # Default: 15 minutes
      }
    end

    defp parse_days(nil), do: 7
    defp parse_days(days) do
      case Integer.parse(days) do
        {days_int, _} -> days_int
        :error -> 7
      end
    end

    def validate(%__MODULE__{api_key: nil}), do: {:error, "OANDA API key is required"}
    def validate(%__MODULE__{account_id: nil}), do: {:error, "OANDA account ID is required"}
    def validate(config), do: {:ok, config}

    def print(%__MODULE__{} = config) do
      IO.puts("=========================================")
      IO.puts("Forex Trading Workflow Example")
      IO.puts("=========================================")
      IO.puts("Instrument: #{config.instrument}")
      IO.puts("Historical data: #{config.days_of_history} days")
      IO.puts("Training parameters:")
      IO.puts("  - Population size: #{config.population_size}")
      IO.puts("  - Generations: #{config.generations}")
      IO.puts("  - Timeframe: #{config.timeframe}")
      IO.puts("Using OANDA API in practice mode")
      IO.puts("=========================================")
    end
  end

  defmodule UI do
    @moduledoc """
    UI helpers for the forex trading workflow.
    """

    def print_step(step_num, total_steps, description) do
      IO.puts("\n[Step #{step_num}/#{total_steps}] #{description}")
    end

    def print_success(message) do
      IO.puts("✓ #{message}")
    end

    def print_error(message) do
      IO.puts("✗ #{message}")
    end

    def print_info(message) do
      IO.puts("  #{message}")
    end

    def format_elapsed_time(milliseconds) do
      total_seconds = div(milliseconds, 1000)
      hours = div(total_seconds, 3600)
      minutes = div(rem(total_seconds, 3600), 60)
      seconds = rem(total_seconds, 60)

      if hours > 0 do
        "#{hours}h #{minutes}m #{seconds}s"
      else
        "#{minutes}m #{seconds}s"
      end
    end

    def track_progress(total_steps, description, step_time_ms \\ 1000) do
      progress_agent = spawn(fn ->
        progress_loop = fn loop_fn, current, total ->
          receive do
            {:progress, new_progress} ->
              ForexWorkflow.ProgressBar.print(new_progress, total, 40, "  #{description}:")
              loop_fn.(loop_fn, new_progress, total)

            :stop ->
              # Ensure 100% is displayed
              ForexWorkflow.ProgressBar.print(total, total, 40, "  #{description}:")
          after
            # Update every 500ms if no progress messages received
            500 ->
              ForexWorkflow.ProgressBar.print(current, total, 40, "  #{description}:")
              loop_fn.(loop_fn, current, total)
          end
        end

        progress_loop.(progress_loop, 0, total_steps)
      end)

      # Start simulated progress updates
      spawn(fn ->
        Enum.reduce(1..total_steps, 0, fn step, _acc ->
          Process.sleep(step_time_ms)
          send(progress_agent, {:progress, step})
          step
        end)
        send(progress_agent, :stop)
      end)

      progress_agent
    end
  end

  defmodule ProgressBar do
    @moduledoc """
    A simple progress bar implementation.
    """
    def print(current, total, bar_width \\ 40, description \\ nil) do
      percent = Float.round(current / total * 100, 1)
      completed_bars = trunc(bar_width * current / total)
      remaining_bars = bar_width - completed_bars
      completed_str = String.duplicate("█", completed_bars)
      remaining_str = String.duplicate("░", remaining_bars)

      if description do
        IO.write("\r#{description} [#{completed_str}#{remaining_str}] #{percent}%     ")
      else
        IO.write("\r[#{completed_str}#{remaining_str}] #{percent}%     ")
      end

      if current >= total, do: IO.write("\n")
    end
  end

  @doc """
  Run the complete forex trading workflow.
  """
  def run(args) do
    with {:ok, config} <- Config.new(args) |> Config.validate(),
         :ok <- Config.print(config),
         {:ok, config} <- step_1_init_broker(config),
         {:ok, data_file} <- step_2_download_data(config),
         {:ok, agent_info} <- step_3_train_agent(config, data_file),
         :ok <- step_4_store_agent(config, agent_info),
         {:ok, performance} <- step_5_evaluate_agent(config, agent_info, data_file),
         {:ok, agent_id} <- step_6_deploy_agent(config, agent_info),
         {:ok, robustness} <- step_7_test_robustness(config, agent_info, data_file) do

      print_workflow_success(config)
      {:ok, %{agent_id: agent_id, performance: performance, robustness: robustness}}
    else
      {:error, step, reason} ->
        UI.print_error("Workflow failed at step #{step}: #{reason}")
        {:error, reason}

      {:error, reason} ->
        UI.print_error("Workflow failed: #{reason}")
        {:error, reason}
    end
  end

  defp step_1_init_broker(config) do
    UI.print_step(1, 7, "Initializing OANDA broker...")

    case TradingAPI.init_broker(:oanda, config.api_key, %{account_id: config.account_id}) do
      {:ok, broker_state} ->
        UI.print_success("Successfully connected to OANDA")
        {:ok, %{config | broker_state: broker_state}}

      {:error, reason} ->
        {:error, 1, "Failed to connect to OANDA: #{reason}"}
    end
  end

  defp step_2_download_data(config) do
    UI.print_step(2, 7, "Downloading historical data for #{config.instrument}...")

    # Track download progress
    UI.track_progress(10, "Download progress")

    # Calculate date range based on days_of_history
    now = DateTime.utc_now()
    from_date = DateTime.add(now, -config.days_of_history * 24 * 60 * 60, :second)

    download_result = DataDownloader.download_data(
      Bardo.Examples.Applications.AlgoTrading.Brokers.Oanda,
      config.broker_state,
      config.instrument,
      %{
        timeframe: config.timeframe,
        start_date: DateTime.to_iso8601(from_date),
        end_date: DateTime.to_iso8601(now)
      }
    )

    case download_result do
      {:ok, data_file} ->
        UI.print_success("Successfully downloaded data to #{data_file}")
        {:ok, data_file}

      {:error, reason} ->
        {:error, 2, "Data download failed: #{reason}"}
    end
  end

  defp step_3_train_agent(config, data_file) do
    UI.print_step(3, 7, "Training an agent on the historical data...")
    UI.print_info("Using population size: #{config.population_size}, generations: #{config.generations}")

    # Calculate total estimated progress steps
    total_training_steps = config.population_size * config.generations

    # Track training progress
    UI.track_progress(total_training_steps, "Training progress")

    training_start_time = System.monotonic_time(:millisecond)

    training_result = AgentTrainer.train_agent(
      config.instrument,
      data_file,
      %{
        population_size: config.population_size,
        generations: config.generations,
        mutation_rate: 0.3,
        crossover_rate: 0.7,
        elite_fraction: 0.1,
        substrate_config: %{
          input_time_points: 60,   # Look back 60 candles (15 hours)
          input_price_levels: 20,
          input_data_types: 10,
          hidden_layers: 2,
          hidden_neurons_per_layer: 20,
          output_neurons: 3
        }
      }
    )

    training_end_time = System.monotonic_time(:millisecond)
    training_time = training_end_time - training_start_time

    case training_result do
      {:ok, agent_info} ->
        UI.print_success("Successfully trained agent: #{agent_info.agent_id}")
        UI.print_info("Training time: #{UI.format_elapsed_time(training_time)}")
        UI.print_info("Fitness: #{Enum.join(agent_info.fitness, ", ")}")
        {:ok, agent_info}

      {:error, reason} ->
        {:error, 3, "Agent training failed: #{reason}"}
    end
  end

  defp step_4_store_agent(config, agent_info) do
    UI.print_step(4, 7, "Storing the agent in the repository...")

    # Already stored by the trainer, but we'll verify it exists in the repository
    case AgentRepository.list_agents(config.instrument) do
      {:ok, agents} ->
        if Enum.any?(agents, fn agent -> agent.id == agent_info.agent_id end) do
          UI.print_success("Agent is stored in the repository")
          :ok
        else
          {:error, 4, "Agent not found in repository - this shouldn't happen"}
        end

      {:error, reason} ->
        {:error, 4, "Failed to verify agent in repository: #{reason}"}
    end
  end

  defp step_5_evaluate_agent(config, agent_info, data_file) do
    UI.print_step(5, 7, "Evaluating the agent's performance...")

    # Track backtest progress
    UI.track_progress(20, "Evaluation progress")

    backtest_result = VerificationTools.run_backtest(
      agent_info.agent_path,
      data_file,
      %{
        initial_balance: 10000.0,
        risk_per_trade: 1.0,
        commission: 0.1,
        slippage: 1.0,
        report_file: "#{config.instrument}_backtest_report.md"
      }
    )

    case backtest_result do
      {:ok, performance} ->
        UI.print_success("Backtest completed")
        UI.print_info("Profit/Loss: $#{Float.round(performance.profit_loss, 2)} (#{Float.round(performance.profit_percentage, 2)}%)")
        UI.print_info("Win Rate: #{Float.round(performance.win_rate * 100, 2)}%")
        UI.print_info("Max Drawdown: #{Float.round(performance.max_drawdown, 2)}%")
        UI.print_info("Profit Factor: #{Float.round(performance.profit_factor, 2)}")
        UI.print_info("Report saved to #{config.instrument}_backtest_report.md")
        {:ok, performance}

      {:error, reason} ->
        {:error, 5, "Backtest failed: #{reason}"}
    end
  end

  defp step_6_deploy_agent(config, agent_info) do
    UI.print_step(6, 7, "Deploying the agent for paper trading...")

    deploy_result = TradingAPI.deploy_agent(
      agent_info.agent_path,
      :oanda,
      config.broker_state,
      %{
        instrument: config.instrument,
        risk_per_trade: 1.0,
        max_drawdown: 10.0,
        continuous_learning: true
      }
    )

    case deploy_result do
      {:ok, agent_id} ->
        UI.print_success("Successfully deployed agent: #{agent_id}")
        {:ok, agent_id}

      {:error, reason} ->
        {:error, 6, "Agent deployment failed: #{reason}"}
    end
  end

  defp step_7_test_robustness(config, agent_info, data_file) do
    UI.print_step(7, 7, "Testing agent robustness...")

    # Track robustness test progress
    UI.track_progress(15, "Robustness testing progress")

    robustness_result = VerificationTools.test_robustness(
      agent_info.agent_path,
      [data_file],  # In a real scenario, we would use multiple data files for different market conditions
      %{
        report_file: "#{config.instrument}_robustness_report.md"
      }
    )

    case robustness_result do
      {:ok, robustness} ->
        UI.print_success("Robustness test completed")
        UI.print_info("Overall Consistency: #{Float.round(robustness.summary.overall_consistency * 100, 2)}%")
        UI.print_info("Robustness Score: #{Float.round(robustness.summary.robustness_score, 2)}")
        UI.print_info("Report saved to #{config.instrument}_robustness_report.md")
        {:ok, robustness}

      {:error, reason} ->
        {:error, 7, "Robustness test failed: #{reason}"}
    end
  end

  defp print_workflow_success(config) do
    IO.puts("\n=========================================")
    IO.puts("Workflow completed successfully!")
    IO.puts("=========================================")
    IO.puts("\nYour trained agent is now deployed and trading on your OANDA practice account.")
    IO.puts("It will continue to learn and adapt to changing market conditions.")
    IO.puts("\nMonitor its performance and adjust risk parameters as needed.")
    IO.puts("For more advanced options, refer to the documentation in docs/algo_trading_guide.md")
  end
end

# Main execution
args = System.argv()

case ForexWorkflow.run(args) do
  {:ok, _result} ->
    # Successful execution, exit with status 0
    System.halt(0)

  {:error, _reason} ->
    # Failed execution, exit with status 1
    System.halt(1)
end
