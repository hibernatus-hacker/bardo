# Using Bardo as a Library

This tutorial provides a step-by-step guide to using Bardo as a library in your own Elixir applications.

## 1. Setting Up Your Project

First, add Bardo as a dependency in your `mix.exs` file:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

Then, fetch the dependencies:

```shell
mix deps.get
```

## 2. Creating a Simple XOR Solver

Let's create a simple application that uses Bardo to evolve a neural network that solves the XOR problem.

### 2.1 Define Your Application

Create a new module in your project:

```elixir
defmodule MyApp.XorSolver do
  @moduledoc """
  A module that uses Bardo to evolve a neural network solving the XOR problem.
  """
  
  @doc """
  Evolves a neural network to solve XOR and returns the champion.
  """
  def run do
    # Start Bardo subsystems
    Bardo.start()
    
    # Create a unique experiment ID
    experiment_id = "xor_#{:os.system_time(:millisecond)}"
    
    # Create the experiment
    {:ok, _pid} = Bardo.ExperimentManager.new_experiment(experiment_id)
    
    # Configure the experiment
    :ok = Bardo.ExperimentManager.configure(experiment_id, %{
      population_size: 100,
      max_generations: 50,
      mutation_rate: 0.3,
      fitness_goal: 3.9  # Stop when we reach this fitness (max is 4.0)
    })
    
    # Start the evolution with our fitness function
    :ok = Bardo.ExperimentManager.start_evaluation(experiment_id, &evaluate_xor/1)
    
    # Wait for the experiment to complete
    {:ok, experiment} = wait_for_completion(experiment_id)
    
    # Get the best solution
    {:ok, champion} = Bardo.ExperimentManager.get_best_solution(experiment_id)
    
    # Test the champion
    test_champion(champion)
    
    # Return the champion genotype
    champion
  end
  
  @doc """
  Evaluates a genotype on the XOR problem.
  """
  def evaluate_xor(genotype) do
    # Convert genotype to neural network
    nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
    
    # The XOR inputs and expected outputs
    test_cases = [
      {[0.0, 0.0], 0.0},
      {[0.0, 1.0], 1.0},
      {[1.0, 0.0], 1.0},
      {[1.0, 1.0], 0.0}
    ]
    
    # Test each case and calculate fitness
    fitness = Enum.reduce(test_cases, 0, fn {inputs, expected}, acc ->
      # Get the actual output
      result = Bardo.AgentManager.Cortex.activate(nn, inputs)
      output = List.first(result)
      
      # Calculate fitness component (1.0 - error)
      # The closer to expected, the higher the fitness
      fitness_component = 1.0 - abs(expected - output)
      
      # Add to total fitness
      acc + fitness_component
    end)
    
    fitness
  end
  
  @doc """
  Tests a champion genotype on the XOR problem.
  """
  def test_champion(genotype) do
    nn = Bardo.AgentManager.Cortex.from_genotype(genotype)
    
    test_cases = [
      {[0.0, 0.0], 0.0},
      {[0.0, 1.0], 1.0},
      {[1.0, 0.0], 1.0},
      {[1.0, 1.0], 0.0}
    ]
    
    IO.puts("\nTesting champion on XOR problem:")
    Enum.each(test_cases, fn {inputs, expected} ->
      result = Bardo.AgentManager.Cortex.activate(nn, inputs)
      output = List.first(result)
      IO.puts("Input: #{inspect(inputs)} => Output: #{Float.round(output, 4)} (Expected: #{expected})")
    end)
  end
  
  @doc """
  Waits for an experiment to complete.
  """
  def wait_for_completion(experiment_id, max_attempts \\ 100) do
    if max_attempts <= 0 do
      {:error, :timeout}
    else
      case Bardo.ExperimentManager.status(experiment_id) do
        {:complete, experiment} ->
          {:ok, experiment}
        
        {:in_progress, _} ->
          :timer.sleep(100)
          wait_for_completion(experiment_id, max_attempts - 1)
        
        other ->
          {:error, other}
      end
    end
  end
end
```

### 2.2 Running Your Application

Now you can run your XOR solver from an IEx session:

```elixir
iex> MyApp.XorSolver.run()
```

## 3. Creating a Custom Environment

Let's create a more complex example where we define a custom environment with specific sensors and actuators.

### 3.1 Define a Simple Grid World Environment

```elixir
defmodule MyApp.GridWorld do
  @moduledoc """
  A simple 2D grid world where an agent must navigate to a goal.
  """
  
  defmodule Morphology do
    @behaviour Bardo.Morphology
    
    @impl true
    def sensor_spec do
      [
        %{
          id: :position_sensor,
          fanout: 2,
          vl: :float,
          cortex_id: nil,
          name: "Position Sensor"
        },
        %{
          id: :goal_sensor,
          fanout: 2,
          vl: :float,
          cortex_id: nil,
          name: "Goal Sensor"
        }
      ]
    end
    
    @impl true
    def actuator_spec do
      [
        %{
          id: :movement_actuator,
          fanin: 4,  # Up, Down, Left, Right
          vl: :float,
          cortex_id: nil,
          name: "Movement Actuator"
        }
      ]
    end
    
    @impl true
    def hidden_layer_spec do
      [
        %{
          id: :hidden,
          size: 6,
          af: :tanh,
          input_layer_ids: [:position_sensor, :goal_sensor],
          output_layer_ids: [:movement_actuator]
        }
      ]
    end
  end
  
  defmodule PositionSensor do
    @behaviour Bardo.AgentManager.Sensor
    
    @impl true
    def init(id, cortex_pid, vl, fanout) do
      {:ok, %{
        id: id,
        sensor_type: :position,
        fanout: fanout,
        cortex_pid: cortex_pid,
        vl: vl
      }}
    end
    
    @impl true
    def sense(state, data) do
      # Normalize position to range 0.0..1.0
      {x, y} = data.position
      {width, height} = data.grid_size
      
      signals = [
        x / width,
        y / height
      ]
      
      {:ok, signals, state}
    end
  end
  
  defmodule GoalSensor do
    @behaviour Bardo.AgentManager.Sensor
    
    @impl true
    def init(id, cortex_pid, vl, fanout) do
      {:ok, %{
        id: id,
        sensor_type: :goal,
        fanout: fanout,
        cortex_pid: cortex_pid,
        vl: vl
      }}
    end
    
    @impl true
    def sense(state, data) do
      # Calculate direction to goal
      {x, y} = data.position
      {goal_x, goal_y} = data.goal
      
      # Direction vector to goal
      dx = (goal_x - x) / data.grid_size |> element(0)
      dy = (goal_y - y) / data.grid_size |> element(1)
      
      signals = [dx, dy]
      
      {:ok, signals, state}
    end
  end
  
  defmodule MovementActuator do
    @behaviour Bardo.AgentManager.Actuator
    
    @impl true
    def init(id, cortex_pid, vl, fanin) do
      {:ok, %{
        id: id,
        actuator_type: :movement,
        fanin: fanin,
        cortex_pid: cortex_pid,
        vl: vl
      }}
    end
    
    @impl true
    def actuate(state, {_, signals, _, _, _, _, _}) do
      # Get movement direction from neural network outputs
      [up, down, left, right] = signals
      
      # Choose the strongest output
      direction = Enum.zip([:up, :down, :left, :right], [up, down, left, right])
                  |> Enum.max_by(fn {_, value} -> value end)
                  |> elem(0)
      
      {:ok, direction, state}
    end
  end
  
  @doc """
  Runs the grid world simulation.
  """
  def run do
    # Start Bardo subsystems
    Bardo.start()
    
    # Create a unique experiment ID
    experiment_id = "grid_world_#{:os.system_time(:millisecond)}"
    
    # Create the experiment
    {:ok, _pid} = Bardo.ExperimentManager.new_experiment(experiment_id)
    
    # Configure the experiment
    :ok = Bardo.ExperimentManager.configure(experiment_id, %{
      population_size: 100,
      max_generations: 50,
      mutation_rate: 0.3,
      fitness_goal: 0.95  # Stop when we reach this fitness (max is 1.0)
    })
    
    # Start the evolution with our fitness function
    :ok = Bardo.ExperimentManager.start_evaluation(experiment_id, &evaluate_navigation/1)
    
    # Wait for the experiment to complete
    {:ok, _} = wait_for_completion(experiment_id)
    
    # Get the best solution
    {:ok, champion} = Bardo.ExperimentManager.get_best_solution(experiment_id)
    
    # Test the champion
    test_champion(champion)
    
    # Return the champion
    champion
  end
  
  @doc """
  Evaluates a genotype on the grid world navigation task.
  """
  def evaluate_navigation(genotype) do
    # World parameters
    grid_size = {10, 10}
    goal = {9, 9}
    max_steps = 50
    
    # Convert genotype to neural network
    nn = Bardo.AgentManager.Cortex.from_genotype(genotype, __MODULE__.Morphology)
    
    # Add sensors and actuators
    nn = Bardo.AgentManager.Cortex.add_sensor(nn, __MODULE__.PositionSensor)
    nn = Bardo.AgentManager.Cortex.add_sensor(nn, __MODULE__.GoalSensor)
    nn = Bardo.AgentManager.Cortex.add_actuator(nn, __MODULE__.MovementActuator)
    
    # Run simulation
    simulate_agent(nn, {0, 0}, goal, grid_size, max_steps)
  end
  
  @doc """
  Simulates an agent navigating the grid world.
  """
  def simulate_agent(nn, position, goal, grid_size, steps_left, path \\ []) do
    if position == goal do
      # Reached goal, calculate fitness based on path length
      path_length = length(path)
      optimal_length = abs(elem(goal, 0) - 0) + abs(elem(goal, 1) - 0)
      efficiency = optimal_length / path_length
      
      # Return fitness (1.0 for optimal path)
      1.0 * efficiency
    else
      if steps_left <= 0 do
        # Out of steps, calculate fitness based on distance to goal
        {x, y} = position
        {goal_x, goal_y} = goal
        distance = :math.sqrt(:math.pow(goal_x - x, 2) + :math.pow(goal_y - y, 2))
        max_distance = :math.sqrt(:math.pow(goal_x, 2) + :math.pow(goal_y, 2))
        
        # Return fitness (closer to goal is better)
        1.0 - (distance / max_distance)
      else
        # Sense environment
        sensor_data = %{
          position: position,
          goal: goal,
          grid_size: grid_size
        }
        
        # Get action from neural network
        action = activate_agent(nn, sensor_data)
        
        # Update position based on action
        new_position = update_position(position, action, grid_size)
        
        # Continue simulation
        simulate_agent(nn, new_position, goal, grid_size, steps_left - 1, [new_position | path])
      end
    end
  end
  
  @doc """
  Activates the agent's neural network to get an action.
  """
  def activate_agent(nn, sensor_data) do
    # Prepare input for position sensor
    position_input = %{
      position: sensor_data.position,
      grid_size: sensor_data.grid_size
    }
    
    # Prepare input for goal sensor
    goal_input = %{
      position: sensor_data.position,
      goal: sensor_data.goal,
      grid_size: sensor_data.grid_size
    }
    
    # Activate neural network
    Bardo.AgentManager.Cortex.activate(nn, %{
      position_sensor: position_input,
      goal_sensor: goal_input
    })
  end
  
  @doc """
  Updates the agent's position based on an action.
  """
  def update_position({x, y}, action, {width, height}) do
    case action do
      :up -> {x, max(0, y - 1)}
      :down -> {x, min(height - 1, y + 1)}
      :left -> {max(0, x - 1), y}
      :right -> {min(width - 1, x + 1), y}
    end
  end
  
  @doc """
  Tests a champion genotype on the grid world navigation task.
  """
  def test_champion(genotype) do
    # World parameters
    grid_size = {10, 10}
    goal = {9, 9}
    max_steps = 50
    
    # Convert genotype to neural network
    nn = Bardo.AgentManager.Cortex.from_genotype(genotype, __MODULE__.Morphology)
    
    # Add sensors and actuators
    nn = Bardo.AgentManager.Cortex.add_sensor(nn, __MODULE__.PositionSensor)
    nn = Bardo.AgentManager.Cortex.add_sensor(nn, __MODULE__.GoalSensor)
    nn = Bardo.AgentManager.Cortex.add_actuator(nn, __MODULE__.MovementActuator)
    
    # Run simulation with visualization
    visualize_agent(nn, {0, 0}, goal, grid_size, max_steps)
  end
  
  @doc """
  Visualizes an agent navigating the grid world.
  """
  def visualize_agent(nn, position, goal, grid_size, steps_left, path \\ []) do
    # Print grid
    IO.puts("\nGrid World Navigation:")
    print_grid(position, goal, grid_size)
    
    if position == goal do
      IO.puts("\nGoal reached in #{length(path)} steps!")
      path
    else
      if steps_left <= 0 do
        IO.puts("\nFailed to reach goal within step limit.")
        path
      else
        # Sense environment
        sensor_data = %{
          position: position,
          goal: goal,
          grid_size: grid_size
        }
        
        # Get action from neural network
        action = activate_agent(nn, sensor_data)
        
        # Update position based on action
        new_position = update_position(position, action, grid_size)
        IO.puts("Action: #{action}")
        
        # Continue simulation
        :timer.sleep(200)  # Slow down visualization
        visualize_agent(nn, new_position, goal, grid_size, steps_left - 1, [new_position | path])
      end
    end
  end
  
  @doc """
  Prints the grid world.
  """
  def print_grid(agent_pos, goal_pos, {width, height}) do
    for y <- 0..(height - 1) do
      line = for x <- 0..(width - 1) do
        cond do
          {x, y} == agent_pos -> "A"
          {x, y} == goal_pos -> "G"
          true -> "."
        end
      end
      IO.puts(Enum.join(line, " "))
    end
  end
  
  @doc """
  Waits for an experiment to complete.
  """
  def wait_for_completion(experiment_id, max_attempts \\ 100) do
    if max_attempts <= 0 do
      {:error, :timeout}
    else
      case Bardo.ExperimentManager.status(experiment_id) do
        {:complete, experiment} ->
          {:ok, experiment}
        
        {:in_progress, _} ->
          :timer.sleep(100)
          wait_for_completion(experiment_id, max_attempts - 1)
        
        other ->
          {:error, other}
      end
    end
  end
end
```

### 3.2 Running the Grid World Example

Run your grid world navigation example:

```elixir
iex> MyApp.GridWorld.run()
```

## 4. Saving and Loading Models

Once you've evolved a successful neural network, you'll want to save it for later use.

```elixir
defmodule MyApp.ModelManager do
  @moduledoc """
  Utilities for saving and loading evolved models.
  """
  
  @doc """
  Saves a champion genotype to file.
  """
  def save_champion(genotype, filename) do
    Bardo.Persistence.save(genotype, filename)
  end
  
  @doc """
  Loads a champion genotype from file.
  """
  def load_champion(filename) do
    Bardo.Persistence.load(filename)
  end
  
  @doc """
  Creates a neural network from a genotype file.
  """
  def create_network_from_file(filename, morphology \\ nil) do
    case load_champion(filename) do
      {:ok, genotype} ->
        nn = if morphology do
          Bardo.AgentManager.Cortex.from_genotype(genotype, morphology)
        else
          Bardo.AgentManager.Cortex.from_genotype(genotype)
        end
        
        {:ok, nn}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Runs inference with a saved model.
  """
  def run_inference(filename, input, morphology \\ nil) do
    case create_network_from_file(filename, morphology) do
      {:ok, nn} ->
        result = Bardo.AgentManager.Cortex.activate(nn, input)
        {:ok, result}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

## 5. Integration with Phoenix

If you're building a web application with Phoenix, you can use Bardo for tasks like recommendation systems or intelligent agents.

Here's a simple example of a Phoenix controller that uses a pre-trained Bardo model:

```elixir
defmodule MyAppWeb.RecommendationController do
  use MyAppWeb, :controller
  
  @model_path "priv/models/recommendation_model.gen"
  
  def index(conn, %{"user_id" => user_id}) do
    # Get user features
    user = MyApp.Accounts.get_user!(user_id)
    user_features = extract_user_features(user)
    
    # Get recommendations using Bardo model
    {:ok, recommendations} = get_recommendations(user_features)
    
    # Render recommendations
    render(conn, "index.html", recommendations: recommendations)
  end
  
  defp extract_user_features(user) do
    # Convert user data to neural network input
    # ...
    features
  end
  
  defp get_recommendations(user_features) do
    case MyApp.ModelManager.run_inference(@model_path, user_features) do
      {:ok, output} ->
        # Convert neural network output to product recommendations
        recommendations = convert_to_recommendations(output)
        {:ok, recommendations}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  defp convert_to_recommendations(neural_output) do
    # Convert neural network output to product IDs
    # ...
    recommendations
  end
end
```

## 6. Best Practices

When using Bardo in production applications, follow these best practices:

1. **Pre-train your models**: Don't run evolution in production. Pre-train your models and deploy only the inference code.

2. **Error handling**: Always handle errors from Bardo functions, especially when loading models or running inference.

3. **Input validation**: Validate and normalize inputs before passing them to neural networks.

4. **Resource management**: Be mindful of memory usage, especially with large neural networks.

5. **Monitoring**: Add monitoring to track model performance and inference time in production.

6. **Fallbacks**: Have fallback logic when neural networks fail or produce unexpected results.

7. **Version control**: Keep track of your model versions and their corresponding training data.

## 7. Advanced Topics

For more advanced usage of Bardo, consult the following resources:

- [API Reference](api_reference.md): Comprehensive API documentation
- [Advanced Features](advanced.md): Information on advanced features like substrate encoding
- [Examples](examples.md): More example implementations