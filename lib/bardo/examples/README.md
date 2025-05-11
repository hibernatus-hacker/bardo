# Bardo Examples

This directory contains examples demonstrating the capabilities of the Bardo neuroevolution framework. These examples range from simple XOR solvers to complex applications like algorithmic trading and multi-agent systems.

## Example Categories

The examples are organized into three main categories:

### 1. Simple Examples (`simple/`)

Basic examples for learning the core concepts of Bardo:

- **XOR**: A classic neural network learning problem - learn the XOR logic function. Serves as a good starting point for understanding neuroevolution.
  - Run with: `mix run_xor` or `Bardo.Examples.Simple.Xor.run()`

### 2. Benchmarks (`benchmarks/`)

Standard benchmark problems for evaluating and comparing neuroevolution performance:

- **Double Pole Balancing (DPB)**: Balance one or two poles on a cart by applying forces to the cart. Available in two versions:
  - With damping: `Bardo.Examples.Benchmarks.Dpb.run_with_damping/4`
  - Without damping: `Bardo.Examples.Benchmarks.Dpb.run_without_damping/4`

### 3. Applications (`applications/`)

Real-world applications showcasing Bardo's capabilities in more complex domains:

- **Flatland**: A predator-prey simulation where agents evolve in a 2D environment.
  - Run with: `Bardo.Examples.Applications.Flatland.run/6`

- **Forex Trading (FX)**: A simple forex trading simulation demonstrating how to evolve trading strategies.
  - Run with: `Bardo.Examples.Applications.Fx.run/4`

- **Algorithmic Trading**: A more sophisticated trading framework with support for multiple brokers and data sources.
  - See the [Algorithmic Trading README](applications/algo_trading/README.md) for details
  - Run examples with: `mix run_algo_trading`

## Running Examples

You can run examples in several ways:

### Using Mix Tasks

The simplest way to run examples is using the provided mix tasks:

```bash
# Run all examples with small parameters
mix run_examples

# Run only the XOR example
mix run_examples --xor-only

# Run the XOR example with custom parameters
mix run_xor --size 100 --generations 50 --runs 5

# Run the algorithmic trading examples
mix run_algo_trading
```

### Using IEx

For more control, you can run examples directly in IEx:

```elixir
# Start IEx
iex -S mix

# Run XOR example
Bardo.Examples.Simple.Xor.run(population_size: 100, max_generations: 50)

# Run Double Pole Balancing benchmark
Bardo.Examples.Benchmarks.Dpb.run_with_damping(:my_experiment, 10, 5, 1000)

# Run Flatland simulation
Bardo.Examples.Applications.Flatland.run(:flatland_experiment, 10, 10, 20, 100, 5)
```

## Helper Modules

The `ExamplesHelper` module provides utilities for running more complex examples:

```elixir
alias Bardo.Examples.ExamplesHelper

# Run an experiment with progress tracking
ExamplesHelper.run_experiment(my_config, timeout: 300_000, update_interval: 5_000)
```

## Creating Your Own Examples

To create your own examples, follow these patterns:

1. For simple examples, create a module under `Bardo.Examples.Simple`
2. For benchmarks, create a module under `Bardo.Examples.Benchmarks`
3. For applications, create a module under `Bardo.Examples.Applications`

Your module should include:
- A `run` function or similar entry point
- Documentation explaining the example
- Parameter validations and error handling
- Progress reporting for long-running examples

## Recommended Learning Path

If you're new to Bardo, we recommend:

1. Start with the XOR example to understand basic neuroevolution
2. Move to the Double Pole Balancing benchmark to see more complex fitness functions
3. Explore the Flatland simulation to understand multi-agent systems
4. Study the trading examples to see real-world applications

## Documentation

For more detailed information about each example, refer to:

- [Bardo Documentation](../../docs/)
- [API Reference](../../docs/api_reference.md)
- [Quickstart Guide](../../docs/quickstart.md)