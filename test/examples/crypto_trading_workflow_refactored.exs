# Cryptocurrency Trading Workflow Example (Refactored)
#
# This script demonstrates a complete end-to-end workflow for algorithmic trading with Bardo
# using a more testable architecture with dependency injection and separation of concerns.
#
# Usage: mix run examples/crypto_trading_workflow_refactored.exs [instrument] [days_of_history] [api_key] [api_secret]

require Logger

# Import core modules
alias Bardo.Examples.Applications.AlgoTrading.TradingAPI
alias Bardo.Examples.Applications.AlgoTrading.DataDownloader
alias Bardo.Examples.Applications.AlgoTrading.AgentTrainer
alias Bardo.Examples.Applications.AlgoTrading.AgentRepository
alias Bardo.Examples.Applications.AlgoTrading.VerificationTools
alias Bardo.Examples.Applications.AlgoTrading.Brokers.Gemini

# Define WorkflowManager module to encapsulate the workflow logic
defmodule WorkflowManager do
  @moduledoc """
  Manages the cryptocurrency trading workflow with proper dependency injection
  and separation of concerns for better testability.
  """

  @type progress_tracker :: pid()
  @type broker_module :: module()
  @type broker_state :: map()

  # Define a struct for configuration
  defstruct [
    :instrument,
    :days_of_history,
    :api_key,
    :api_secret,
    :broker_type,
    :broker_module,
    :population_size,
    :generations,
    :timeframe,
    :live_mode
  ]

  @doc """
  Initialize a new workflow configuration with defaults.
  """
  def new(args \\ []) do
    # Parse command line arguments or use provided args
    args = if Enum.empty?(args), do: System.argv(), else: args
    
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
    
    %__MODULE__{
      instrument: instrument,
      days_of_history: days_of_history,
      api_key: api_key,
      api_secret: api_secret,
      broker_type: :gemini,
      broker_module: Gemini,
      population_size: 5,
      generations: 3,
      timeframe: "M15",
      live_mode: false
    }
  end

  @doc """
  Validate required configuration values.
  """
  def validate(config) do
    cond do
      is_nil(config.api_key) ->
        {:error, "Gemini API key is required"}
        
      is_nil(config.api_secret) ->
        {:error, "Gemini API secret is required"}
        
      true ->
        {:ok, config}
    end
  end

  @doc """
  Print workflow configuration.
  """
  def print_config(config) do
    IO.puts("=========================================")
    IO.puts("Cryptocurrency Trading Workflow Example")
    IO.puts("=========================================")
    IO.puts("Instrument: #{config.instrument}")
    IO.puts("Historical data: #{config.days_of_history} days")
    IO.puts("Training parameters:")
    IO.puts("  - Population size: #{config.population_size}")
    IO.puts("  - Generations: #{config.generations}")
    IO.puts("  - Timeframe: #{config.timeframe}")
    IO.puts("Using Gemini API in #{if config.live_mode, do: "LIVE", else: "sandbox"} mode")
    IO.puts("=========================================")
  end

  @doc """
  Run the complete workflow.
  """
  def run(config, dependencies \\ %{}) do
    # Inject default dependencies if not provided
    deps = %{
      trading_api: Map.get(dependencies, :trading_api, TradingAPI),
      data_downloader: Map.get(dependencies, :data_downloader, DataDownloader),
      agent_trainer: Map.get(dependencies, :agent_trainer, AgentTrainer),
      agent_repository: Map.get(dependencies, :agent_repository, AgentRepository),
      verification_tools: Map.get(dependencies, :verification_tools, VerificationTools),
      progress_tracker: Map.get(dependencies, :progress_tracker, ProgressTracker)
    }
    
    with {:ok, config} <- validate(config),
         {:ok, broker_state} <- init_broker(config, deps.trading_api),
         {:ok, data_file} <- download_data(config, broker_state, deps),
         {:ok, agent_info} <- train_agent(config, data_file, deps),
         {:ok, backup_dir} <- backup_agents(config, deps.agent_repository),
         {:ok, performance} <- run_backtest(config, agent_info, data_file, deps),
         {:ok, agent_id} <- deploy_agent(config, agent_info, broker_state, deps),
         {:ok, comparison} <- compare_agents(config, agent_info, data_file, deps) do
      
      # Report success
      IO.puts("\n=========================================")
      IO.puts("Workflow completed successfully!")
      IO.puts("=========================================")
      IO.puts("\nYour trained agent is now deployed and trading on your Gemini#{if config.live_mode, do: "", else: " sandbox"} account.")
      IO.puts("It will continue to learn and adapt to changing market conditions.")
      IO.puts("\nMonitor its performance and adjust risk parameters as needed.")
      IO.puts("For more advanced options, refer to the documentation in docs/algo_trading_guide.md")
      
      # Return results
      {:ok, %{
        data_file: data_file,
        agent_info: agent_info,
        performance: performance,
        agent_id: agent_id
      }}
    else
      {:error, step, reason} ->
        IO.puts("\n✗ Workflow failed at step: #{step}")
        IO.puts("  Reason: #{reason}")
        {:error, step, reason}
        
      {:error, reason} ->
        IO.puts("\n✗ Workflow failed during initialization")
        IO.puts("  Reason: #{reason}")
        {:error, "initialization", reason}
    end
  end

  # Step 1: Initialize broker
  defp init_broker(config, trading_api) do
    IO.puts("\n[Step 1/7] Initializing #{config.broker_type} broker...")
    
    case trading_api.init_broker(config.broker_type, config.api_key, %{
      api_secret: config.api_secret,
      live: config.live_mode
    }) do
      {:ok, broker_state} ->
        IO.puts("✓ Successfully connected to #{config.broker_type}")
        {:ok, broker_state}
        
      {:error, reason} ->
        {:error, "broker_initialization", reason}
    end
  end

  # Step 2: Download data
  defp download_data(config, broker_state, deps) do
    IO.puts("\n[Step 2/7] Downloading historical data for #{config.instrument}...")
    
    # Initialize progress tracking
    download_total_steps = 10
    download_progress_agent = deps.progress_tracker.start(download_total_steps, "Download progress")
    
    # Calculate date range based on days_of_history
    now = DateTime.utc_now()
    from_date = DateTime.add(now, -config.days_of_history * 24 * 60 * 60, :second)
    
    # Perform download
    result = deps.data_downloader.download_data(
      config.broker_module,
      broker_state,
      config.instrument,
      %{
        timeframe: config.timeframe,
        start_date: DateTime.to_iso8601(from_date),
        end_date: DateTime.to_iso8601(now)
      }
    )
    
    # Stop progress tracker
    deps.progress_tracker.stop(download_progress_agent)
    
    case result do
      {:ok, data_file} ->
        IO.puts("✓ Successfully downloaded data to #{data_file}")
        {:ok, data_file}
        
      {:error, reason} ->
        {:error, "data_download", reason}
    end
  end

  # Step 3: Train agent
  defp train_agent(config, data_file, deps) do
    IO.puts("\n[Step 3/7] Training an agent on the historical data...")
    IO.puts("  Using population size: #{config.population_size}, generations: #{config.generations}")
    
    # Calculate total estimated progress steps
    total_training_steps = config.population_size * config.generations
    
    # Initialize training progress tracking
    training_progress_agent = deps.progress_tracker.start(total_training_steps, "Training progress")
    
    # Training options
    training_options = %{
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
    
    training_start_time = System.monotonic_time(:millisecond)
    
    # Train agent
    result = deps.agent_trainer.train_agent(
      config.instrument,
      data_file,
      training_options
    )
    
    # Stop progress tracker
    deps.progress_tracker.stop(training_progress_agent)
    
    training_end_time = System.monotonic_time(:millisecond)
    training_time = training_end_time - training_start_time
    
    case result do
      {:ok, agent_info} ->
        IO.puts("\n✓ Successfully trained agent: #{agent_info.agent_id}")
        IO.puts("  Training time: #{format_elapsed_time(training_time)}")
        IO.puts("  Fitness: #{Enum.join(agent_info.fitness, ", ")}")
        {:ok, agent_info}
        
      {:error, reason} ->
        {:error, "agent_training", reason}
    end
  end

  # Step 4: Backup existing agents
  defp backup_agents(config, agent_repository) do
    IO.puts("\n[Step 4/7] Storing the agent in the repository...")
    
    # Make a backup of all agents for this instrument
    case agent_repository.backup_agents(config.instrument) do
      {:ok, backup_dir} ->
        IO.puts("✓ Created backup of existing agents in #{backup_dir}")
        {:ok, backup_dir}
        
      {:error, reason} ->
        {:error, "agent_backup", reason}
    end
  end

  # Step 5: Run backtest
  defp run_backtest(config, agent_info, data_file, deps) do
    IO.puts("\n[Step 5/7] Evaluating the agent's performance...")
    
    # Initialize backtest progress tracking
    backtest_total_steps = 20
    backtest_progress_agent = deps.progress_tracker.start(backtest_total_steps, "Evaluation progress")
    
    # Run backtest
    result = deps.verification_tools.run_backtest(
      agent_info.agent_path,
      data_file,
      %{
        initial_balance: 10000.0,
        risk_per_trade: 1.0,
        commission: 0.25,  # Higher commission for crypto
        slippage: 0.1,     # Lower slippage in percentage
        report_file: "#{config.instrument}_backtest_report.md"
      }
    )
    
    # Stop progress tracker
    deps.progress_tracker.stop(backtest_progress_agent)
    
    case result do
      {:ok, performance} ->
        IO.puts("✓ Backtest completed")
        IO.puts("  Profit/Loss: $#{Float.round(performance.profit_loss, 2)} (#{Float.round(performance.profit_percentage, 2)}%)")
        IO.puts("  Win Rate: #{Float.round(performance.win_rate * 100, 2)}%")
        IO.puts("  Max Drawdown: #{Float.round(performance.max_drawdown, 2)}%")
        IO.puts("  Profit Factor: #{Float.round(performance.profit_factor, 2)}")
        IO.puts("  Report saved to #{config.instrument}_backtest_report.md")
        {:ok, performance}
        
      {:error, reason} ->
        {:error, "backtest", reason}
    end
  end

  # Step 6: Deploy agent
  defp deploy_agent(config, agent_info, broker_state, deps) do
    IO.puts("\n[Step 6/7] Deploying the agent for paper trading...")
    
    # Deploy the agent
    result = deps.trading_api.deploy_agent(
      agent_info.agent_path,
      config.broker_type,
      broker_state,
      %{
        instrument: config.instrument,
        risk_per_trade: 1.0,
        max_drawdown: 15.0,      # Higher drawdown allowed for volatile crypto
        continuous_learning: true
      }
    )
    
    case result do
      {:ok, agent_id} ->
        IO.puts("✓ Successfully deployed agent: #{agent_id}")
        {:ok, agent_id}
        
      {:error, reason} ->
        {:error, "agent_deployment", reason}
    end
  end

  # Step 7: Compare with other agents
  defp compare_agents(config, agent_info, data_file, deps) do
    IO.puts("\n[Step 7/7] Comparing agent performance...")
    
    # Initialize comparison progress tracking
    comparison_total_steps = 15
    comparison_progress_agent = deps.progress_tracker.start(comparison_total_steps, "Comparison progress")
    
    # Get previous best agent if available
    result = deps.agent_repository.list_agents(config.instrument, %{
      sort_by: :performance,
      sort_order: :desc,
      limit: 5
    })
    
    case result do
      {:ok, previous_agents} ->
        if length(previous_agents) > 1 do
          agent_paths = Enum.map(previous_agents, & &1.file_path)
          
          # Run comparison
          comparison_result = deps.verification_tools.compare_agents(
            agent_paths,
            data_file,
            %{
              report_file: "#{config.instrument}_comparison_report.md"
            }
          )
          
          # Stop progress tracker
          deps.progress_tracker.stop(comparison_progress_agent)
          
          case comparison_result do
            {:ok, comparison} ->
              best_agent = List.first(comparison.comparison.overall_ranking)
              IO.puts("✓ Agent comparison completed")
              IO.puts("  Best agent: #{best_agent.id} (Score: #{Float.round(best_agent.score, 2)})")
              IO.puts("  Report saved to #{config.instrument}_comparison_report.md")
              {:ok, comparison}
              
            {:error, reason} ->
              {:error, "agent_comparison", reason}
          end
        else
          # Stop progress tracker
          deps.progress_tracker.stop(comparison_progress_agent)
          
          IO.puts("ℹ No previous agents to compare with")
          {:ok, nil}
        end
        
      {:error, reason} ->
        # Stop progress tracker
        deps.progress_tracker.stop(comparison_progress_agent)
        
        {:error, "agent_listing", reason}
    end
  end

  # Helper function to format elapsed time
  defp format_elapsed_time(milliseconds) do
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
end

# Progress tracking module (extracted for testability)
defmodule ProgressTracker do
  @moduledoc """
  Handles progress tracking with a nice visual progress bar.
  """
  
  @doc """
  Start a progress tracker with the given total steps and description.
  Returns a process ID that can be used to update and stop the tracker.
  """
  def start(total_steps, description) do
    spawn(fn ->
      progress_loop(0, total_steps, description)
    end)
  end
  
  @doc """
  Update the progress of a tracker.
  """
  def update(tracker_pid, progress) do
    send(tracker_pid, {:progress, progress})
  end
  
  @doc """
  Simulate progress updates at regular intervals.
  """
  def simulate(tracker_pid, total_steps, step_time_ms \\ 1000) do
    spawn(fn ->
      Enum.reduce(1..total_steps, 0, fn step, _acc ->
        Process.sleep(step_time_ms)
        update(tracker_pid, step)
        step
      end)
      stop(tracker_pid)
    end)
  end
  
  @doc """
  Stop a progress tracker.
  """
  def stop(tracker_pid) do
    send(tracker_pid, :stop)
  end
  
  # Internal function to handle progress updates
  defp progress_loop(current, total, description) do
    print_progress_bar(current, total, 40, description)
    
    receive do
      {:progress, new_progress} ->
        progress_loop(new_progress, total, description)
        
      :stop ->
        # Ensure 100% is displayed
        print_progress_bar(total, total, 40, description)
        
    after
      # Update display every 500ms even if no progress messages received
      500 ->
        progress_loop(current, total, description)
    end
  end
  
  # Print a nice progress bar
  defp print_progress_bar(current, total, bar_width, description) do
    percent = Float.round(current / total * 100, 1)
    completed_bars = trunc(bar_width * current / total)
    remaining_bars = bar_width - completed_bars
    completed_str = String.duplicate("█", completed_bars)
    remaining_str = String.duplicate("░", remaining_bars)
    
    if description do
      IO.write("\r  #{description}: [#{completed_str}#{remaining_str}] #{percent}%     ")
    else
      IO.write("\r[#{completed_str}#{remaining_str}] #{percent}%     ")
    end
    
    if current >= total, do: IO.write("\n")
  end
end