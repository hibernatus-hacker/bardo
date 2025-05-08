defmodule Bardo.Test.Distributed.TestHelper do
  @moduledoc """
  Helper functions for distributed testing of Bardo.
  
  This module provides utility functions specifically for managing
  distributed tests, including test data generation, mock implementations,
  and result verification.
  """
  
  @doc """
  Create a test genotype for distributed testing.
  
  ## Parameters
  
  - config: Configuration for the genotype
    - :input_nodes - Number of input nodes
    - :output_nodes - Number of output nodes
    - :hidden_layers - Number of hidden layers
    - :nodes_per_layer - Nodes per hidden layer
  
  ## Returns
  
  A test genotype that can be used in distributed tests
  """
  def create_test_genotype(config \\ []) do
    input_nodes = Keyword.get(config, :input_nodes, 10)
    output_nodes = Keyword.get(config, :output_nodes, 2)
    hidden_layers = Keyword.get(config, :hidden_layers, 1)
    nodes_per_layer = Keyword.get(config, :nodes_per_layer, 5)
    
    # Create basic inputs
    input_ids = for i <- 1..input_nodes, do: "i#{i}"
    output_ids = for i <- 1..output_nodes, do: "o#{i}"
    
    # Create hidden layer nodes
    hidden_ids = for l <- 1..hidden_layers, n <- 1..nodes_per_layer, do: "h#{l}_#{n}"
    
    # Create neurons
    neurons = 
      # Input neurons
      (for id <- input_ids, do: %{
        id: id,
        layer: 0,
        activation: "tanh",
        bias: 0.0,
        input: true
      }) ++
      # Hidden neurons
      (for id <- hidden_ids, do: %{
        id: id,
        layer: String.at(id, 1) |> String.to_integer(),
        activation: "sigmoid",
        bias: :rand.uniform() - 0.5,
        input: false
      }) ++
      # Output neurons
      (for id <- output_ids, do: %{
        id: id,
        layer: hidden_layers + 1,
        activation: "tanh",
        bias: :rand.uniform() - 0.5,
        input: false
      })
    
    # Create connections
    connections = []
    
    # Connect input to first hidden layer
    connections = connections ++ 
      (for i <- input_ids, h <- Enum.filter(hidden_ids, &(String.at(&1, 1) == "1")), do: %{
        source_id: i,
        target_id: h,
        weight: :rand.uniform() * 2 - 1
      })
    
    # Connect between hidden layers
    connections = connections ++
      (for l <- 1..(hidden_layers-1) do
        source_layer = Enum.filter(hidden_ids, &(String.at(&1, 1) == "#{l}"))
        target_layer = Enum.filter(hidden_ids, &(String.at(&1, 1) == "#{l+1}"))
        
        for s <- source_layer, t <- target_layer, do: %{
          source_id: s,
          target_id: t,
          weight: :rand.uniform() * 2 - 1
        }
      end)
      |> List.flatten()
    
    # Connect last hidden layer to output
    last_hidden = Enum.filter(hidden_ids, &(String.at(&1, 1) == "#{hidden_layers}"))
    
    connections = connections ++
      (for h <- last_hidden, o <- output_ids, do: %{
        source_id: h,
        target_id: o,
        weight: :rand.uniform() * 2 - 1
      })
    
    # Create genotype
    %{
      neurons: neurons,
      connections: connections,
      fitness: [0.0],
      metadata: %{
        generation: 0,
        species: 0
      }
    }
  end
  
  @doc """
  Generate mock market data for testing.
  
  ## Parameters
  
  - symbol: Trading symbol
  - count: Number of candles to generate
  - timeframe: Timeframe in minutes
  
  ## Returns
  
  A list of mock market data candles
  """
  def generate_mock_market_data(symbol, count, timeframe \\ 15) do
    # Base starting price
    base_price = case symbol do
      "EURUSD" -> 1.1000
      "GBPUSD" -> 1.3000
      "USDJPY" -> 110.00
      _ -> 1.0000
    end
    
    # Generate candles with some realistic price movement
    now = DateTime.utc_now()
    
    Enum.map(1..count, fn i ->
      # Linear trend
      trend = i / count * 0.1
      
      # Cyclic component (sine wave)
      cycle = :math.sin(i / 10) * 0.01
      
      # Random component
      noise = (:rand.uniform() - 0.5) * 0.005
      
      # Calculate price components
      price = base_price * (1 + trend + cycle + noise)
      spread = price * 0.0002  # 2 pip spread
      
      # Calculate high/low with some randomness
      high_range = price * (:rand.uniform() * 0.004 + 0.001)
      low_range = price * (:rand.uniform() * 0.004 + 0.001)
      
      # Generate candle
      %{
        symbol: symbol,
        time: DateTime.add(now, -i * timeframe * 60), # Go backwards from now
        open: price,
        high: price + high_range,
        low: price - low_range,
        close: price + (:rand.uniform() - 0.5) * 0.003 * price,
        volume: :rand.uniform(1000) + 100,
        timeframe: timeframe
      }
    end)
    # Sort by time ascending (oldest first)
    |> Enum.sort_by(fn candle -> candle.time end, &<=/2)
  end
  
  @doc """
  Create indicators from market data for testing.
  
  ## Parameters
  
  - market_data: List of market data candles
  
  ## Returns
  
  A map of indicators
  """
  def generate_mock_indicators(market_data) do
    # Basic indicators with random but sensible values
    
    # Number of candles
    n = length(market_data)
    
    %{
      sma_20: Enum.map(1..n, fn i -> 
        candle = Enum.at(market_data, min(i, n-1))
        candle.close * (1 + (:rand.uniform() - 0.5) * 0.01)
      end),
      
      sma_50: Enum.map(1..n, fn i -> 
        candle = Enum.at(market_data, min(i, n-1))
        candle.close * (1 + (:rand.uniform() - 0.5) * 0.02)
      end),
      
      sma_200: Enum.map(1..n, fn i -> 
        candle = Enum.at(market_data, min(i, n-1))
        candle.close * (1 + (:rand.uniform() - 0.5) * 0.04)
      end),
      
      rsi_14: Enum.map(1..n, fn _i -> 
        # RSI between 30 and 70 normally
        30 + :rand.uniform() * 40
      end),
      
      macd: Enum.map(1..n, fn _i -> 
        # MACD typically between -0.01 and 0.01
        (:rand.uniform() - 0.5) * 0.02
      end),
      
      macd_signal: Enum.map(1..n, fn _i -> 
        # Signal line
        (:rand.uniform() - 0.5) * 0.02
      end),
      
      bollinger_upper: Enum.map(1..n, fn _i -> 
        # Typically +2% from price
        0.02 * (1 + (:rand.uniform() - 0.5) * 0.3)
      end),
      
      bollinger_lower: Enum.map(1..n, fn _i -> 
        # Typically -2% from price
        -0.02 * (1 + (:rand.uniform() - 0.5) * 0.3)
      end),
      
      atr_14: Enum.map(1..n, fn _i -> 
        # ATR as percentage of price
        0.002 * (1 + (:rand.uniform() - 0.5) * 0.5)
      end),
      
      adx_14: Enum.map(1..n, fn _i -> 
        # ADX between 10 and 50
        10 + :rand.uniform() * 40
      end),
      
      stoch_k: Enum.map(1..n, fn _i -> 
        # Stochastic K between 10 and 90
        10 + :rand.uniform() * 80
      end),
      
      stoch_d: Enum.map(1..n, fn _i -> 
        # Stochastic D between 10 and 90
        10 + :rand.uniform() * 80
      end)
    }
  end
  
  @doc """
  Verify an agent's structure is valid.
  
  ## Parameters
  
  - agent: The agent to verify
  
  ## Returns
  
  {:ok, validation_info} if valid, {:error, reason} otherwise
  """
  def verify_agent_structure(agent) do
    cond do
      not is_map(agent) ->
        {:error, "Agent is not a map"}
        
      not Map.has_key?(agent, :neurons) ->
        {:error, "Agent does not have neurons"}
        
      not Map.has_key?(agent, :connections) ->
        {:error, "Agent does not have connections"}
        
      not is_list(agent.neurons) or agent.neurons == [] ->
        {:error, "Agent has no neurons"}
        
      not is_list(agent.connections) ->
        {:error, "Agent connections are not a list"}
        
      true ->
        # Basic structure is valid
        
        # Verify neuron IDs are unique
        neuron_ids = Enum.map(agent.neurons, & &1.id)
        if length(Enum.uniq(neuron_ids)) != length(neuron_ids) do
          {:error, "Agent has duplicate neuron IDs"}
        else
          # Verify connection endpoints exist
          source_ids = Enum.map(agent.connections, & &1.source_id)
          target_ids = Enum.map(agent.connections, & &1.target_id)
          
          unknown_sources = Enum.filter(source_ids, &(&1 not in neuron_ids))
          unknown_targets = Enum.filter(target_ids, &(&1 not in neuron_ids))
          
          cond do
            unknown_sources != [] ->
              {:error, "Connections reference unknown source neurons: #{inspect(unknown_sources)}"}
              
            unknown_targets != [] ->
              {:error, "Connections reference unknown target neurons: #{inspect(unknown_targets)}"}
              
            true ->
              # Agent structure is valid
              {:ok, %{
                neuron_count: length(agent.neurons),
                connection_count: length(agent.connections),
                input_count: Enum.count(agent.neurons, & &1.input),
                output_count: Enum.count(agent.neurons, & &1.layer == Enum.max(Enum.map(agent.neurons, & &1.layer)))
              }}
          end
        end
    end
  end
  
  @doc """
  Verify an experiment's structure is valid.
  
  ## Parameters
  
  - experiment: The experiment to verify
  
  ## Returns
  
  {:ok, validation_info} if valid, {:error, reason} otherwise
  """
  def verify_experiment_structure(experiment) do
    cond do
      not is_map(experiment) ->
        {:error, "Experiment is not a map"}
        
      not Map.has_key?(experiment, :id) ->
        {:error, "Experiment does not have an ID"}
        
      not Map.has_key?(experiment, :status) ->
        {:error, "Experiment does not have a status"}
        
      not is_atom(experiment.id) ->
        {:error, "Experiment ID is not an atom"}
        
      experiment.status not in [:initializing, :running, :complete, :stopping, :stopped, :error] ->
        {:error, "Experiment has invalid status: #{experiment.status}"}
        
      true ->
        # Basic structure is valid
        {:ok, %{
          id: experiment.id,
          status: experiment.status,
          has_best_agent: Map.has_key?(experiment, :best_agent),
          islands: Map.get(experiment, :islands, 0),
          generations: Map.get(experiment, :generations, 0)
        }}
    end
  end
end