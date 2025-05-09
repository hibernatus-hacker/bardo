defmodule Bardo.Examples.Applications.AlgoTrading.ContinuousLearning do
  @moduledoc """
  Module for implementing continuous learning in deployed trading agents.
  
  This module provides functionality for:
  - Collecting trading performance data for deployed agents
  - Updating agent networks based on real-world performance
  - Managing agent evolution during live trading
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  alias Bardo.PopulationManager.GenomeMutator
  
  @doc """
  Initialize continuous learning for an agent.
  
  ## Parameters
  
  - genotype: The agent's current genotype
  - opts: Configuration options
    - `:learning_rate` - Rate of adaptation (default: 0.01)
    - `:mutation_probability` - Probability of mutation (default: 0.1)
    - `:max_memory_size` - Maximum memory size for experiences (default: 1000)
    - `:update_frequency` - How often to update the network (default: 10)
  
  ## Returns
  
  - Continuous learning state map
  """
  def init(genotype, opts \\ %{}) do
    # Extract configuration options
    learning_rate = Map.get(opts, :learning_rate, 0.01)
    mutation_probability = Map.get(opts, :mutation_probability, 0.1)
    max_memory_size = Map.get(opts, :max_memory_size, 1000)
    update_frequency = Map.get(opts, :update_frequency, 10)
    
    # Initialize state
    %{
      genotype: genotype,
      original_genotype: genotype,  # Keep original for reference
      learning_rate: learning_rate,
      mutation_probability: mutation_probability,
      max_memory_size: max_memory_size,
      update_frequency: update_frequency,
      experience_memory: [],
      trade_count: 0,
      update_count: 0,
      performance_history: [],
      last_updated: DateTime.utc_now()
    }
  end
  
  @doc """
  Process a completed trade and potentially update the agent.
  
  ## Parameters
  
  - state: Continuous learning state
  - trade: Trade data map with:
    - `:profit_loss` - Profit/loss from the trade
    - `:entry_signals` - Agent's signals at entry
    - `:exit_signals` - Agent's signals at exit
    - `:market_data` - Market data relevant to the trade
  
  ## Returns
  
  - Updated continuous learning state
  """
  def process_trade(state, trade) do
    # Extract trade data
    profit_loss = Map.get(trade, :profit_loss, 0.0)
    
    # Add experience to memory
    experience = %{
      profit_loss: profit_loss,
      entry_signals: Map.get(trade, :entry_signals, []),
      exit_signals: Map.get(trade, :exit_signals, []),
      market_data: Map.get(trade, :market_data, %{}),
      timestamp: DateTime.utc_now()
    }
    
    # Update memory (keep within max size)
    memory = [experience | state.experience_memory]
             |> Enum.take(state.max_memory_size)
    
    # Increment trade count
    trade_count = state.trade_count + 1
    
    # Check if it's time to update the network
    state = %{state | 
      experience_memory: memory,
      trade_count: trade_count
    }
    
    if rem(trade_count, state.update_frequency) == 0 do
      update_agent(state)
    else
      state
    end
  end
  
  @doc """
  Update the agent based on accumulated experience.
  
  ## Parameters
  
  - state: Continuous learning state
  
  ## Returns
  
  - Updated continuous learning state
  """
  def update_agent(state) do
    # Calculate recent performance
    recent_performance = calculate_performance(state.experience_memory)
    
    # Determine if the agent should be updated
    should_update = should_update_agent?(state, recent_performance)
    
    if should_update do
      # Apply adaptive updates to the genotype
      updated_genotype = adapt_genotype(state.genotype, state.experience_memory, state.learning_rate, state.mutation_probability)
      
      # Update state
      %{state | 
        genotype: updated_genotype,
        update_count: state.update_count + 1,
        performance_history: [recent_performance | state.performance_history] |> Enum.take(10),
        last_updated: DateTime.utc_now()
      }
    else
      # Just update performance history
      %{state | 
        performance_history: [recent_performance | state.performance_history] |> Enum.take(10)
      }
    end
  end
  
  @doc """
  Export the current state of continuous learning.
  
  ## Parameters
  
  - state: Continuous learning state
  - file_path: Path to save the exported state (optional)
  
  ## Returns
  
  - `{:ok, exported_data}` - Serialized state data
  - `{:error, reason}` - If export fails
  """
  def export_state(state, file_path \\ nil) do
    # Create export data
    export_data = %{
      genotype: state.genotype,
      original_genotype: state.original_genotype,
      performance_history: state.performance_history,
      trade_count: state.trade_count,
      update_count: state.update_count,
      last_updated: state.last_updated,
      config: %{
        learning_rate: state.learning_rate,
        mutation_probability: state.mutation_probability,
        max_memory_size: state.max_memory_size,
        update_frequency: state.update_frequency
      }
    }
    
    # Serialize
    case AgentSerializer.serialize(state.genotype, export_data) do
      {:ok, json_string} ->
        # Save to file if path provided
        if file_path do
          case File.write(file_path, json_string) do
            :ok -> {:ok, json_string}
            {:error, reason} -> {:error, "Failed to write export file: #{inspect(reason)}"}
          end
        else
          {:ok, json_string}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Import a previously exported continuous learning state.
  
  ## Parameters
  
  - json_string: Serialized state data
  - opts: Configuration options to override
  
  ## Returns
  
  - `{:ok, state}` - Restored continuous learning state
  - `{:error, reason}` - If import fails
  """
  def import_state(json_string, opts \\ %{}) do
    case AgentSerializer.deserialize(json_string) do
      {:ok, {genotype, metadata}} ->
        # Extract saved configuration
        config = Map.get(metadata, "config", %{})
        
        # Create state with saved and potentially overridden options
        learning_rate = Map.get(opts, :learning_rate, Map.get(config, "learning_rate", 0.01))
        mutation_probability = Map.get(opts, :mutation_probability, Map.get(config, "mutation_probability", 0.1))
        max_memory_size = Map.get(opts, :max_memory_size, Map.get(config, "max_memory_size", 1000))
        update_frequency = Map.get(opts, :update_frequency, Map.get(config, "update_frequency", 10))
        
        # Restore other state variables
        original_genotype = Map.get(metadata, "original_genotype", genotype)
        performance_history = Map.get(metadata, "performance_history", [])
        trade_count = Map.get(metadata, "trade_count", 0)
        update_count = Map.get(metadata, "update_count", 0)
        last_updated = Map.get(metadata, "last_updated", DateTime.utc_now() |> DateTime.to_iso8601())
        
        # Construct state
        state = %{
          genotype: genotype,
          original_genotype: original_genotype,
          learning_rate: learning_rate,
          mutation_probability: mutation_probability,
          max_memory_size: max_memory_size,
          update_frequency: update_frequency,
          experience_memory: [],  # Memory is not saved/restored
          trade_count: trade_count,
          update_count: update_count,
          performance_history: performance_history,
          last_updated: last_updated
        }
        
        {:ok, state}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Private helper functions
  
  # Calculate performance metrics from experiences
  defp calculate_performance(experiences) do
    # Skip if no experiences
    if length(experiences) == 0 do
      %{
        profit_loss: 0.0,
        win_rate: 0.0,
        avg_profit: 0.0,
        avg_loss: 0.0,
        profit_factor: 0.0,
        expectancy: 0.0
      }
    else
      # Calculate metrics
      total_pnl = Enum.reduce(experiences, 0.0, fn exp, acc -> acc + exp.profit_loss end)
      winning_trades = Enum.filter(experiences, fn exp -> exp.profit_loss > 0 end)
      losing_trades = Enum.filter(experiences, fn exp -> exp.profit_loss < 0 end)
      
      win_count = length(winning_trades)
      loss_count = length(losing_trades)
      total_count = length(experiences)
      
      # Win rate
      win_rate = if total_count > 0, do: win_count / total_count, else: 0.0
      
      # Average profit and loss
      avg_profit = if win_count > 0 do
        Enum.reduce(winning_trades, 0.0, fn exp, acc -> acc + exp.profit_loss end) / win_count
      else
        0.0
      end
      
      avg_loss = if loss_count > 0 do
        abs(Enum.reduce(losing_trades, 0.0, fn exp, acc -> acc + exp.profit_loss end) / loss_count)
      else
        0.0
      end
      
      # Total profit and loss
      total_profit = Enum.reduce(winning_trades, 0.0, fn exp, acc -> acc + exp.profit_loss end)
      total_loss = abs(Enum.reduce(losing_trades, 0.0, fn exp, acc -> acc + exp.profit_loss end))
      
      # Profit factor
      profit_factor = if total_loss > 0, do: total_profit / total_loss, else: 0.0
      
      # Expectancy
      expectancy = if total_count > 0 do
        (win_rate * avg_profit) - ((1 - win_rate) * avg_loss)
      else
        0.0
      end
      
      %{
        profit_loss: total_pnl,
        win_rate: win_rate,
        avg_profit: avg_profit,
        avg_loss: avg_loss,
        profit_factor: profit_factor,
        expectancy: expectancy
      }
    end
  end
  
  # Determine if the agent should be updated
  defp should_update_agent?(state, recent_performance) do
    # Always update if no previous performance data
    if length(state.performance_history) == 0 do
      true
    else
      # Get previous performance metrics
      previous_performance = List.first(state.performance_history)
      
      # Update if recent performance is better
      recent_performance.expectancy > previous_performance.expectancy
    end
  end
  
  # Adapt the genotype based on trading experience
  defp adapt_genotype(genotype, experiences, learning_rate, mutation_probability) do
    # Filter experiences by outcome for reinforcement learning
    positive_experiences = Enum.filter(experiences, fn exp -> exp.profit_loss > 0 end)
    negative_experiences = Enum.filter(experiences, fn exp -> exp.profit_loss < 0 end)
    
    # Skip adaptation if no meaningful experiences
    if length(positive_experiences) == 0 && length(negative_experiences) == 0 do
      genotype
    else
      # Apply reinforcement learning to adjust weights
      genotype = if length(positive_experiences) > 0 do
        # Strengthen weights that led to positive outcomes
        reinforce_connections(genotype, positive_experiences, learning_rate)
      else
        genotype
      end
      
      genotype = if length(negative_experiences) > 0 do
        # Weaken weights that led to negative outcomes
        adjust_negative_connections(genotype, negative_experiences, learning_rate)
      else
        genotype
      end
      
      # Apply random mutations with probability
      if :rand.uniform() < mutation_probability do
        apply_mutation(genotype)
      else
        genotype
      end
    end
  end
  
  # Reinforce connections that contributed to positive outcomes
  defp reinforce_connections(genotype, positive_experiences, learning_rate) do
    # Extract relevant signals from experiences
    signals = Enum.flat_map(positive_experiences, fn exp -> 
      Map.get(exp, :entry_signals, [])
    end)
    
    # Skip if no signals
    if length(signals) == 0 do
      genotype
    else
      # Find active neurons and connections
      active_neurons = identify_active_neurons(signals)
      
      # Update weights for connections involving active neurons
      connections = Map.get(genotype, :connections, %{})
      
      updated_connections = Enum.reduce(connections, %{}, fn {id, connection}, acc ->
        # Check if connection involves active neurons
        if is_connection_active?(connection, active_neurons) do
          # Strengthen the connection
          updated_connection = Map.put(
            connection, 
            :weight, 
            connection.weight + (connection.weight * learning_rate)
          )
          
          Map.put(acc, id, updated_connection)
        else
          # Keep connection unchanged
          Map.put(acc, id, connection)
        end
      end)
      
      # Update genotype with reinforced connections
      Map.put(genotype, :connections, updated_connections)
    end
  end
  
  # Adjust connections that contributed to negative outcomes
  defp adjust_negative_connections(genotype, negative_experiences, learning_rate) do
    # Extract relevant signals from experiences
    signals = Enum.flat_map(negative_experiences, fn exp -> 
      Map.get(exp, :entry_signals, [])
    end)
    
    # Skip if no signals
    if length(signals) == 0 do
      genotype
    else
      # Find active neurons and connections
      active_neurons = identify_active_neurons(signals)
      
      # Update weights for connections involving active neurons
      connections = Map.get(genotype, :connections, %{})
      
      updated_connections = Enum.reduce(connections, %{}, fn {id, connection}, acc ->
        # Check if connection involves active neurons
        if is_connection_active?(connection, active_neurons) do
          # Weaken the connection
          updated_connection = Map.put(
            connection, 
            :weight, 
            connection.weight - (connection.weight * learning_rate)
          )
          
          Map.put(acc, id, updated_connection)
        else
          # Keep connection unchanged
          Map.put(acc, id, connection)
        end
      end)
      
      # Update genotype with adjusted connections
      Map.put(genotype, :connections, updated_connections)
    end
  end
  
  # Apply random mutation to genotype
  defp apply_mutation(genotype) do
    # Choose a random mutation operator
    mutation_type = Enum.random([
      :mutate_weights,
      :add_connection,
      :remove_connection
    ])
    
    # Apply selected mutation
    case mutation_type do
      :mutate_weights ->
        mutate_weights(genotype)
        
      :add_connection ->
        add_random_connection(genotype)
        
      :remove_connection ->
        remove_random_connection(genotype)
    end
  end
  
  # Mutate connection weights with Gaussian noise
  defp mutate_weights(genotype) do
    connections = Map.get(genotype, :connections, %{})
    
    # Skip if no connections
    if map_size(connections) == 0 do
      genotype
    else
      # Apply Gaussian mutation to weights
      updated_connections = Enum.reduce(connections, %{}, fn {id, connection}, acc ->
        # Add Gaussian noise to weight
        noise = :rand.normal() * 0.1
        updated_weight = connection.weight + noise
        
        # Update connection
        updated_connection = Map.put(connection, :weight, updated_weight)
        Map.put(acc, id, updated_connection)
      end)
      
      # Update genotype
      Map.put(genotype, :connections, updated_connections)
    end
  end
  
  # Add a random connection
  defp add_random_connection(genotype) do
    neurons = Map.get(genotype, :neurons, %{})
    
    # Skip if less than 2 neurons
    if map_size(neurons) < 2 do
      genotype
    else
      # Find valid from/to neurons
      neuron_ids = Map.keys(neurons)
      from_id = Enum.random(neuron_ids)
      to_id = Enum.random(neuron_ids -- [from_id])
      
      # Create new connection ID
      connections = Map.get(genotype, :connections, %{})
      new_conn_id = "conn_#{map_size(connections) + 1}"
      
      # Create new connection with random weight
      new_connection = %{
        from_id: from_id,
        to_id: to_id,
        weight: (:rand.uniform() * 2.0) - 1.0  # Range [-1.0, 1.0]
      }
      
      # Add to genotype
      updated_connections = Map.put(connections, new_conn_id, new_connection)
      Map.put(genotype, :connections, updated_connections)
    end
  end
  
  # Remove a random connection
  defp remove_random_connection(genotype) do
    connections = Map.get(genotype, :connections, %{})
    
    # Skip if no connections
    if map_size(connections) == 0 do
      genotype
    else
      # Choose a random connection to remove
      connection_id = Enum.random(Map.keys(connections))
      
      # Remove from genotype
      updated_connections = Map.delete(connections, connection_id)
      Map.put(genotype, :connections, updated_connections)
    end
  end
  
  # Identify active neurons from signals
  defp identify_active_neurons(signals) do
    # Flatten signals and filter by activation threshold
    Enum.flat_map(signals, fn signal ->
      Enum.with_index(signal)
      |> Enum.filter(fn {value, _idx} -> abs(value) > 0.5 end)
      |> Enum.map(fn {_value, idx} -> "input_#{idx + 1}" end)
    end)
    |> Enum.uniq()
  end
  
  # Check if a connection involves active neurons
  defp is_connection_active?(connection, active_neurons) do
    Enum.member?(active_neurons, connection.from_id) || 
    Enum.member?(active_neurons, connection.to_id)
  end
end