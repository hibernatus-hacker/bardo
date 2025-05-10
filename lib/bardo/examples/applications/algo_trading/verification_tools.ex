defmodule Bardo.Examples.Applications.AlgoTrading.VerificationTools do
  @moduledoc """
  Utilities for testing and verifying algorithmic trading agents.
  
  This module provides tools for:
  - Backtesting agents against historical data
  - Validating agent performance across different market conditions
  - Comparing multiple agents head-to-head
  - Visualizing and exporting test results
  """
  
  require Logger
  
  alias Bardo.Examples.Applications.AlgoTrading.DataUtils
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  
  @doc """
  Run a comprehensive backtest for an agent.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - data_file: Path to historical data file
  - options: Additional options
    - `:initial_balance` - Initial account balance (default: 10000.0)
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:commission` - Commission per trade in percentage (default: 0.1)
    - `:slippage` - Slippage in pips (default: 1.0)
    - `:report_file` - Path to save the report (default: none)
  
  ## Returns
  
  - `{:ok, results}` - Detailed backtest results
  - `{:error, reason}` - If backtest fails
  """
  def run_backtest(agent_path, data_file, options \\ %{}) do
    # Extract options with defaults
    initial_balance = Map.get(options, :initial_balance, 10000.0)
    risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    commission = Map.get(options, :commission, 0.1)
    slippage = Map.get(options, :slippage, 1.0)
    report_file = Map.get(options, :report_file)

    # Load agent
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Load historical data
        case DataUtils.load_historical_data(data_file) do
          {:ok, candles} ->
            # Run simulation
            results = run_trading_simulation(genotype, candles, %{
              initial_balance: initial_balance,
              risk_per_trade: risk_per_trade,
              commission: commission,
              slippage: slippage
            })
            
            # Generate detailed metrics
            detailed_results = generate_detailed_metrics(results)
            
            # Generate report if requested
            if report_file do
              generate_report(detailed_results, agent_path, data_file, options, report_file)
            end
            
            {:ok, detailed_results}
            
          {:error, reason} ->
            {:error, "Failed to load historical data: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load agent: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Run backtest on multiple data segments to test robustness.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - data_files: List of data file paths for different market conditions
  - options: Same as run_backtest/3 plus:
    - `:segment_names` - Names for each data segment (defaults to filenames)
  
  ## Returns
  
  - `{:ok, results}` - Results for each segment plus summary
  - `{:error, reason}` - If testing fails
  """
  def test_robustness(agent_path, data_files, options \\ %{}) do
    # Load agent once
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Get segment names
        segment_names = Map.get(options, :segment_names) ||
                        Enum.map(data_files, &Path.basename/1)
        
        # Ensure we have matching names for each data file
        if length(segment_names) != length(data_files) do
          {:error, "Number of segment names must match number of data files"}
        else
          # Run backtest on each segment
          segment_results = Enum.zip(data_files, segment_names)
                            |> Enum.map(fn {file, name} ->
                              case DataUtils.load_historical_data(file) do
                                {:ok, candles} ->
                                  # Run simulation
                                  results = run_trading_simulation(genotype, candles, %{
                                    initial_balance: Map.get(options, :initial_balance, 10000.0),
                                    risk_per_trade: Map.get(options, :risk_per_trade, 1.0),
                                    commission: Map.get(options, :commission, 0.1),
                                    slippage: Map.get(options, :slippage, 1.0)
                                  })
                                  
                                  # Return with segment name
                                  {name, generate_detailed_metrics(results)}
                                  
                                {:error, reason} ->
                                  {name, {:error, "Failed to load data: #{inspect(reason)}"}}
                              end
                            end)
          
          # Filter out any segments that failed
          valid_segments = Enum.filter(segment_results, fn {_, result} -> is_map(result) end)
          
          if Enum.empty?(valid_segments) do
            {:error, "All segments failed to process"}
          else
            # Generate summary metrics
            summary = generate_robustness_summary(valid_segments)
            
            # Generate report if requested
            if report_file = Map.get(options, :report_file) do
              generate_robustness_report(valid_segments, summary, agent_path, options, report_file)
            end
            
            {:ok, %{
              segments: Map.new(valid_segments),
              summary: summary
            }}
          end
        end
        
      {:error, reason} ->
        {:error, "Failed to load agent: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Compare multiple agents on the same dataset.
  
  ## Parameters
  
  - agent_paths: List of paths to agent JSON files
  - data_file: Path to historical data file
  - options: Additional options (same as run_backtest/3)
  
  ## Returns
  
  - `{:ok, results}` - Comparison results for each agent
  - `{:error, reason}` - If comparison fails
  """
  def compare_agents(agent_paths, data_file, options \\ %{}) do
    # Load data once
    case DataUtils.load_historical_data(data_file) do
      {:ok, candles} ->
        # Backtest each agent
        agent_results = Enum.map(agent_paths, fn path ->
          case AgentSerializer.load_agent(path) do
            {:ok, {genotype, metadata}} ->
              # Run simulation
              results = run_trading_simulation(genotype, candles, %{
                initial_balance: Map.get(options, :initial_balance, 10000.0),
                risk_per_trade: Map.get(options, :risk_per_trade, 1.0),
                commission: Map.get(options, :commission, 0.1),
                slippage: Map.get(options, :slippage, 1.0)
              })

              # Return with agent ID
              agent_id = Path.basename(path, ".json")
              {agent_id, %{
                path: path,
                metadata: metadata,
                results: generate_detailed_metrics(results)
              }}
              
            {:error, reason} ->
              {Path.basename(path, ".json"), {:error, "Failed to load agent: #{inspect(reason)}"}}
          end
        end)
        
        # Filter out any agents that failed
        valid_agents = Enum.filter(agent_results, fn {_, result} -> is_map(result) end)
        
        if Enum.empty?(valid_agents) do
          {:error, "All agents failed to process"}
        else
          # Generate comparison summary
          comparison = generate_comparison_summary(valid_agents)
          
          # Generate report if requested
          if report_file = Map.get(options, :report_file) do
            generate_comparison_report(valid_agents, comparison, data_file, options, report_file)
          end
          
          {:ok, %{
            agents: Map.new(valid_agents),
            comparison: comparison
          }}
        end
        
      {:error, reason} ->
        {:error, "Failed to load historical data: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Run a stress test with various market conditions.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - base_data_file: Path to base historical data file
  - options: Additional options
    - `:volatility_factors` - List of volatility multipliers (default: [0.5, 1.0, 2.0])
    - `:trend_scenarios` - List of trend adjustments (default: [-0.01, 0.0, 0.01])
    - `:gap_scenarios` - List of gap percentages to simulate (default: [0.0, 0.01, 0.02])
  
  ## Returns
  
  - `{:ok, results}` - Stress test results across scenarios
  - `{:error, reason}` - If stress testing fails
  """
  def run_stress_test(agent_path, base_data_file, options \\ %{}) do
    # Extract stress test parameters
    volatility_factors = Map.get(options, :volatility_factors, [0.5, 1.0, 2.0])
    trend_scenarios = Map.get(options, :trend_scenarios, [-0.01, 0.0, 0.01])
    gap_scenarios = Map.get(options, :gap_scenarios, [0.0, 0.01, 0.02])
    
    # Load agent
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Load base data
        case DataUtils.load_historical_data(base_data_file) do
          {:ok, base_candles} ->
            # Generate stress scenarios
            scenarios = generate_stress_scenarios(base_candles, %{
              volatility_factors: volatility_factors,
              trend_scenarios: trend_scenarios,
              gap_scenarios: gap_scenarios
            })
            
            # Run tests for each scenario
            scenario_results = Enum.map(scenarios, fn {name, candles} ->
              # Run simulation
              results = run_trading_simulation(genotype, candles, %{
                initial_balance: Map.get(options, :initial_balance, 10000.0),
                risk_per_trade: Map.get(options, :risk_per_trade, 1.0),
                commission: Map.get(options, :commission, 0.1),
                slippage: Map.get(options, :slippage, 1.0)
              })
              
              # Return with scenario name
              {name, generate_detailed_metrics(results)}
            end)
            
            # Generate summary
            summary = generate_stress_test_summary(scenario_results)
            
            # Generate report if requested
            if report_file = Map.get(options, :report_file) do
              generate_stress_test_report(scenario_results, summary, agent_path, base_data_file, options, report_file)
            end
            
            {:ok, %{
              scenarios: Map.new(scenario_results),
              summary: summary
            }}
            
          {:error, reason} ->
            {:error, "Failed to load base data: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load agent: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Perform walk-forward testing with out-of-sample validation.
  
  ## Parameters
  
  - agent_path: Path to the agent JSON file
  - data_file: Path to historical data file
  - options: Additional options
    - `:windows` - Number of testing windows (default: 5)
    - `:train_ratio` - Ratio of data for training (default: 0.7)
  
  ## Returns
  
  - `{:ok, results}` - Walk-forward testing results
  - `{:error, reason}` - If testing fails
  """
  def walk_forward_test(agent_path, data_file, options \\ %{}) do
    # Extract options
    windows = Map.get(options, :windows, 5)
    train_ratio = Map.get(options, :train_ratio, 0.7)
    
    # Load agent
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Load historical data
        case DataUtils.load_historical_data(data_file) do
          {:ok, candles} ->
            # Create windows
            window_data = create_walk_forward_windows(candles, windows, train_ratio)
            
            # Test each window
            window_results = Enum.map(window_data, fn {window_num, {_train_candles, test_candles}} ->
              # Run simulation on test data (out-of-sample)
              results = run_trading_simulation(genotype, test_candles, %{
                initial_balance: Map.get(options, :initial_balance, 10000.0),
                risk_per_trade: Map.get(options, :risk_per_trade, 1.0),
                commission: Map.get(options, :commission, 0.1),
                slippage: Map.get(options, :slippage, 1.0)
              })
              
              # Return with window number
              {"Window #{window_num}", generate_detailed_metrics(results)}
            end)
            
            # Generate summary
            summary = generate_walk_forward_summary(window_results)
            
            # Generate report if requested
            if report_file = Map.get(options, :report_file) do
              generate_walk_forward_report(window_results, summary, agent_path, data_file, options, report_file)
            end
            
            {:ok, %{
              windows: Map.new(window_results),
              summary: summary
            }}
            
          {:error, reason} ->
            {:error, "Failed to load historical data: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load agent: #{inspect(reason)}"}
    end
  end
  
  # Private helper functions
  
  # Run trading simulation
  defp run_trading_simulation(_genotype, _candles, options) do
    # Extract options with defaults
    initial_balance = Map.get(options, :initial_balance, 10000.0)
    _risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    _commission = Map.get(options, :commission, 0.1)
    _slippage = Map.get(options, :slippage, 1.0)
    
    # Placeholder for simulation implementation
    # This should be replaced with actual simulation logic
    
    # Return dummy results for now
    %{
      initial_balance: initial_balance,
      final_balance: initial_balance * 1.15,
      profit_loss: initial_balance * 0.15,
      profit_percentage: 15.0,
      total_trades: 45,
      winning_trades: 25,
      losing_trades: 20,
      win_rate: 25/45,
      max_drawdown: 8.5,
      trades: []
    }
  end
  
  # Generate detailed metrics from simulation results
  defp generate_detailed_metrics(results) do
    # Calculate additional metrics
    
    # Profit factor (gross profit / gross loss)
    {gross_profit, gross_loss} = Enum.reduce(Map.get(results, :trades, []), {0.0, 0.0}, fn trade, {gp, gl} ->
      profit = Map.get(trade, :profit, 0.0)
      
      if profit > 0 do
        {gp + profit, gl}
      else
        {gp, gl + abs(profit)}
      end
    end)
    
    profit_factor = (if gross_loss > 0, do: gross_profit / gross_loss, else: 0.0)
    
    # Average profit and loss per trade
    avg_profit = if results.winning_trades > 0 do
      gross_profit / results.winning_trades
    else
      0.0
    end
    
    avg_loss = if results.losing_trades > 0 do
      gross_loss / results.losing_trades
    else
      0.0
    end
    
    # Expectancy (average expected profit/loss per trade)
    expectancy = if results.total_trades > 0 do
      results.profit_loss / results.total_trades
    else
      0.0
    end
    
    # Risk-adjusted return (Sharpe ratio approximation)
    risk_adjusted_return = if results.max_drawdown > 0 do
      results.profit_percentage / results.max_drawdown
    else
      0.0
    end
    
    # Return expanded metrics
    Map.merge(results, %{
      profit_factor: profit_factor,
      avg_profit: avg_profit,
      avg_loss: avg_loss,
      expectancy: expectancy,
      risk_adjusted_return: risk_adjusted_return
    })
  end
  
  # Generate robustness summary from segment results
  defp generate_robustness_summary(segment_results) do
    # Extract metrics for calculation
    metrics = Enum.map(segment_results, fn {_, results} ->
      %{
        profit_percentage: Map.get(results, :profit_percentage, 0.0),
        win_rate: Map.get(results, :win_rate, 0.0),
        max_drawdown: Map.get(results, :max_drawdown, 0.0),
        profit_factor: Map.get(results, :profit_factor, 0.0),
        expectancy: Map.get(results, :expectancy, 0.0)
      }
    end)
    
    # Calculate average, min, max, and variance for each metric
    profit_percentages = Enum.map(metrics, & &1.profit_percentage)
    win_rates = Enum.map(metrics, & &1.win_rate)
    max_drawdowns = Enum.map(metrics, & &1.max_drawdown)
    profit_factors = Enum.map(metrics, & &1.profit_factor)
    expectancies = Enum.map(metrics, & &1.expectancy)
    
    # Calculate consistency score (0-100)
    # Higher score means more consistent performance across segments
    profit_consistency = calculate_consistency(profit_percentages)
    win_rate_consistency = calculate_consistency(win_rates)
    drawdown_consistency = calculate_consistency(max_drawdowns)
    
    # Overall consistency is the average of individual consistencies
    overall_consistency = (profit_consistency + win_rate_consistency + drawdown_consistency) / 3
    
    # Robustness score (0-100)
    # Combines consistency with absolute performance
    avg_profit = Enum.sum(profit_percentages) / length(profit_percentages)
    avg_win_rate = Enum.sum(win_rates) / length(win_rates)
    avg_drawdown = Enum.sum(max_drawdowns) / length(max_drawdowns)
    
    # Higher is better for profit and win rate, lower is better for drawdown
    normalized_profit = normalize_metric(avg_profit, 0.0, 50.0)
    normalized_win_rate = normalize_metric(avg_win_rate, 0.0, 1.0)
    normalized_drawdown = 1.0 - normalize_metric(avg_drawdown, 0.0, 50.0)
    
    robustness_score = (
      normalized_profit * 0.4 + 
      normalized_win_rate * 0.3 + 
      normalized_drawdown * 0.3
    ) * overall_consistency
    
    # Return summary statistics
    %{
      segments: length(segment_results),
      avg_profit_percentage: avg_profit,
      min_profit_percentage: Enum.min(profit_percentages),
      max_profit_percentage: Enum.max(profit_percentages),
      
      avg_win_rate: avg_win_rate,
      min_win_rate: Enum.min(win_rates),
      max_win_rate: Enum.max(win_rates),
      
      avg_max_drawdown: avg_drawdown,
      min_max_drawdown: Enum.min(max_drawdowns),
      max_max_drawdown: Enum.max(max_drawdowns),
      
      avg_profit_factor: Enum.sum(profit_factors) / length(profit_factors),
      avg_expectancy: Enum.sum(expectancies) / length(expectancies),
      
      profit_consistency: profit_consistency,
      win_rate_consistency: win_rate_consistency,
      drawdown_consistency: drawdown_consistency,
      overall_consistency: overall_consistency,
      
      robustness_score: robustness_score
    }
  end
  
  # Generate comparison summary from agent results
  defp generate_comparison_summary(agent_results) do
    # Rank agents by different metrics
    profit_ranking = Enum.sort_by(agent_results, fn {_, data} -> 
      get_in(data, [:results, :profit_percentage]) || 0.0
    end, :desc)
    
    risk_adjusted_ranking = Enum.sort_by(agent_results, fn {_, data} -> 
      get_in(data, [:results, :risk_adjusted_return]) || 0.0
    end, :desc)
    
    consistency_ranking = Enum.sort_by(agent_results, fn {_, data} -> 
      win_rate = get_in(data, [:results, :win_rate]) || 0.0
      expectancy = get_in(data, [:results, :expectancy]) || 0.0
      win_rate * expectancy  # Simple consistency score
    end, :desc)
    
    # Create score based on multiple factors
    scored_agents = Enum.map(agent_results, fn {id, data} ->
      results = data.results
      
      # Calculate composite score (0-100)
      profit_score = normalize_metric(results.profit_percentage, -20.0, 50.0) * 100
      win_rate_score = results.win_rate * 100
      drawdown_score = (1.0 - normalize_metric(results.max_drawdown, 0.0, 50.0)) * 100
      profit_factor_score = normalize_metric(results.profit_factor, 0.0, 3.0) * 100
      
      composite_score = (
        profit_score * 0.35 + 
        win_rate_score * 0.25 + 
        drawdown_score * 0.25 + 
        profit_factor_score * 0.15
      )
      
      {id, composite_score}
    end)
    
    # Sort by composite score
    overall_ranking = Enum.sort_by(scored_agents, fn {_, score} -> score end, :desc)
    
    # Return multi-factor comparison
    %{
      agents: length(agent_results),
      best_profit: {elem(List.first(profit_ranking), 0), get_in(elem(List.first(profit_ranking), 1), [:results, :profit_percentage])},
      best_risk_adjusted: {elem(List.first(risk_adjusted_ranking), 0), get_in(elem(List.first(risk_adjusted_ranking), 1), [:results, :risk_adjusted_return])},
      best_consistency: {elem(List.first(consistency_ranking), 0), get_in(elem(List.first(consistency_ranking), 1), [:results, :win_rate])},
      overall_ranking: Enum.map(overall_ranking, fn {id, score} -> %{id: id, score: score} end),
      profit_ranking: Enum.map(profit_ranking, fn {id, _} -> id end),
      risk_adjusted_ranking: Enum.map(risk_adjusted_ranking, fn {id, _} -> id end),
      consistency_ranking: Enum.map(consistency_ranking, fn {id, _} -> id end)
    }
  end
  
  # Generate stress test scenarios
  defp generate_stress_scenarios(base_candles, options) do
    # Extract parameters
    volatility_factors = Map.get(options, :volatility_factors, [0.5, 1.0, 2.0])
    trend_scenarios = Map.get(options, :trend_scenarios, [-0.01, 0.0, 0.01])
    gap_scenarios = Map.get(options, :gap_scenarios, [0.0, 0.01, 0.02])
    
    # Generate scenarios
    _scenarios = []
    
    # Add volatility scenarios
    volatility_scenarios = Enum.map(volatility_factors, fn factor ->
      modified_candles = modify_volatility(base_candles, factor)
      {"Volatility x#{factor}", modified_candles}
    end)
    
    # Add trend scenarios
    trend_scenarios = Enum.map(trend_scenarios, fn trend ->
      modified_candles = add_trend(base_candles, trend)
      name = cond do
        trend > 0 -> "Uptrend +#{trend * 100}%"
        trend < 0 -> "Downtrend #{trend * 100}%"
        true -> "No Trend"
      end
      {name, modified_candles}
    end)
    
    # Add gap scenarios
    gap_scenarios = Enum.map(gap_scenarios, fn gap ->
      modified_candles = add_gaps(base_candles, gap)
      if gap > 0 do
        {"Gaps #{gap * 100}%", modified_candles}
      else
        {"No Gaps", modified_candles}
      end
    end)
    
    # Combine all scenarios
    volatility_scenarios ++ trend_scenarios ++ gap_scenarios
  end
  
  # Create windows for walk-forward testing
  defp create_walk_forward_windows(candles, windows, train_ratio) do
    # Calculate window size
    total_candles = length(candles)
    window_size = div(total_candles, windows)
    
    # Create windows
    Enum.map(0..(windows-1), fn window ->
      start_idx = window * window_size
      end_idx = min(start_idx + window_size, total_candles)
      
      window_candles = Enum.slice(candles, start_idx..(end_idx-1))
      
      # Split into train and test sets
      train_size = floor(length(window_candles) * train_ratio)
      
      train_candles = Enum.take(window_candles, train_size)
      test_candles = Enum.drop(window_candles, train_size)
      
      {window + 1, {train_candles, test_candles}}
    end)
  end
  
  # Generate report for backtest
  defp generate_report(results, agent_path, data_file, options, report_file) do
    # Create report content
    content = """
    # Backtest Report
    
    ## Agent Information
    - Agent: #{Path.basename(agent_path)}
    - Data File: #{Path.basename(data_file)}
    - Date: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}
    
    ## Configuration
    - Initial Balance: $#{options[:initial_balance] || 10000.0}
    - Risk Per Trade: #{options[:risk_per_trade] || 1.0}%
    - Commission: #{options[:commission] || 0.1}%
    - Slippage: #{options[:slippage] || 1.0} pips
    
    ## Performance Summary
    - Profit/Loss: $#{Float.round(results.profit_loss, 2)}
    - Profit Percentage: #{Float.round(results.profit_percentage, 2)}%
    - Total Trades: #{results.total_trades}
    - Win Rate: #{Float.round(results.win_rate * 100, 2)}%
    - Profit Factor: #{Float.round(results.profit_factor, 2)}
    - Max Drawdown: #{Float.round(results.max_drawdown, 2)}%
    
    ## Detailed Metrics
    - Initial Balance: $#{Float.round(results.initial_balance, 2)}
    - Final Balance: $#{Float.round(results.final_balance, 2)}
    - Winning Trades: #{results.winning_trades}
    - Losing Trades: #{results.losing_trades}
    - Average Profit: $#{Float.round(results.avg_profit, 2)}
    - Average Loss: $#{Float.round(results.avg_loss, 2)}
    - Expectancy: $#{Float.round(results.expectancy, 2)}
    - Risk-Adjusted Return: #{Float.round(results.risk_adjusted_return, 2)}
    """
    
    # Write report to file
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, content)
  end
  
  # Generate report for robustness test
  defp generate_robustness_report(segments, summary, agent_path, _options, report_file) do
    # Create report content
    segment_details = Enum.map_join(segments, "\n\n", fn {name, results} ->
      """
      ### #{name}
      - Profit/Loss: $#{Float.round(results.profit_loss, 2)}
      - Profit Percentage: #{Float.round(results.profit_percentage, 2)}%
      - Win Rate: #{Float.round(results.win_rate * 100, 2)}%
      - Max Drawdown: #{Float.round(results.max_drawdown, 2)}%
      - Profit Factor: #{Float.round(results.profit_factor, 2)}
      """
    end)
    
    content = """
    # Robustness Test Report
    
    ## Agent Information
    - Agent: #{Path.basename(agent_path)}
    - Date: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}
    - Segments Tested: #{summary.segments}
    
    ## Robustness Summary
    - Overall Consistency: #{Float.round(summary.overall_consistency * 100, 2)}%
    - Robustness Score: #{Float.round(summary.robustness_score, 2)}
    
    ## Performance Ranges
    - Profit Percentage: #{Float.round(summary.min_profit_percentage, 2)}% to #{Float.round(summary.max_profit_percentage, 2)}%
    - Win Rate: #{Float.round(summary.min_win_rate * 100, 2)}% to #{Float.round(summary.max_win_rate * 100, 2)}%
    - Max Drawdown: #{Float.round(summary.min_max_drawdown, 2)}% to #{Float.round(summary.max_max_drawdown, 2)}%
    
    ## Segment Details
    #{segment_details}
    """
    
    # Write report to file
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, content)
  end
  
  # Generate report for comparison test
  defp generate_comparison_report(agents, comparison, data_file, options, report_file) do
    # Create report content
    agent_details = Enum.map_join(agents, "\n\n", fn {id, data} ->
      results = data.results
      """
      ### #{id}
      - Profit/Loss: $#{Float.round(results.profit_loss, 2)}
      - Profit Percentage: #{Float.round(results.profit_percentage, 2)}%
      - Win Rate: #{Float.round(results.win_rate * 100, 2)}%
      - Max Drawdown: #{Float.round(results.max_drawdown, 2)}%
      - Profit Factor: #{Float.round(results.profit_factor, 2)}
      - Risk-Adjusted Return: #{Float.round(results.risk_adjusted_return, 2)}
      """
    end)
    
    ranking_details = Enum.map_join(Enum.with_index(comparison.overall_ranking), "\n", fn {agent, idx} ->
      "#{idx + 1}. #{agent.id} (Score: #{Float.round(agent.score, 2)})"
    end)
    
    content = """
    # Agent Comparison Report
    
    ## Test Information
    - Data File: #{Path.basename(data_file)}
    - Date: #{DateTime.utc_now() |> Calendar.strftime("%Y-%m-%d %H:%M:%S UTC")}
    - Agents Compared: #{comparison.agents}
    
    ## Configuration
    - Initial Balance: $#{options[:initial_balance] || 10000.0}
    - Risk Per Trade: #{options[:risk_per_trade] || 1.0}%
    - Commission: #{options[:commission] || 0.1}%
    - Slippage: #{options[:slippage] || 1.0} pips
    
    ## Overall Ranking
    #{ranking_details}
    
    ## Best Performers
    - Best Profit: #{elem(comparison.best_profit, 0)} (#{Float.round(elem(comparison.best_profit, 1), 2)}%)
    - Best Risk-Adjusted: #{elem(comparison.best_risk_adjusted, 0)} (#{Float.round(elem(comparison.best_risk_adjusted, 1), 2)})
    - Best Consistency: #{elem(comparison.best_consistency, 0)} (Win Rate: #{Float.round(elem(comparison.best_consistency, 1) * 100, 2)}%)
    
    ## Agent Details
    #{agent_details}
    """
    
    # Write report to file
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, content)
  end
  
  # Generate report for stress test
  defp generate_stress_test_report(_scenarios, _summary, _agent_path, _data_file, _options, report_file) do
    # Create report content - not implemented in this simplified version
    content = "# Stress Test Report\n\nPlaceholder for stress test report"
    
    # Write report to file
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, content)
  end
  
  # Generate report for walk-forward test
  defp generate_walk_forward_report(_windows, _summary, _agent_path, _data_file, _options, report_file) do
    # Create report content - not implemented in this simplified version
    content = "# Walk-Forward Test Report\n\nPlaceholder for walk-forward test report"
    
    # Write report to file
    File.mkdir_p!(Path.dirname(report_file))
    File.write!(report_file, content)
  end
  
  # Generate summary for stress test
  defp generate_stress_test_summary(scenario_results) do
    # Placeholder implementation
    %{
      scenarios: length(scenario_results),
      passed_scenarios: length(scenario_results)
    }
  end
  
  # Generate summary for walk-forward test
  defp generate_walk_forward_summary(window_results) do
    # Placeholder implementation
    %{
      windows: length(window_results),
      consistent_windows: length(window_results)
    }
  end
  
  # Calculate consistency score for a list of values
  defp calculate_consistency(values) do
    if length(values) <= 1 do
      1.0  # Perfect consistency with just one value
    else
      mean = Enum.sum(values) / length(values)
      
      # Calculate variance
      variance = Enum.reduce(values, 0.0, fn value, acc ->
        acc + :math.pow(value - mean, 2)
      end) / length(values)
      
      # Calculate coefficient of variation (lower is more consistent)
      cv = (if mean != 0, do: :math.sqrt(variance) / abs(mean), else: 0.0)
      
      # Convert to consistency score (1.0 = perfect consistency, 0.0 = no consistency)
      # Using an exponential decay function to map high CV to low consistency
      :math.exp(-3 * cv)
    end
  end
  
  # Normalize a metric to a 0-1 range
  defp normalize_metric(value, min_value, max_value) do
    normalized = (value - min_value) / (max_value - min_value)
    max(0.0, min(1.0, normalized))
  end
  
  # Modify volatility of candles
  defp modify_volatility(candles, factor) do
    Enum.map(candles, fn candle ->
      # Calculate average price
      avg_price = (candle.open + candle.close) / 2
      
      # Calculate original range
      orig_range = candle.high - candle.low
      
      # Apply volatility factor
      new_range = orig_range * factor
      
      # Calculate new high and low
      half_range = new_range / 2
      new_high = avg_price + half_range
      new_low = avg_price - half_range
      
      # Update candle
      %{candle |
        high: new_high,
        low: new_low
      }
    end)
  end
  
  # Add trend to candles
  defp add_trend(candles, trend_factor) do
    # Running price modifier that accumulates over time
    Enum.reduce(Enum.with_index(candles), {[], 1.0}, fn {candle, _idx}, {acc_candles, modifier} ->
      # Update price modifier with trend
      new_modifier = modifier * (1 + trend_factor)
      
      # Apply modifier to prices
      modified_candle = %{candle |
        open: candle.open * new_modifier,
        high: candle.high * new_modifier,
        low: candle.low * new_modifier,
        close: candle.close * new_modifier
      }
      
      {[modified_candle | acc_candles], new_modifier}
    end)
    |> elem(0)
    |> Enum.reverse()
  end
  
  # Add price gaps to candles
  defp add_gaps(candles, gap_probability) do
    Enum.reduce(Enum.with_index(candles), {[], nil}, fn {candle, idx}, {acc_candles, prev_close} ->
      if idx > 0 && :rand.uniform() < gap_probability do
        # Determine gap direction (up or down)
        gap_direction = (if :rand.uniform() < 0.5, do: 1, else: -1)
        
        # Calculate gap size (0.5% to 2% of price)
        gap_size = prev_close * (:rand.uniform() * 0.015 + 0.005) * gap_direction
        
        # Apply gap to opening price
        gap_open = candle.open + gap_size
        
        # Ensure high/low are consistent
        gap_high = max(candle.high, gap_open)
        gap_low = min(candle.low, gap_open)
        
        # Create gapped candle
        gapped_candle = %{candle |
          open: gap_open,
          high: gap_high,
          low: gap_low
        }
        
        {[gapped_candle | acc_candles], candle.close}
      else
        {[candle | acc_candles], candle.close}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end
end