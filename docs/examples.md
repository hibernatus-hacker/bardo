# Bardo Examples

This document provides detailed information on the example applications and benchmarks included with Bardo.

## Benchmarks

### Double Pole Balancing (DPB)

A classic control problem where a neural network learns to balance two poles of different lengths on a cart.

#### Overview

In this problem, we try to balance two poles of different lengths simultaneously on a cart. The cart can move left and right along a track, and the neural network must apply the correct forces to keep both poles balanced.

- One pole is 0.1 meters long
- The other pole is 1.0 meter long 
- The closer the lengths of the two poles are, the more difficult the problem becomes

#### Running the Example

```elixir
# Run with default settings
Bardo.Examples.Benchmarks.Dpb.run()

# Run with custom settings
Bardo.Examples.Benchmarks.Dpb.run(%{
  population_size: 100,
  max_generations: 200,
  use_damping: true  # Enables damping to discourage rapid cart movements
})
```

#### What to Expect

- With standard settings, a solution typically emerges after ~2,300 evaluations
- The neural network learns to make small, precise movements to balance both poles
- You can observe the evolution progress through the console output or visualizations

#### Implementation Details

The DPB example provides two variants:
- Without damping: Allows fast cart movements as long as poles stay balanced
- With damping: Penalizes high velocity and rapid changes, encouraging smoother control

The neural network receives these inputs:
- Cart position and velocity 
- First pole angle and angular velocity
- Second pole angle and angular velocity

It produces a single output:
- Force value (in Newtons) to apply to the cart, saturated at 10N magnitude

## Applications

### Flatland (Predator vs Prey Simulation)

A more complex simulation where predator and prey agents co-evolve in a 2D world.

#### Overview

Flatland creates a simulated 2D environment where:
- Predator agents (red) try to catch and consume prey agents (blue)
- Prey agents try to survive by avoiding predators and consuming plants (green)
- Both species evolve more sophisticated strategies over time

This example demonstrates:
- Co-evolution of competing species
- Complex emergent behaviors
- Steady-state evolution (ongoing birth and death rather than distinct generations)

#### Running the Example

```elixir
# Run with default settings
Bardo.Examples.Applications.Flatland.run()

# Run with custom settings
Bardo.Examples.Applications.Flatland.run(%{
  predator_population_size: 10,
  prey_population_size: 20,
  plant_quantity: 40,
  max_evaluations: 10000
})
```

#### What to Expect

You'll observe fascinating co-evolutionary dynamics:
- Initially random behavior becomes increasingly strategic
- Predators may evolve trapping or ambush tactics
- Prey develop evasion strategies and efficient foraging
- The population dynamics reach different equilibria depending on which species evolves effective strategies first

#### Implementation Details

Each agent has:
- Distance scanners (sensors that detect objects at different angles)
- Color scanners (sensors that identify object types by color)
- Two-wheel drive actuators (for movement control)

The evolutionary progress can be tracked through:
- Average fitness over time
- Neural network complexity
- Population diversity
- Population turnover (death rates)

## Custom Example Development

To create your own example using Bardo:

1. Define your environment and interaction rules
2. Create custom sensors and actuators
3. Set up the evolution parameters
4. Configure fitness functions

See the [advanced guide](advanced.md) for detailed instructions on developing custom examples.