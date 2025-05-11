# Extending Bardo

This guide shows how to extend Bardo with custom components for your specific needs.

## Custom Sensors

Sensors are the interface between the environment and your neural network's inputs. They convert external data into neural signals.

### Implementing a Custom Sensor

To create a custom sensor, implement the `Bardo.AgentManager.Sensor` behaviour:

```elixir
defmodule MyApp.CustomSensor do
  @behaviour Bardo.AgentManager.Sensor
  
  @impl true
  def init(id, cortex_pid, vl, fanout) do
    # Initialize sensor state
    {:ok, %{
      id: id,
      sensor_type: :custom,
      fanout: fanout,
      cortex_pid: cortex_pid,
      vl: vl,
      # Any additional state you need
      custom_state: %{}
    }}
  end
  
  @impl true
  def sense(state, data) do
    # Process incoming data into neural signals
    signals = process_data(data, state.fanout)
    
    # Return signals and updated state
    {:ok, signals, state}
  end
  
  defp process_data(data, fanout) do
    # Custom data processing logic
    # Must return a list of values with length equal to fanout
    List.duplicate(0.0, fanout)
  end
end
```

### Common Sensor Types

#### Vector Sensor

A simple sensor that passes numeric vectors directly to the neural network:

```elixir
defmodule MyApp.VectorSensor do
  @behaviour Bardo.AgentManager.Sensor
  
  @impl true
  def init(id, cortex_pid, vl, fanout) do
    {:ok, %{
      id: id,
      sensor_type: :vector,
      fanout: fanout,
      cortex_pid: cortex_pid,
      vl: vl
    }}
  end
  
  @impl true
  def sense(state, data) do
    # Ensure data is a list with the right length
    signals = cond do
      is_list(data) and length(data) == state.fanout ->
        data
        
      is_list(data) and length(data) < state.fanout ->
        # Pad with zeros if too short
        data ++ List.duplicate(0.0, state.fanout - length(data))
        
      is_list(data) and length(data) > state.fanout ->
        # Truncate if too long
        Enum.take(data, state.fanout)
        
      true ->
        # Default if data is not a list
        List.duplicate(0.0, state.fanout)
    end
    
    {:ok, signals, state}
  end
end
```

#### Image Sensor

A sensor for processing image data:

```elixir
defmodule MyApp.ImageSensor do
  @behaviour Bardo.AgentManager.Sensor
  
  @impl true
  def init(id, cortex_pid, vl, fanout) do
    {:ok, %{
      id: id,
      sensor_type: :image,
      fanout: fanout,
      cortex_pid: cortex_pid,
      vl: vl,
      # Configuration for image processing
      image_size: {28, 28}  # Default to MNIST size
    }}
  end
  
  @impl true
  def sense(state, image_data) do
    # Process image data
    signals = process_image(image_data, state.image_size, state.fanout)
    
    {:ok, signals, state}
  end
  
  defp process_image(image_data, {width, height}, fanout) do
    # Resize and normalize image
    resized = resize_image(image_data, width, height)
    
    # Convert to grayscale values between 0.0 and 1.0
    pixels = normalize_pixels(resized)
    
    # Ensure we have exactly fanout elements
    cond do
      length(pixels) == fanout -> pixels
      length(pixels) < fanout -> pixels ++ List.duplicate(0.0, fanout - length(pixels))
      length(pixels) > fanout -> Enum.take(pixels, fanout)
    end
  end
  
  defp resize_image(image_data, width, height) do
    # Image resizing implementation
    # This would typically use a library like Image
    # ...
    
    # Return resized image
    resized_image
  end
  
  defp normalize_pixels(image) do
    # Convert image pixels to values between 0.0 and 1.0
    # ...
    
    # Return normalized pixels
    normalized_pixels
  end
end
```

## Custom Actuators

Actuators convert the neural network's outputs into actions in the environment.

### Implementing a Custom Actuator

To create a custom actuator, implement the `Bardo.AgentManager.Actuator` behaviour:

```elixir
defmodule MyApp.CustomActuator do
  @behaviour Bardo.AgentManager.Actuator
  
  @impl true
  def init(id, cortex_pid, vl, fanin) do
    # Initialize actuator state
    {:ok, %{
      id: id,
      actuator_type: :custom,
      fanin: fanin,
      cortex_pid: cortex_pid,
      vl: vl,
      # Any additional state you need
      custom_state: %{}
    }}
  end
  
  @impl true
  def actuate(state, {agent_id, signals, _params, _vl, scape, actuator_id, _mod_state}) do
    # Process neural signals into actions
    action = process_signals(signals)
    
    # Return action and updated state
    {:ok, action, state}
  end
  
  defp process_signals(signals) do
    # Custom signal processing logic
    # Convert neural outputs to meaningful actions
    
    # Example: find the index of the highest value (winner-takes-all)
    {index, _value} = Enum.with_index(signals)
                      |> Enum.max_by(fn {value, _index} -> value end)
    
    # Return action based on index
    index
  end
end
```

### Common Actuator Types

#### Discrete Action Actuator

An actuator that selects one discrete action from a set of possibilities:

```elixir
defmodule MyApp.DiscreteActionActuator do
  @behaviour Bardo.AgentManager.Actuator
  
  @impl true
  def init(id, cortex_pid, vl, fanin) do
    {:ok, %{
      id: id,
      actuator_type: :discrete_action,
      fanin: fanin,
      cortex_pid: cortex_pid,
      vl: vl,
      actions: [:action1, :action2, :action3, :action4]  # Default actions
    }}
  end
  
  @impl true
  def actuate(state, {_agent_id, signals, _params, _vl, _scape, _actuator_id, _mod_state}) do
    # Find the strongest output
    {max_index, _} = Enum.with_index(signals)
                    |> Enum.max_by(fn {value, _index} -> value end)
    
    # Convert to action
    action = Enum.at(state.actions, max_index, List.last(state.actions))
    
    {:ok, action, state}
  end
end
```

#### Continuous Control Actuator

An actuator for continuous control tasks:

```elixir
defmodule MyApp.ContinuousControlActuator do
  @behaviour Bardo.AgentManager.Actuator
  
  @impl true
  def init(id, cortex_pid, vl, fanin) do
    {:ok, %{
      id: id,
      actuator_type: :continuous_control,
      fanin: fanin,
      cortex_pid: cortex_pid,
      vl: vl,
      # Output scaling
      min_values: List.duplicate(-1.0, fanin),
      max_values: List.duplicate(1.0, fanin)
    }}
  end
  
  @impl true
  def actuate(state, {_agent_id, signals, _params, _vl, _scape, _actuator_id, _mod_state}) do
    # Scale outputs to the desired ranges
    scaled_outputs = Enum.zip([signals, state.min_values, state.max_values])
                    |> Enum.map(fn {signal, min_val, max_val} ->
                      min_val + (signal * (max_val - min_val))
                    end)
    
    {:ok, scaled_outputs, state}
  end
end
```

## Custom Morphologies

Morphologies define the structure of your neural networks, including inputs, outputs, and hidden layers.

### Implementing a Custom Morphology

To create a custom morphology, implement the `Bardo.Morphology` behaviour:

```elixir
defmodule MyApp.CustomMorphology do
  @behaviour Bardo.Morphology
  
  @impl true
  def sensor_spec do
    [
      %{
        id: :input_sensor,
        fanout: 4,  # 4 inputs
        vl: :float,
        cortex_id: nil,  # Will be filled in at runtime
        name: "Input Sensor"
      }
    ]
  end
  
  @impl true
  def actuator_spec do
    [
      %{
        id: :output_actuator,
        fanin: 2,  # 2 outputs
        vl: :float,
        cortex_id: nil,  # Will be filled in at runtime
        name: "Output Actuator"
      }
    ]
  end
  
  @impl true
  def hidden_layer_spec do
    [
      %{
        id: :hidden1,
        size: 6,  # 6 neurons in the first hidden layer
        af: :sigmoid,  # Activation function
        input_layer_ids: [:input_sensor],  # Connected to inputs
        output_layer_ids: [:hidden2]  # Connected to next hidden layer
      },
      %{
        id: :hidden2,
        size: 4,  # 4 neurons in the second hidden layer
        af: :tanh,  # Different activation function
        input_layer_ids: [:hidden1],  # Connected to previous hidden layer
        output_layer_ids: [:output_actuator]  # Connected to outputs
      }
    ]
  end
end
```

### Morphology Patterns

#### Feed-Forward Network

A basic feed-forward network:

```elixir
defmodule MyApp.FeedForwardMorphology do
  @behaviour Bardo.Morphology
  
  @impl true
  def sensor_spec do
    [
      %{
        id: :input,
        fanout: 10,  # 10 inputs
        vl: :float,
        cortex_id: nil,
        name: "Input Layer"
      }
    ]
  end
  
  @impl true
  def actuator_spec do
    [
      %{
        id: :output,
        fanin: 3,  # 3 outputs
        vl: :float,
        cortex_id: nil,
        name: "Output Layer"
      }
    ]
  end
  
  @impl true
  def hidden_layer_spec do
    [
      %{
        id: :hidden,
        size: 8,  # 8 neurons in hidden layer
        af: :sigmoid,
        input_layer_ids: [:input],
        output_layer_ids: [:output]
      }
    ]
  end
end
```

#### Deep Network

A deeper network with multiple hidden layers:

```elixir
defmodule MyApp.DeepNetworkMorphology do
  @behaviour Bardo.Morphology
  
  @impl true
  def sensor_spec do
    [
      %{
        id: :input,
        fanout: 28 * 28,  # For MNIST images
        vl: :float,
        cortex_id: nil,
        name: "Image Input"
      }
    ]
  end
  
  @impl true
  def actuator_spec do
    [
      %{
        id: :output,
        fanin: 10,  # 10 digits (0-9)
        vl: :float,
        cortex_id: nil,
        name: "Digit Output"
      }
    ]
  end
  
  @impl true
  def hidden_layer_spec do
    [
      %{
        id: :hidden1,
        size: 128,
        af: :relu,
        input_layer_ids: [:input],
        output_layer_ids: [:hidden2]
      },
      %{
        id: :hidden2,
        size: 64,
        af: :relu,
        input_layer_ids: [:hidden1],
        output_layer_ids: [:hidden3]
      },
      %{
        id: :hidden3,
        size: 32,
        af: :relu,
        input_layer_ids: [:hidden2],
        output_layer_ids: [:output]
      }
    ]
  end
end
```

#### Recurrent Network

A recurrent network with feedback connections:

```elixir
defmodule MyApp.RecurrentNetworkMorphology do
  @behaviour Bardo.Morphology
  
  @impl true
  def sensor_spec do
    [
      %{
        id: :input,
        fanout: 5,
        vl: :float,
        cortex_id: nil,
        name: "Sequence Input"
      }
    ]
  end
  
  @impl true
  def actuator_spec do
    [
      %{
        id: :output,
        fanin: 5,
        vl: :float,
        cortex_id: nil,
        name: "Sequence Output"
      }
    ]
  end
  
  @impl true
  def hidden_layer_spec do
    [
      %{
        id: :recurrent,
        size: 10,
        af: :tanh,
        input_layer_ids: [:input, :recurrent], # Self-connection
        output_layer_ids: [:output, :recurrent] # Self-connection
      }
    ]
  end
end
```

## Custom Fitness Functions

Fitness functions evaluate the performance of evolved neural networks.

### Basic Fitness Function

```elixir
def my_fitness_function(genotype) do
  # Convert genotype to neural network
  nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
  
  # Test cases
  test_cases = [
    {inputs1, expected1},
    {inputs2, expected2},
    # More test cases...
  ]
  
  # Evaluate on all test cases
  total_fitness = Enum.reduce(test_cases, 0, fn {inputs, expected}, acc ->
    # Get actual output
    actual = Bardo.AgentManager.Cortex.activate(nn, inputs)
    
    # Calculate error
    error = calculate_error(actual, expected)
    
    # Convert error to fitness (higher is better)
    fitness = 1.0 / (1.0 + error)
    
    # Add to total
    acc + fitness
  end)
  
  # Return average fitness
  total_fitness / length(test_cases)
end

defp calculate_error(actual, expected) do
  # Mean squared error
  Enum.zip(actual, expected)
  |> Enum.map(fn {a, e} -> :math.pow(a - e, 2) end)
  |> Enum.sum()
  |> Kernel./(length(actual))
end
```

### Simulation-Based Fitness Function

For more complex tasks, evaluate agents in a simulated environment:

```elixir
def simulation_fitness_function(genotype) do
  # Convert genotype to neural network
  nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
  
  # Setup simulation environment
  env = initialize_environment()
  
  # Run simulation for fixed number of steps
  {final_env, reward_history} = run_simulation(nn, env, 1000)
  
  # Calculate fitness from rewards
  total_reward = Enum.sum(reward_history)
  
  # Return fitness
  total_reward
end

defp initialize_environment do
  # Setup initial environment state
  # ...
  
  env
end

defp run_simulation(nn, env, steps) do
  run_simulation_loop(nn, env, steps, [], 0)
end

defp run_simulation_loop(_nn, env, 0, rewards, _step) do
  # Simulation complete
  {env, rewards}
end

defp run_simulation_loop(nn, env, steps_left, rewards, step) do
  # Get observations from environment
  observations = get_observations(env)
  
  # Get action from neural network
  action = Bardo.AgentManager.Cortex.activate(nn, observations)
  
  # Apply action to environment
  {new_env, reward, done} = apply_action(env, action)
  
  if done do
    # Simulation ended early
    {new_env, [reward | rewards]}
  else
    # Continue simulation
    run_simulation_loop(nn, new_env, steps_left - 1, [reward | rewards], step + 1)
  end
end

defp get_observations(env) do
  # Extract observations from environment
  # ...
  
  observations
end

defp apply_action(env, action) do
  # Apply action to environment and get reward
  # ...
  
  {updated_env, reward, done}
end
```

## Custom Selection Algorithms

Selection algorithms determine which genotypes get to reproduce.

### Implementing a Custom Selection Algorithm

```elixir
defmodule MyApp.CustomSelectionAlgorithm do
  @behaviour Bardo.PopulationManager.SelectionAlgorithm
  
  @impl true
  def select(population, options) do
    # Sort population by fitness (assuming higher is better)
    sorted = Enum.sort_by(population, fn {_genotype, fitness} -> fitness end, &>=/2)
    
    # Get population size
    pop_size = length(population)
    
    # Get selection parameters with defaults
    elite_count = Map.get(options, :elite_count, 2)
    tournament_size = Map.get(options, :tournament_size, 3)
    tournament_count = pop_size - elite_count
    
    # Directly select elites
    elites = Enum.take(sorted, elite_count)
    
    # Select the rest through tournament selection
    tournament_selected = Enum.map(1..tournament_count, fn _ ->
      # Randomly select candidates for tournament
      candidates = Enum.take_random(population, tournament_size)
      
      # Return the best candidate
      Enum.max_by(candidates, fn {_genotype, fitness} -> fitness end)
    end)
    
    # Combine elites and tournament selections
    elites ++ tournament_selected
  end
end
```

## Custom Plasticity Rules

Plasticity rules define how neural connections change during the lifetime of a network.

### Implementing a Custom Plasticity Rule

```elixir
defmodule MyApp.CustomPlasticityRule do
  @behaviour Bardo.Plasticity
  
  @impl true
  def apply_rule(weight, pre_activation, post_activation, parameters) do
    # Get learning rate
    learning_rate = Map.get(parameters, :learning_rate, 0.01)
    
    # Simple Hebbian learning rule: "Neurons that fire together, wire together"
    delta = learning_rate * pre_activation * post_activation
    
    # Update weight
    new_weight = weight + delta
    
    # Clamp weight to valid range
    clamped = max(-1.0, min(1.0, new_weight))
    
    clamped
  end
end
```

## Extending the UI/Visualization

If you're building a visualization for your Bardo experiments, you can add custom components.

### Network Visualization

```elixir
defmodule MyApp.NetworkVisualizer do
  @doc """
  Converts a neural network to a visualization format.
  """
  def visualize(nn) do
    # Extract neurons and connections
    neurons = extract_neurons(nn)
    connections = extract_connections(nn)
    
    # Format for visualization library
    %{
      nodes: format_nodes(neurons),
      edges: format_edges(connections)
    }
  end
  
  defp extract_neurons(nn) do
    # Extract neuron data from neural network
    # ...
    
    neurons
  end
  
  defp extract_connections(nn) do
    # Extract connection data from neural network
    # ...
    
    connections
  end
  
  defp format_nodes(neurons) do
    # Format neurons for visualization
    Enum.map(neurons, fn neuron ->
      %{
        id: neuron.id,
        label: "Neuron #{neuron.id}",
        type: neuron.type,
        activation: neuron.activation_function
      }
    end)
  end
  
  defp format_edges(connections) do
    # Format connections for visualization
    Enum.map(connections, fn connection ->
      %{
        source: connection.source_id,
        target: connection.target_id,
        weight: connection.weight
      }
    end)
  end
end
```

### Fitness Chart

```elixir
defmodule MyApp.FitnessChart do
  @doc """
  Formats fitness history data for charting.
  """
  def format_fitness_history(experiment_id) do
    # Get experiment data
    {:ok, experiment} = Bardo.ExperimentManager.get_experiment(experiment_id)
    
    # Extract fitness history
    fitness_history = experiment.fitness_history
    
    # Format for charting
    %{
      labels: Enum.map(0..(length(fitness_history) - 1), &Integer.to_string/1),
      datasets: [
        %{
          label: "Best Fitness",
          data: fitness_history,
          borderColor: "rgba(75, 192, 192, 1)",
          backgroundColor: "rgba(75, 192, 192, 0.2)"
        }
      ]
    }
  end
end
```

## Integrating with External Systems

### Custom Data Loaders

```elixir
defmodule MyApp.DataLoader do
  @doc """
  Loads training data from external sources.
  """
  def load_training_data(source) do
    case source do
      {:csv, filename} ->
        load_from_csv(filename)
        
      {:database, query} ->
        load_from_database(query)
        
      {:api, url} ->
        load_from_api(url)
        
      _ ->
        {:error, :unknown_source}
    end
  end
  
  defp load_from_csv(filename) do
    # Parse CSV file
    # ...
    
    {:ok, data}
  end
  
  defp load_from_database(query) do
    # Execute database query
    # ...
    
    {:ok, data}
  end
  
  defp load_from_api(url) do
    # Make API request
    # ...
    
    {:ok, data}
  end
end
```

### External Model Exporters

```elixir
defmodule MyApp.ModelExporter do
  @doc """
  Exports Bardo models to different formats.
  """
  def export_model(genotype, format, filename) do
    case format do
      :onnx ->
        export_to_onnx(genotype, filename)
        
      :tensorflow ->
        export_to_tensorflow(genotype, filename)
        
      :json ->
        export_to_json(genotype, filename)
        
      _ ->
        {:error, :unknown_format}
    end
  end
  
  defp export_to_onnx(genotype, filename) do
    # Convert to ONNX format
    # ...
    
    {:ok, filename}
  end
  
  defp export_to_tensorflow(genotype, filename) do
    # Convert to TensorFlow format
    # ...
    
    {:ok, filename}
  end
  
  defp export_to_json(genotype, filename) do
    # Convert to JSON
    json = Jason.encode!(genotype)
    
    # Write to file
    File.write(filename, json)
  end
end
```

<!-- Distributed computing extensions will be supported in a future release -->

## Performance Optimizations

### Custom Cache Strategy

```elixir
defmodule MyApp.EvaluationCache do
  @doc """
  Initializes an evaluation cache.
  """
  def init do
    # Create ETS table for caching
    :ets.new(:evaluation_cache, [:set, :public, :named_table])
    :ok
  end
  
  @doc """
  Gets or computes fitness for a genotype.
  """
  def get_or_compute(genotype, fitness_function) do
    # Generate cache key
    key = :erlang.phash2(genotype)
    
    # Try to get from cache
    case :ets.lookup(:evaluation_cache, key) do
      [{^key, fitness}] ->
        # Cache hit
        fitness
        
      [] ->
        # Cache miss, compute fitness
        fitness = fitness_function.(genotype)
        
        # Store in cache
        :ets.insert(:evaluation_cache, {key, fitness})
        
        fitness
    end
  end
  
  @doc """
  Clears the evaluation cache.
  """
  def clear do
    :ets.delete_all_objects(:evaluation_cache)
    :ok
  end
end
```

## Real-world Extensions

### Financial Market Integration

```elixir
defmodule MyApp.MarketIntegration do
  @doc """
  Creates a Bardo sensor for financial market data.
  """
  def create_market_sensor(market, timeframe) do
    # Define sensor module
    defmodule MarketSensor do
      @behaviour Bardo.AgentManager.Sensor
      
      @impl true
      def init(id, cortex_pid, vl, fanout) do
        {:ok, %{
          id: id,
          sensor_type: :market,
          fanout: fanout,
          cortex_pid: cortex_pid,
          vl: vl,
          market: market,
          timeframe: timeframe,
          indicators: [:price, :volume, :rsi, :macd]
        }}
      end
      
      @impl true
      def sense(state, data) do
        # Get market data
        market_data = get_market_data(state.market, state.timeframe, data.timestamp)
        
        # Calculate technical indicators
        indicators = calculate_indicators(market_data, state.indicators)
        
        # Format as neural inputs
        signals = format_indicators(indicators, state.fanout)
        
        {:ok, signals, state}
      end
      
      defp get_market_data(market, timeframe, timestamp) do
        # Fetch market data from API or database
        # ...
        
        market_data
      end
      
      defp calculate_indicators(market_data, indicators) do
        # Calculate technical indicators
        # ...
        
        calculated_indicators
      end
      
      defp format_indicators(indicators, fanout) do
        # Format indicators as neural inputs
        # ...
        
        formatted_indicators
      end
    end
    
    # Return sensor module
    MarketSensor
  end
end
```

## Integration with Machine Learning Frameworks

### TensorFlow Integration

```elixir
defmodule MyApp.TensorFlowIntegration do
  @doc """
  Converts a Bardo neural network to a TensorFlow model.
  """
  def convert_to_tensorflow(nn) do
    # Extract network structure
    structure = extract_network_structure(nn)
    
    # Convert to TensorFlow model
    tf_model = build_tensorflow_model(structure)
    
    {:ok, tf_model}
  end
  
  defp extract_network_structure(nn) do
    # Extract layers, neurons, and connections
    # ...
    
    structure
  end
  
  defp build_tensorflow_model(structure) do
    # Build TensorFlow model using Python interop
    # ...
    
    tf_model
  end
  
  @doc """
  Runs inference using TensorFlow.
  """
  def run_inference(tf_model, inputs) do
    # Run inference in TensorFlow
    # ...
    
    {:ok, outputs}
  end
end
```