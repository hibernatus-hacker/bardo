# Flatland Tutorial: Predator-Prey Co-evolution

This tutorial will walk you through setting up and running the Flatland simulation, one of the most fascinating examples included with Bardo. In this simulation, predator and prey agents co-evolve in a 2D world, developing increasingly sophisticated survival strategies.

## Overview

The Flatland simulation creates a 2D environment with:

- **Predators**: Red agents that hunt and consume prey
- **Prey**: Blue agents that try to avoid predators while eating plants
- **Plants**: Green resources that provide energy to prey

What makes this simulation particularly interesting is that both predator and prey agents are controlled by neural networks that evolve over time through natural selection.

## Running the Basic Simulation

### Step 1: Start an Elixir session

First, open an interactive Elixir session:

```bash
cd /path/to/bardo
iex -S mix
```

### Step 2: Run the default Flatland simulation

```elixir
iex> Bardo.Examples.Applications.Flatland.run()
```

This will start the simulation with default parameters. You'll see output describing the initialization process, followed by periodic updates on the evolutionary progress.

## Customizing the Simulation

You can customize the simulation with different parameters:

```elixir
iex> Bardo.Examples.Applications.Flatland.run(%{
  predator_population_size: 15,  # Default: 10
  prey_population_size: 30,      # Default: 20
  plant_quantity: 50,            # Default: 40
  world_size: {1200, 1200},      # Default: {1000, 1000}
  max_generations: 200,          # Default: 100
  steady_state: true,            # Use steady-state evolution (ongoing births/deaths)
  visualization: true            # Enable visualization (if available)
})
```

## Understanding the Agents

### Prey Agents

Prey agents are equipped with:

1. **Distance sensors**: Detect objects at different angles from the agent
2. **Color sensors**: Identify what type of object is detected (predator, prey, or plant)
3. **Two-wheel actuators**: Control movement direction and speed

Their neural networks evolve to accomplish these goals:
- Avoid predators
- Find and consume plants
- Manage energy efficiently

### Predator Agents

Predator agents have similar sensory and motor capabilities:

1. **Distance sensors**: Detect objects at different angles
2. **Color sensors**: Identify prey and distinguish from other predators
3. **Two-wheel actuators**: Control movement

Their neural networks evolve to:
- Track and catch prey
- Develop hunting strategies
- Manage energy efficiently

## Analyzing the Results

As the simulation runs, you'll observe several metrics:

### 1. Fitness Scores

```elixir
iex> Bardo.Examples.Applications.Flatland.plot_fitness("experiment_id")
```

This shows how average fitness for both species changes over time. Typically:
- Initially, scores are low as agents move randomly
- As agents learn to find food, scores increase
- When predators learn to hunt, prey fitness drops while predator fitness rises
- Eventually, an arms race develops as prey evolve evasion tactics

### 2. Neural Network Complexity

```elixir
iex> Bardo.Examples.Applications.Flatland.plot_complexity("experiment_id")
```

This shows how neural network size changes over time:
- Networks typically grow more complex as they evolve more sophisticated behaviors
- Predators and prey often develop different levels of complexity

### 3. Population Diversity

```elixir
iex> Bardo.Examples.Applications.Flatland.plot_diversity("experiment_id")
```

This shows genetic diversity within each population:
- Higher diversity means more exploration of possible solutions
- Lower diversity indicates convergence on successful strategies

### 4. Population Turnover

```elixir
iex> Bardo.Examples.Applications.Flatland.plot_turnover("experiment_id")
```

This shows death rates for each species:
- Higher prey turnover indicates successful predator hunting
- Lower predator turnover indicates successful feeding

## Interesting Behaviors to Watch For

As the simulation runs, several fascinating emergent behaviors may develop:

1. **Predator Ambush Tactics**: Predators may learn to wait near plant concentrations to ambush prey
2. **Prey Grouping**: Prey may develop swarming behaviors for protection
3. **Resource Management**: Both species tend to develop energy-efficient movement patterns
4. **Pattern Recognition**: Agents may learn to predict the behavior of other agents

## Extending the Simulation

You can extend the Flatland simulation in several ways:

### 1. Customizing Sensor Configurations

```elixir
# Create a custom sensor configuration
sensor_config = %{
  num_distance_sensors: 8,      # Default: 6
  sensor_range: 200,            # Default: 150
  sensor_resolution: "high"     # Default: "medium"
}

# Run with custom sensors
Bardo.Examples.Applications.Flatland.run(%{sensor_config: sensor_config})
```

### 2. Adding Environmental Features

You can modify the `Flatland` module to add features like:
- Obstacles
- Resource-rich regions
- Environmental hazards
- Seasonal changes

### 3. Creating Custom Agents

You can define new types of agents by creating modules that implement the sensor and actuator behaviors.

## Conclusion

The Flatland simulation demonstrates the power of neuroevolution to produce complex, adaptive behaviors through a process similar to natural selection. As you run the simulation, you'll observe the fascinating co-evolution of predator and prey species, each developing increasingly sophisticated strategies in response to the other.

For more details on the implementation, explore the following files:
- `lib/bardo/examples/applications/flatland.ex`
- `lib/bardo/examples/applications/flatland/flatland_sensor.ex`
- `lib/bardo/examples/applications/flatland/flatland_actuator.ex`