# Cryptocurrency Trading Workflow Example
#
# This script demonstrates a complete end-to-end workflow for algorithmic trading with Bardo:
# 1. Download historical data from Gemini
# 2. Train a trading agent on the data
# 3. Evaluate the agent's performance
# 4. Deploy the agent for live trading
#
# Usage: mix run examples/crypto_trading_workflow.exs [instrument] [days_of_history] [api_key] [api_secret]
#   instrument: Cryptocurrency pair to trade (default: BTCUSD)
#   days_of_history: Number of days of historical data to use (default: 90)
#   api_key: Gemini API key (required for data download and live trading)
#   api_secret: Gemini API secret (required for data download and live trading)

require Logger

alias Bardo.Examples.Applications.AlgoTrading.TradingAPI
alias Bardo.Examples.Applications.AlgoTrading.DataDownloader
alias Bardo.Examples.Applications.AlgoTrading.AgentTrainer
alias Bardo.Examples.Applications.AlgoTrading.AgentRepository
alias Bardo.Examples.Applications.AlgoTrading.VerificationTools

# Parse command line arguments
args = System.argv()
instrument = Enum.at(args, 0, "BTCUSD")
days_of_history = case Enum.at(args, 1) do
  nil -> 90  # Default to 90 days
  days ->
    case Integer.parse(days) do
      {days_int, _} -> days_int
      :error -> 90
    end
end
api_key = Enum.at(args, 2, System.get_env("GEMINI_API_KEY"))
api_secret = Enum.at(args, 3, System.get_env("GEMINI_API_SECRET"))

# Configurable parameters - can be extracted to a config file
population_size = 5     # Size of population for genetic algorithm (default: 50)
generations = 3          # Number of generations to train (default: 100)
timeframe = "M15"        # Candle timeframe (default: "M15" = 15 minutes)

if is_nil(api_key) do
  IO.puts("ERROR: Gemini API key is required. Either provide it as the third argument or set the GEMINI_API_KEY environment variable.")
  System.halt(1)
end

if is_nil(api_secret) do
  IO.puts("ERROR: Gemini API secret is required. Either provide it as the fourth argument or set the GEMINI_API_SECRET environment variable.")
  System.halt(1)
end

IO.puts("=========================================")
IO.puts("Cryptocurrency Trading Workflow Example")
IO.puts("=========================================")
IO.puts("Instrument: #{instrument}")
IO.puts("Historical data: #{days_of_history} days")
IO.puts("Training parameters:")
IO.puts("  - Population size: #{population_size}")
IO.puts("  - Generations: #{generations}")
IO.puts("  - Timeframe: #{timeframe}")
IO.puts("Using Gemini API in sandbox mode")
IO.puts("=========================================")

# Progress bar helper function
defmodule ProgressBar do
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

# Function to format time in a human-readable way
format_elapsed_time = fn milliseconds ->
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

# Custom progress tracker that simulates progress for training
update_progress = fn agent_pid, total_steps ->
  # Calculate approximate time per step (1 second)
  step_time_ms = 1000

  spawn(fn ->
    Enum.reduce(1..total_steps, 0, fn step, _acc ->
      Process.sleep(step_time_ms)
      send(agent_pid, {:progress, step})
      step
    end)
    send(agent_pid, :stop)
  end)
end

# Step 1: Initialize the Gemini broker
IO.puts("\n[Step 1/7] Initializing Gemini broker...")

broker_config = %{
  api_key: api_key,
  api_secret: api_secret,
  live: false  # Use sandbox environment
}

case TradingAPI.init_broker(:gemini, api_key, %{api_secret: api_secret}) do
  {:ok, broker_state} ->
    IO.puts("✓ Successfully connected to Gemini")

    # Step 2: Download historical data
    IO.puts("\n[Step 2/7] Downloading historical data for #{instrument}...")

    # Initialize download progress tracking
    download_total_steps = 10
    download_progress_agent = spawn(fn ->
      progress_loop = fn loop_fn, current, total ->
        receive do
          {:progress, new_progress} ->
            ProgressBar.print(new_progress, total, 40, "  Download progress:")
            loop_fn.(loop_fn, new_progress, total)

          :stop ->
            # Ensure 100% is displayed
            ProgressBar.print(total, total, 40, "  Download progress:")
        after
          # Update every 500ms if no progress messages received
          500 ->
            ProgressBar.print(current, total, 40, "  Download progress:")
            loop_fn.(loop_fn, current, total)
        end
      end

      progress_loop.(progress_loop, 0, download_total_steps)
    end)

    # Start simulated progress updates for download
    update_progress.(download_progress_agent, download_total_steps)

    # Calculate date range based on days_of_history
    now = DateTime.utc_now()
    from_date = DateTime.add(now, -days_of_history * 24 * 60 * 60, :second)

    download_result = DataDownloader.download_data(
      Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini,
      broker_state,
      instrument,
      %{
        timeframe: timeframe,
        start_date: DateTime.to_iso8601(from_date),
        end_date: DateTime.to_iso8601(now)
      }
    )

    case download_result do
      {:ok, data_file} ->
        IO.puts("✓ Successfully downloaded data to #{data_file}")

        # Step 3: Train a trading agent
        IO.puts("\n[Step 3/7] Training an agent on the historical data...")
        IO.puts("  Using population size: #{population_size}, generations: #{generations}")

        # Calculate total estimated progress steps
        total_training_steps = population_size * generations

        # Initialize training progress tracking
        training_progress_agent = spawn(fn ->
          progress_loop = fn loop_fn, current, total ->
            receive do
              {:progress, new_progress} ->
                ProgressBar.print(new_progress, total, 40, "  Training progress:")
                loop_fn.(loop_fn, new_progress, total)

              :stop ->
                # Ensure 100% is displayed
                ProgressBar.print(total, total, 40, "  Training progress:")
            after
              # Update every 500ms if no progress messages received
              500 ->
                ProgressBar.print(current, total, 40, "  Training progress:")
                loop_fn.(loop_fn, current, total)
            end
          end

          progress_loop.(progress_loop, 0, total_training_steps)
        end)

        # Start simulated progress updates for training
        update_progress.(training_progress_agent, total_training_steps)

        # Training options
        training_options = %{
          population_size: population_size,
          generations: generations,
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

        training_start_time = System.monotonic_time(:millisecond)

        training_result = AgentTrainer.train_agent(
          instrument,
          data_file,
          training_options
        )

        # Stop training progress agent
        send(training_progress_agent, :stop)

        training_end_time = System.monotonic_time(:millisecond)
        training_time = training_end_time - training_start_time

        case training_result do
          {:ok, agent_info} ->
            IO.puts("\n✓ Successfully trained agent: #{agent_info.agent_id}")
            IO.puts("  Training time: #{format_elapsed_time.(training_time)}")
            IO.puts("  Fitness: #{Enum.join(agent_info.fitness, ", ")}")

            # Step 4: Store agent in the repository
            IO.puts("\n[Step 4/7] Storing the agent in the repository...")

            # Make a backup of all agents for this instrument
            backup_result = AgentRepository.backup_agents(instrument)

            case backup_result do
              {:ok, backup_dir} ->
                IO.puts("✓ Created backup of existing agents in #{backup_dir}")

                # Step 5: Evaluate the agent on historical data
                IO.puts("\n[Step 5/7] Evaluating the agent's performance...")

                # Initialize backtest progress tracking
                backtest_total_steps = 20
                backtest_progress_agent = spawn(fn ->
                  progress_loop = fn loop_fn, current, total ->
                    receive do
                      {:progress, new_progress} ->
                        ProgressBar.print(new_progress, total, 40, "  Evaluation progress:")
                        loop_fn.(loop_fn, new_progress, total)

                      :stop ->
                        # Ensure 100% is displayed
                        ProgressBar.print(total, total, 40, "  Evaluation progress:")
                    after
                      # Update every 500ms if no progress messages received
                      500 ->
                        ProgressBar.print(current, total, 40, "  Evaluation progress:")
                        loop_fn.(loop_fn, current, total)
                    end
                  end

                  progress_loop.(progress_loop, 0, backtest_total_steps)
                end)

                # Start simulated progress updates for backtest
                update_progress.(backtest_progress_agent, backtest_total_steps)

                backtest_result = VerificationTools.run_backtest(
                  agent_info.agent_path,
                  data_file,
                  %{
                    initial_balance: 10000.0,
                    risk_per_trade: 1.0,
                    commission: 0.25,  # Higher commission for crypto
                    slippage: 0.1,     # Lower slippage in percentage
                    report_file: "#{instrument}_backtest_report.md"
                  }
                )

                case backtest_result do
                  {:ok, performance} ->
                    IO.puts("✓ Backtest completed")
                    IO.puts("  Profit/Loss: $#{Float.round(performance.profit_loss, 2)} (#{Float.round(performance.profit_percentage, 2)}%)")
                    IO.puts("  Win Rate: #{Float.round(performance.win_rate * 100, 2)}%")
                    IO.puts("  Max Drawdown: #{Float.round(performance.max_drawdown, 2)}%")
                    IO.puts("  Profit Factor: #{Float.round(performance.profit_factor, 2)}")
                    IO.puts("  Report saved to #{instrument}_backtest_report.md")

                    # Step 6: Deploy agent for paper trading
                    IO.puts("\n[Step 6/7] Deploying the agent for paper trading...")

                    deploy_result = TradingAPI.deploy_agent(
                      agent_info.agent_path,
                      :gemini,
                      broker_state,
                      %{
                        instrument: instrument,
                        risk_per_trade: 1.0,
                        max_drawdown: 15.0,      # Higher drawdown allowed for volatile crypto
                        continuous_learning: true
                      }
                    )

                    case deploy_result do
                      {:ok, agent_id} ->
                        IO.puts("✓ Successfully deployed agent: #{agent_id}")

                        # Step 7: Compare with other agents
                        IO.puts("\n[Step 7/7] Comparing agent performance...")

                        # Initialize comparison progress tracking
                        comparison_total_steps = 15
                        comparison_progress_agent = spawn(fn ->
                          progress_loop = fn loop_fn, current, total ->
                            receive do
                              {:progress, new_progress} ->
                                ProgressBar.print(new_progress, total, 40, "  Comparison progress:")
                                loop_fn.(loop_fn, new_progress, total)

                              :stop ->
                                # Ensure 100% is displayed
                                ProgressBar.print(total, total, 40, "  Comparison progress:")
                            after
                              # Update every 500ms if no progress messages received
                              500 ->
                                ProgressBar.print(current, total, 40, "  Comparison progress:")
                                loop_fn.(loop_fn, current, total)
                            end
                          end

                          progress_loop.(progress_loop, 0, comparison_total_steps)
                        end)

                        # Start simulated progress updates for comparison
                        update_progress.(comparison_progress_agent, comparison_total_steps)

                        # Get previous best agent if available
                        previous_agents_result = AgentRepository.list_agents(instrument, %{
                          sort_by: :performance,
                          sort_order: :desc,
                          limit: 5
                        })

                        case previous_agents_result do
                          {:ok, previous_agents} ->
                            if length(previous_agents) > 1 do
                              agent_paths = Enum.map(previous_agents, & &1.file_path)

                              comparison_result = VerificationTools.compare_agents(
                                agent_paths,
                                data_file,
                                %{
                                  report_file: "#{instrument}_comparison_report.md"
                                }
                              )

                              case comparison_result do
                                {:ok, comparison} ->
                                  IO.puts("✓ Agent comparison completed")
                                  best_agent = List.first(comparison.comparison.overall_ranking)
                                  IO.puts("  Best agent: #{best_agent.id} (Score: #{Float.round(best_agent.score, 2)})")
                                  IO.puts("  Report saved to #{instrument}_comparison_report.md")

                                  IO.puts("\n=========================================")
                                  IO.puts("Workflow completed successfully!")
                                  IO.puts("=========================================")
                                  IO.puts("\nYour trained agent is now deployed and trading on your Gemini sandbox account.")
                                  IO.puts("It will continue to learn and adapt to changing market conditions.")
                                  IO.puts("\nMonitor its performance and adjust risk parameters as needed.")
                                  IO.puts("For more advanced options, refer to the documentation in docs/algo_trading_guide.md")

                                {:error, reason} ->
                                  IO.puts("✗ Agent comparison failed: #{reason}")
                              end
                            else
                              IO.puts("ℹ No previous agents to compare with")

                              IO.puts("\n=========================================")
                              IO.puts("Workflow completed successfully!")
                              IO.puts("=========================================")
                              IO.puts("\nYour trained agent is now deployed and trading on your Gemini sandbox account.")
                            end

                          {:error, reason} ->
                            IO.puts("✗ Failed to retrieve previous agents: #{reason}")
                        end

                      {:error, reason} ->
                        IO.puts("✗ Agent deployment failed: #{reason}")
                    end

                  {:error, reason} ->
                    IO.puts("✗ Backtest failed: #{reason}")
                end

              {:error, reason} ->
                IO.puts("✗ Failed to create backup: #{reason}")
            end

          {:error, reason} ->
            IO.puts("✗ Agent training failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("✗ Data download failed: #{reason}")
    end

  {:error, reason} ->
    IO.puts("✗ Failed to connect to Gemini: #{reason}")
end
