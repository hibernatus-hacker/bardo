# Benchmark Examples

This directory contains benchmark examples used to evaluate and compare the performance of neuroevolution algorithms in Bardo.

## Double Pole Balancing (DPB)

The Double Pole Balancing problem is a standard benchmark in the field of neuroevolution. It involves balancing two poles of different lengths attached to a cart that moves along a track. The agent must apply forces to the cart to keep the poles balanced.

![Double Pole Balancing](https://upload.wikimedia.org/wikipedia/commons/thumb/c/c9/Cart-pole_system.svg/400px-Cart-pole_system.svg.png)

### Variants

Two variants of the DPB benchmark are implemented:

1. **With Damping** - This version includes friction, making it easier to solve
2. **Without Damping** - This version has no friction, making it more challenging

### Running the DPB Benchmark

#### Using the Mix Task

```bash
# Run all examples including DPB
mix run_examples

# Run with the refactored runner
mix run_examples_refactored --example dpb
```

#### From IEx

```elixir
# Run with damping (easier)
Bardo.Examples.Benchmarks.Dpb.run_with_damping(
  :my_experiment_id,  # Experiment ID
  10,                 # Populations
  5,                  # Iterations per population
  500                 # Maximum simulation time
)

# Run without damping (harder)
Bardo.Examples.Benchmarks.Dpb.run_without_damping(
  :my_experiment_id,  # Experiment ID
  10,                 # Populations
  5,                  # Iterations per population
  500                 # Maximum simulation time
)

# Test the best solution
Bardo.Examples.Benchmarks.Dpb.test_best_solution(:my_experiment_id)
```

### How It Works

The DPB benchmark demonstrates:

1. **Physics simulation** - The system models the physics of cart-pole systems
2. **Fitness evaluation** - Networks are evaluated based on how long they keep the poles balanced
3. **Sensor and actuator design** - Shows how to design appropriate inputs and outputs for control problems
4. **Progressive learning** - Demonstrates how solutions evolve from simple to complex behaviors

### Implementation Details

The implementation in the `dpb/` directory includes:

- Specialized sensor and actuator modules tailored for the DPB problem
- Physics-based simulation of the cart-pole system
- Multiple difficulty levels to evaluate algorithm performance
- Visualization and playback of the best solutions

### Key Learning Points

- How to design fitness functions for control problems
- Encoding physical systems for neural network control
- Testing and validating evolved solutions
- Comparing algorithm performance across difficulty levels

### What to Try Next

After understanding the DPB benchmark, try:

1. Modifying the pole lengths or masses to change the difficulty
2. Adjusting the mutation rates to see how it affects solution quality
3. Trying different neural network architectures
4. Moving to the more complex application examples like Flatland