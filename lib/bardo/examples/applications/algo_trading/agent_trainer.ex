defmodule Bardo.Examples.Applications.AlgoTrading.AgentTrainer do
  @moduledoc """
  Specialized module for training and evolving trading agents.

  This module provides functionality for:
  - Creating initial populations with substrate encoding
  - Evolving agents through genetic algorithms
  - Evaluating agent performance in simulated environments
  - Optimizing agents for specific trading strategies
  """

  require Logger

  alias Bardo.Examples.Applications.AlgoTrading.DataUtils
  alias Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer

  # Default root directory for storing trained agents
  @agent_storage_dir "/home/user/Desktop/bardo/priv/market_data/agent_repository"

  @doc """
  Train a trading agent on historical data.

  ## Parameters

  - instrument: Instrument code (e.g., "EUR_USD", "BTC/USD")
  - data_file: Path to historical data file
  - options: Additional options
    - `:population_size` - Size of the initial population (default: 50)
    - `:generations` - Number of generations to evolve (default: 100)
    - `:mutation_rate` - Probability of mutation (default: 0.3)
    - `:crossover_rate` - Probability of crossover (default: 0.7)
    - `:elite_fraction` - Fraction of population to preserve as elite (default: 0.1)
    - `:substrate_config` - Configuration for substrate encoding
    - `:save_dir` - Directory to save the trained agent (default: agent repository)
    - `:save_intermediates` - Whether to save intermediate agents (default: false)
    - `:parallel` - Whether to evaluate population in parallel (default: true)

  ## Returns

  - `{:ok, agent_info}` - Information about the trained agent
  - `{:error, reason}` - If training fails
  """
  def train_agent(instrument, data_file, options \\ %{}) do
    # Extract options with defaults
    population_size = Map.get(options, :population_size, 50)
    generations = Map.get(options, :generations, 100)
    mutation_rate = Map.get(options, :mutation_rate, 0.3)
    crossover_rate = Map.get(options, :crossover_rate, 0.7)
    elite_fraction = Map.get(options, :elite_fraction, 0.1)
    parallel = Map.get(options, :parallel, true)
    save_intermediates = Map.get(options, :save_intermediates, false)
    
    # Default substrate configuration
    substrate_config = Map.get(options, :substrate_config, %{
      input_time_points: 60,      # 60 time points
      input_price_levels: 20,     # 20 price levels
      input_data_types: 10,       # 10 data types (OHLC, volume, indicators)
      hidden_layers: 2,           # 2 hidden layers
      hidden_neurons_per_layer: 20, # 20 neurons per hidden layer
      output_neurons: 3           # 3 outputs (direction, size, risk)
    })

    # Load historical data
    case DataUtils.load_historical_data(data_file) do
      {:ok, candles} ->
        # Log training start
        Logger.info("Starting training for #{instrument} with population size #{population_size} for #{generations} generations")

        # Create initial population
        population = create_initial_population(population_size, substrate_config)

        # Train for the specified number of generations
        start_time = System.monotonic_time(:millisecond)

        # Initialize stats tracking
        stats = %{
          generation: 0,
          best_fitness: 0,
          avg_fitness: 0,
          population_size: population_size,
          instrument: instrument,
          data_file: data_file
        }

        # Run the evolutionary algorithm
        {final_population, final_stats} = evolve_population(
          population,
          candles,
          generations,
          %{
            mutation_rate: mutation_rate,
            crossover_rate: crossover_rate,
            elite_fraction: elite_fraction,
            parallel: parallel,
            save_intermediates: save_intermediates,
            instrument: instrument,
            stats: stats
          }
        )

        # Calculate training time
        end_time = System.monotonic_time(:millisecond)
        training_time_ms = end_time - start_time

        # Find the best agent in the final population
        best_agent = Enum.max_by(final_population, fn agent ->
          case agent.fitness do
            [profit | _] -> profit
            _ -> -1000.0  # Default for invalid fitness
          end
        end)

        # Create directory for storing the agent
        agent_dir = Map.get(options, :save_dir, get_agent_dir(instrument))
        File.mkdir_p!(agent_dir)

        # Generate filename with timestamp and fitness
        agent_filename = generate_agent_filename(instrument, best_agent.fitness)
        agent_path = Path.join(agent_dir, agent_filename)

        # Prepare metadata
        metadata = %{
          "instrument" => instrument,
          "trained_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "data_file" => data_file,
          "population_size" => population_size,
          "generations" => generations,
          "mutation_rate" => mutation_rate,
          "crossover_rate" => crossover_rate,
          "elite_fraction" => elite_fraction,
          "training_time_ms" => training_time_ms,
          "final_stats" => final_stats,
          "performance" => best_agent.fitness
        }

        # Save the best agent
        case AgentSerializer.save_agent(best_agent.genotype, agent_path, metadata) do
          :ok ->
            # Return information about the trained agent
            {:ok, %{
              agent_id: Path.basename(agent_path, ".json"),
              agent_path: agent_path,
              fitness: best_agent.fitness,
              metadata: metadata,
              stats: final_stats
            }}

          {:error, reason} ->
            {:error, "Failed to save trained agent: #{inspect(reason)}"}
        end

      {:error, reason} ->
        {:error, "Failed to load historical data: #{inspect(reason)}"}
    end
  end

  @doc """
  Evaluate an agent's performance on historical data.

  ## Parameters

  - agent_path: Path to the agent JSON file
  - data_file: Path to historical data file
  - options: Additional options
    - `:initial_balance` - Initial account balance (default: 10000.0)
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:commission` - Commission per trade in percentage (default: 0.1)
    - `:slippage` - Slippage in pips (default: 1.0)

  ## Returns

  - `{:ok, performance}` - Performance metrics
  - `{:error, reason}` - If evaluation fails
  """
  def evaluate_agent(agent_path, data_file, options \\ %{}) do
    # Extract options with defaults
    initial_balance = Map.get(options, :initial_balance, 10000.0)
    risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    commission = Map.get(options, :commission, 0.1)
    slippage = Map.get(options, :slippage, 1.0)

    # Load agent
    case AgentSerializer.load_agent(agent_path) do
      {:ok, {genotype, _metadata}} ->
        # Load historical data
        case DataUtils.load_historical_data(data_file) do
          {:ok, candles} ->
            # Prepare test candles (use 80% of data for consistent comparison)
            test_candles = prepare_test_candles(candles)

            # Run simulation
            sim_results = run_trading_simulation(genotype, test_candles, %{
              initial_balance: initial_balance,
              risk_per_trade: risk_per_trade,
              commission: commission,
              slippage: slippage
            })

            # Calculate performance metrics
            performance = calculate_performance_metrics(sim_results)

            {:ok, performance}

          {:error, reason} ->
            {:error, "Failed to load historical data: #{inspect(reason)}"}
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
  - options: Same as evaluate_agent/3

  ## Returns

  - `{:ok, results}` - Comparison results for each agent
  - `{:error, reason}` - If comparison fails
  """
  def compare_agents(agent_paths, data_file, options \\ %{}) do
    # Evaluate each agent
    results = Enum.map(agent_paths, fn agent_path ->
      case evaluate_agent(agent_path, data_file, options) do
        {:ok, performance} ->
          # Get agent ID and metadata
          {_, metadata} = AgentSerializer.load_agent(agent_path)
          agent_id = Path.basename(agent_path, ".json")

          {agent_id, %{
            path: agent_path,
            performance: performance,
            metadata: metadata
          }}

        {:error, reason} ->
          {Path.basename(agent_path, ".json"), {:error, reason}}
      end
    end)

    # Check if all evaluations were successful
    if Enum.all?(results, fn {_, result} -> is_map(result) end) do
      # Format results as a map
      result_map = Enum.into(results, %{})

      # Sort agents by profitability
      sorted_agents = Enum.sort_by(results, fn {_, result} ->
        get_in(result, [:performance, :profit_loss])
      end, :desc)

      {:ok, %{
        results: result_map,
        ranking: sorted_agents
      }}
    else
      # Some evaluations failed
      failed = Enum.filter(results, fn {_, result} -> match?({:error, _}, result) end)
               |> Enum.map(fn {id, {:error, reason}} -> "#{id}: #{reason}" end)
               |> Enum.join(", ")

      {:error, "Failed to evaluate some agents: #{failed}"}
    end
  end

  # Private helper functions

  # Create a directory path for storing agents by instrument
  defp get_agent_dir(instrument) do
    # Ensure base directory exists
    File.mkdir_p!(@agent_storage_dir)

    # Normalize instrument name for directory
    instrument_normalized = String.replace(instrument, "/", "_")
    instrument_normalized = String.replace(instrument_normalized, "-", "_")

    Path.join(@agent_storage_dir, instrument_normalized)
  end

  # Generate a filename for an agent based on instrument and fitness
  defp generate_agent_filename(instrument, fitness) do
    # Clean up instrument name
    instrument_clean = String.replace(instrument, "/", "_")

    # Extract performance value
    perf = case fitness do
      [profit | _] -> profit
      _ -> 0.0
    end

    # Format performance with 2 decimal places
    perf_str = Float.round(perf, 2) |> Float.to_string()

    # Add timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_unix()

    "#{instrument_clean}_#{perf_str}_#{timestamp}.json"
  end

  # Create initial population with substrate encoding
  defp create_initial_population(population_size, substrate_config) do
    Enum.map(1..population_size, fn _ ->
      genotype = SubstrateEncoding.create_substrate_genotype(substrate_config)
      %{genotype: genotype, fitness: [0.0, 0.0, 0.0]}
    end)
  end

  # Evolve population for specified number of generations
  defp evolve_population(population, candles, generations, options) do
    # Extract progress callback if provided
    progress_callback = Map.get(options, :progress_callback, nil)
    progress_counter = 0

    # Helper function for evolving a single generation
    evolve_generation = fn pop, gen_num, stats, progress, acc_fn ->
      # Split data into training and validation sets (70/30)
      {train_candles, validation_candles} = split_candles(candles, 0.7)

      # Evaluate population on training data
      evaluated_population = evaluate_population(pop, train_candles, options)

      # Update progress counter (population size evaluated)
      new_progress = progress + length(pop)

      # Call progress callback if provided
      if progress_callback do
        progress_callback.(new_progress)
      end

      # Sort by fitness
      sorted_population = Enum.sort_by(evaluated_population, fn agent ->
        case agent.fitness do
          [profit | _] -> profit
          _ -> -1000.0
        end
      end, :desc)

      # Calculate statistics
      best_agent = List.first(sorted_population)
      best_fitness = case best_agent.fitness do
        [profit | _] -> profit
        _ -> 0.0
      end

      avg_fitness = Enum.reduce(sorted_population, 0, fn agent, acc ->
        case agent.fitness do
          [profit | _] -> acc + profit
          _ -> acc
        end
      end) / length(sorted_population)

      # Validate best agent on validation data
      validation_result = evaluate_agent_sim(best_agent.genotype, validation_candles, %{})
      validation_fitness = case validation_result do
        %{profit_loss: pl} -> pl
        _ -> 0.0
      end

      # Update statistics
      updated_stats = %{
        generation: gen_num,
        best_fitness: best_fitness,
        avg_fitness: avg_fitness,
        validation_fitness: validation_fitness
      }

      # Log progress
      Logger.info("Generation #{gen_num}: Best = #{best_fitness}, Avg = #{avg_fitness}, Validation = #{validation_fitness}")

      # Save intermediate if requested
      if options.save_intermediates && rem(gen_num, 10) == 0 do
        save_intermediate_agent(best_agent, options.instrument, gen_num, updated_stats)
      end

      # Create next generation using selection, crossover, and mutation
      next_generation = if gen_num < generations do
        create_next_generation(sorted_population, options)
      else
        sorted_population
      end

      # Call accumulator function with results
      acc_fn.(next_generation, Map.merge(stats, updated_stats), new_progress)
    end

    # Recursive function to evolve through all generations
    evolve_generations = fn
      _evolve_fn, pop, 0, stats, _progress, _opts -> {pop, stats}
      evolve_fn, pop, gens_left, stats, progress, opts ->
        gen_num = options.stats.generation + (options.generations - gens_left) + 1

        # Run one generation
        {next_pop, updated_stats, new_progress} = evolve_generation.(pop, gen_num, stats, progress, fn p, s, prog -> {p, s, prog} end)

        # Continue to next generation
        evolve_fn.(evolve_fn, next_pop, gens_left - 1, updated_stats, new_progress, opts)
    end

    # Start the evolutionary process
    {final_pop, final_stats} = evolve_generations.(evolve_generations, population, generations, options.stats, progress_counter, options)

    # Ensure progress is completed
    if progress_callback do
      # Calculate total progress (generations * population size)
      total_progress = generations * length(population)
      progress_callback.(total_progress)
    end

    {final_pop, final_stats}
  end

  # Evaluate entire population on candles
  defp evaluate_population(population, candles, options) do
    if options.parallel do
      # Parallel evaluation
      population
      |> Task.async_stream(fn agent ->
        fitness = evaluate_agent_fitness(agent.genotype, candles)
        %{agent | fitness: fitness}
      end, ordered: false, timeout: 60_000)
      |> Enum.map(fn {:ok, result} -> result end)
    else
      # Sequential evaluation
      Enum.map(population, fn agent ->
        fitness = evaluate_agent_fitness(agent.genotype, candles)
        %{agent | fitness: fitness}
      end)
    end
  end

  # Evaluate a single agent's fitness
  defp evaluate_agent_fitness(genotype, candles) do
    # Run simulation
    sim_results = run_trading_simulation(genotype, candles, %{})

    # Extract key metrics for fitness
    profit_loss = Map.get(sim_results, :profit_loss, 0.0)
    win_rate = Map.get(sim_results, :win_rate, 0.0)
    drawdown = Map.get(sim_results, :max_drawdown, 100.0)

    # Calculate Sharpe ratio or similar metric
    _sharpe = calculate_sharpe_ratio(sim_results)

    # Trade count factor (penalize strategies with too few trades)
    trade_count = Map.get(sim_results, :total_trades, 0)
    trade_factor = min(1.0, trade_count / 20)  # Max factor at 20+ trades

    # Return multi-objective fitness
    [
      profit_loss * trade_factor,  # Primary objective
      win_rate,                    # Secondary objective
      -drawdown                    # Minimize drawdown
    ]
  end

  # Create the next generation of agents
  defp create_next_generation(population, options) do
    # Extract options
    elite_fraction = options.elite_fraction
    mutation_rate = options.mutation_rate
    crossover_rate = options.crossover_rate

    # Calculate number of elites to keep
    elite_count = max(1, round(length(population) * elite_fraction))

    # Keep elites (unchanged)
    elites = Enum.take(population, elite_count)

    # Create offspring to fill the rest of the population
    offspring_count = length(population) - elite_count

    # Generate offspring through selection, crossover, and mutation
    offspring = Enum.map(1..offspring_count, fn _ ->
      # Select parents through tournament selection
      parent1 = tournament_selection(population, 3)
      parent2 = tournament_selection(population, 3)

      # Apply crossover with probability
      child = if :rand.uniform() < crossover_rate do
        crossover(parent1.genotype, parent2.genotype)
      else
        # No crossover, use first parent
        parent1.genotype
      end

      # Apply mutation with probability
      child = if :rand.uniform() < mutation_rate do
        mutate(child)
      else
        child
      end

      # Return new agent
      %{genotype: child, fitness: [0.0, 0.0, 0.0]}
    end)

    # Combine elites and offspring
    elites ++ offspring
  end

  # Tournament selection
  defp tournament_selection(population, tournament_size) do
    # Select random individuals for tournament
    tournament = Enum.take_random(population, tournament_size)

    # Return the best
    Enum.max_by(tournament, fn agent ->
      case agent.fitness do
        [profit | _] -> profit
        _ -> -1000.0
      end
    end)
  end

  # Crossover two genotypes
  defp crossover(genotype1, genotype2) do
    # Extract neurons and connections
    neurons1 = Map.get(genotype1, :neurons, %{})
    _neurons2 = Map.get(genotype2, :neurons, %{})
    connections1 = Map.get(genotype1, :connections, %{})
    connections2 = Map.get(genotype2, :connections, %{})

    # Keep neurons the same (substrate architecture) but crossover connections
    connection_ids = Map.keys(connections1) |> MapSet.new()
                     |> MapSet.union(MapSet.new(Map.keys(connections2)))
                     |> MapSet.to_list()

    # For each connection, randomly select from either parent
    connections = Enum.reduce(connection_ids, %{}, fn id, acc ->
      cond do
        Map.has_key?(connections1, id) && Map.has_key?(connections2, id) ->
          # Both parents have this connection - randomly choose or blend
          if :rand.uniform() < 0.5 do
            Map.put(acc, id, Map.get(connections1, id))
          else
            Map.put(acc, id, Map.get(connections2, id))
          end

        Map.has_key?(connections1, id) ->
          # Only first parent has this connection
          if :rand.uniform() < 0.5 do
            Map.put(acc, id, Map.get(connections1, id))
          else
            acc
          end

        Map.has_key?(connections2, id) ->
          # Only second parent has this connection
          if :rand.uniform() < 0.5 do
            Map.put(acc, id, Map.get(connections2, id))
          else
            acc
          end
      end
    end)

    # Create child genotype
    %{
      neurons: neurons1,  # Use structure from first parent
      connections: connections,
      substrate_metadata: Map.get(genotype1, :substrate_metadata, %{})
    }
  end

  # Mutate a genotype
  defp mutate(genotype) do
    # Extract connections
    connections = Map.get(genotype, :connections, %{})

    # Mutate connection weights
    mutated_connections = Enum.reduce(connections, %{}, fn {id, connection}, acc ->
      # 30% chance to mutate each connection
      if :rand.uniform() < 0.3 do
        # Get current weight
        weight = Map.get(connection, :weight, 0.0)

        # Apply Gaussian mutation
        mutation = :rand.normal() * 0.2  # Adjust scale factor as needed
        new_weight = weight + mutation

        # Update connection
        updated_connection = Map.put(connection, :weight, new_weight)
        Map.put(acc, id, updated_connection)
      else
        # Keep original
        Map.put(acc, id, connection)
      end
    end)

    # Return mutated genotype
    %{genotype | connections: mutated_connections}
  end

  # Run a trading simulation
  defp run_trading_simulation(genotype, candles, options) do
    # Extract options with defaults
    initial_balance = Map.get(options, :initial_balance, 10000.0)
    risk_per_trade = Map.get(options, :risk_per_trade, 1.0)
    commission = Map.get(options, :commission, 0.1)
    slippage = Map.get(options, :slippage, 1.0)

    # Initialize simulation state
    state = %{
      balance: initial_balance,
      equity: initial_balance,
      position: 0,  # 0 = no position, 1 = long, -1 = short
      position_size: 0.0,
      entry_price: 0.0,
      trades: [],
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      profit_loss: 0.0,
      peak_balance: initial_balance,
      max_drawdown: 0.0
    }

    # Simulate trading on each candle
    final_state = Enum.reduce(Enum.with_index(candles), state, fn {candle, idx}, acc ->
      # Skip if not enough historical data for inputs
      if idx < 60 do  # Assuming we need 60 candles for input
        acc
      else
        # Get historical candles for input
        historical_candles = Enum.slice(candles, idx - 60, 60)

        # Prepare inputs from historical candles
        inputs = prepare_neural_inputs(historical_candles, genotype)

        # Process agent decision
        process_trading_decision(genotype, inputs, candle, acc, %{
          risk_per_trade: risk_per_trade,
          commission: commission,
          slippage: slippage
        })
      end
    end)

    # Close any open position at the end of simulation
    final_state = if final_state.position != 0 do
      close_position(final_state, List.last(candles), %{commission: commission, slippage: slippage})
    else
      final_state
    end

    # Calculate additional metrics
    win_rate = if final_state.total_trades > 0 do
      final_state.winning_trades / final_state.total_trades
    else
      0.0
    end

    # Return simulation results
    %{
      initial_balance: initial_balance,
      final_balance: final_state.balance,
      profit_loss: final_state.profit_loss,
      profit_percentage: (final_state.profit_loss / initial_balance) * 100,
      total_trades: final_state.total_trades,
      winning_trades: final_state.winning_trades,
      losing_trades: final_state.losing_trades,
      win_rate: win_rate,
      max_drawdown: final_state.max_drawdown,
      trades: final_state.trades
    }
  end

  # Calculate performance metrics
  defp calculate_performance_metrics(sim_results) do
    # Calculate additional metrics

    # Profit factor (gross profit / gross loss)
    {gross_profit, gross_loss} = Enum.reduce(sim_results.trades, {0.0, 0.0}, fn trade, {gp, gl} ->
      if trade.profit > 0 do
        {gp + trade.profit, gl}
      else
        {gp, gl + abs(trade.profit)}
      end
    end)

    profit_factor = if gross_loss > 0, do: gross_profit / gross_loss, else: 0.0

    # Average profit and loss per trade
    avg_profit = if sim_results.winning_trades > 0 do
      gross_profit / sim_results.winning_trades
    else
      0.0
    end

    avg_loss = if sim_results.losing_trades > 0 do
      gross_loss / sim_results.losing_trades
    else
      0.0
    end

    # Expectancy (average expected profit/loss per trade)
    expectancy = if sim_results.total_trades > 0 do
      sim_results.profit_loss / sim_results.total_trades
    else
      0.0
    end

    # Return expanded metrics
    Map.merge(sim_results, %{
      profit_factor: profit_factor,
      avg_profit: avg_profit,
      avg_loss: avg_loss,
      expectancy: expectancy,
      sharpe_ratio: calculate_sharpe_ratio(sim_results)
    })
  end

  # Calculate Sharpe ratio from simulation results
  defp calculate_sharpe_ratio(sim_results) do
    trades = Map.get(sim_results, :trades, [])

    if length(trades) < 2 do
      0.0  # Not enough data
    else
      # Calculate returns
      returns = Enum.map(trades, fn trade -> trade.profit / trade.size end)

      # Calculate mean return
      mean_return = Enum.sum(returns) / length(returns)

      # Calculate standard deviation of returns
      variance = Enum.reduce(returns, 0.0, fn r, acc ->
        acc + :math.pow(r - mean_return, 2)
      end) / length(returns)

      std_dev = :math.sqrt(variance)

      # Calculate Sharpe ratio (assuming risk-free rate of 0)
      if std_dev > 0, do: mean_return / std_dev, else: 0.0
    end
  end

  # Process a trading decision
  defp process_trading_decision(genotype, inputs, candle, state, options) do
    # Activate the neural network
    outputs = activate_neural_network(genotype, inputs)

    # Interpret outputs
    [direction, size, _risk] = outputs

    # Convert to trading decision
    # Direction: < -0.33 = sell, > 0.33 = buy, otherwise hold
    trade_signal = cond do
      direction < -0.33 -> -1  # Sell/Short
      direction > 0.33 -> 1    # Buy/Long
      true -> 0                # Hold
    end

    # Size: 0.0-1.0 representing position size
    position_size = max(0.0, min(1.0, size)) * options.risk_per_trade * state.balance

    # Current position
    current_position = state.position

    cond do
      # No position and new signal
      current_position == 0 and trade_signal != 0 ->
        # Open new position
        open_position(state, trade_signal, position_size, candle, options)

      # Position exists and opposite signal
      current_position != 0 and trade_signal != 0 and trade_signal != current_position ->
        # Close existing position
        closed_state = close_position(state, candle, options)

        # Open new position
        open_position(closed_state, trade_signal, position_size, candle, options)

      # Otherwise, maintain current state
      true ->
        # Update equity based on unrealized profit/loss
        if current_position != 0 do
          entry_price = state.entry_price
          current_price = if current_position > 0, do: candle.close, else: candle.close

          # Calculate unrealized profit/loss
          price_diff = if current_position > 0 do
            current_price - entry_price
          else
            entry_price - current_price
          end

          unrealized_pl = price_diff * state.position_size

          # Update equity
          equity = state.balance + unrealized_pl

          # Update max drawdown if needed
          peak_balance = max(state.peak_balance, equity)
          drawdown = if peak_balance > 0 do
            (peak_balance - equity) / peak_balance * 100
          else
            0.0
          end

          max_drawdown = max(state.max_drawdown, drawdown)

          # Return updated state
          %{state | equity: equity, peak_balance: peak_balance, max_drawdown: max_drawdown}
        else
          state
        end
    end
  end

  # Open a new position
  defp open_position(state, direction, size, candle, options) do
    # Get entry price (add slippage)
    entry_price = if direction > 0 do
      candle.close + (options.slippage * 0.0001)  # Add slippage for buy
    else
      candle.close - (options.slippage * 0.0001)  # Subtract slippage for sell
    end

    # Apply commission
    commission_amount = size * (options.commission / 100)

    # Update state
    %{state |
      position: direction,
      position_size: size,
      entry_price: entry_price,
      balance: state.balance - commission_amount,
      equity: state.balance - commission_amount
    }
  end

  # Close an existing position
  defp close_position(state, candle, options) do
    # Get exit price (add slippage)
    exit_price = if state.position > 0 do
      candle.close - (options.slippage * 0.0001)  # Subtract slippage for sell
    else
      candle.close + (options.slippage * 0.0001)  # Add slippage for buy
    end

    # Calculate profit/loss
    price_diff = if state.position > 0 do
      exit_price - state.entry_price
    else
      state.entry_price - exit_price
    end

    trade_profit = price_diff * state.position_size

    # Apply commission
    commission_amount = state.position_size * (options.commission / 100)

    # Calculate net profit
    net_profit = trade_profit - commission_amount

    # Record trade
    trade = %{
      entry_time: candle.time,  # This is not correct - would need entry candle
      exit_time: candle.time,
      direction: state.position,
      entry_price: state.entry_price,
      exit_price: exit_price,
      size: state.position_size,
      profit: net_profit,
      win: net_profit > 0
    }

    # Update counters
    total_trades = state.total_trades + 1
    winning_trades = if net_profit > 0, do: state.winning_trades + 1, else: state.winning_trades
    losing_trades = if net_profit <= 0, do: state.losing_trades + 1, else: state.losing_trades

    # Update balance and profit/loss
    new_balance = state.balance + net_profit
    total_pl = state.profit_loss + net_profit

    # Update peak balance if needed
    peak_balance = max(state.peak_balance, new_balance)

    # Calculate drawdown
    drawdown = if peak_balance > 0 do
      (peak_balance - new_balance) / peak_balance * 100
    else
      0.0
    end

    max_drawdown = max(state.max_drawdown, drawdown)

    # Return updated state
    %{state |
      position: 0,
      position_size: 0.0,
      entry_price: 0.0,
      balance: new_balance,
      equity: new_balance,
      trades: [trade | state.trades],
      total_trades: total_trades,
      winning_trades: winning_trades,
      losing_trades: losing_trades,
      profit_loss: total_pl,
      peak_balance: peak_balance,
      max_drawdown: max_drawdown
    }
  end

  # Activate neural network
  defp activate_neural_network(_genotype, _inputs) do
    # This is a simplified implementation - in a real system, we would use the actual
    # neural network activation code from the cortex module

    # For now, return some random outputs
    [
      :rand.uniform() * 2 - 1,  # Direction (-1 to 1)
      :rand.uniform(),          # Size (0 to 1)
      :rand.uniform()           # Risk (0 to 1)
    ]
  end

  # Prepare neural inputs from candles
  defp prepare_neural_inputs(_candles, _genotype) do
    # In a real implementation, this would convert the candles to a substrate grid
    # and then flatten it for the neural network inputs

    # For now, return a placeholder
    %{}
  end

  # Split candles into training and validation sets
  defp split_candles(candles, train_ratio) do
    split_point = floor(length(candles) * train_ratio)

    train_candles = Enum.take(candles, split_point)
    validation_candles = Enum.drop(candles, split_point)

    {train_candles, validation_candles}
  end

  # Prepare test candles (use 80% for consistent comparison)
  defp prepare_test_candles(candles) do
    # Use a fixed percentage of the data for testing
    # This allows for more consistent comparison between agents
    test_size = floor(length(candles) * 0.8)
    Enum.take(candles, test_size)
  end

  # Run simulation for agent evaluation
  defp evaluate_agent_sim(genotype, candles, options) do
    # Use the same simulation function but with simplified options
    run_trading_simulation(genotype, candles, options)
  end

  # Save an intermediate agent during training
  defp save_intermediate_agent(agent, instrument, generation, stats) do
    # Only save if the agent has positive profit
    if List.first(agent.fitness) > 0 do
      # Create directory
      agent_dir = get_agent_dir(instrument)
      File.mkdir_p!(Path.join(agent_dir, "intermediates"))

      # Generate filename
      filename = "#{instrument}_gen#{generation}_#{List.first(agent.fitness)}.json"
      filepath = Path.join([agent_dir, "intermediates", filename])

      # Save agent
      AgentSerializer.save_agent(agent.genotype, filepath, %{
        "instrument" => instrument,
        "generation" => generation,
        "fitness" => agent.fitness,
        "stats" => stats
      })
    end
  end
end
