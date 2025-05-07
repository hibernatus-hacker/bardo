# Bardo

![Bardo Logo](https://via.placeholder.com/150/0A0A0A/FFFFFF?text=Bardo)

Bardo is a powerful and approachable neuroevolution library for Elixir. It provides a complete toolkit for building, training and running neuroevolution systems that learn through evolutionary algorithms.

Built on a foundation of concurrent topology and parameter evolving neural networks (TWEANN), Bardo makes advanced neuroevolution techniques accessible while leveraging Elixir/OTP's built-in concurrency for highly efficient parallel training.

## Features

- **Topology and Parameter Evolving Neural Networks**: Evolve both the weights and structure of neural networks
- **Distributed and Concurrent**: Leverage the BEAM VM for parallel evolution and training
- **Sensor and Actuator Framework**: Easy integration with various environments
- **Ready-to-use Examples**: Including predator-prey simulations and control problems
- **Modular Design**: Easily extend with custom components and algorithms
- **Built-in Visualization**: Tools for monitoring evolutionary progress

## Installation

Add `bardo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bardo, "~> 0.1.0"}
  ]
end
```

Or install from GitHub:

```elixir
def deps do
  [
    {:bardo, github: "username/bardo"}
  ]
end
```

## Quick Start

### Running the Simple XOR Example

The simplest way to get started with Bardo is to run the XOR example, which demonstrates how to evolve a neural network to solve the XOR problem:

```bash
# Clone the repository
git clone https://github.com/username/bardo.git
cd bardo

# Install dependencies
mix deps.get

# Compile the project
mix compile

# Run the XOR example
mix run -e "Bardo.Examples.Simple.Xor.run()"
```

This will evolve a population of neural networks over multiple generations and display the best solution's performance on the XOR problem.

### Setting Up Your Own Experiment

Once you're familiar with the XOR example, you can set up your own experiment with the full framework:

```elixir
# Create a new experiment
experiment = Bardo.ExperimentManager.new_experiment("my_first_experiment")

# Configure the experiment
Bardo.ExperimentManager.configure(experiment, %{
  population_size: 50,
  max_generations: 100,
  mutation_rate: 0.3
})

# Start the experiment with a fitness function
Bardo.ExperimentManager.start(experiment, &MyApp.FitnessFunctions.xor_fitness/1)

# Check progress
Bardo.ExperimentManager.status(experiment)

# Get the best solution
best_neural_network = Bardo.ExperimentManager.get_best_solution(experiment)
```

### Development Status

The library has been updated to support running all examples. The simple XOR example is a good starting point, but the more complex examples (DPB, Flatland, FX, AlgoTrading) are now fully functional as well, providing more advanced neuroevolution scenarios.

## Examples

Bardo includes several example applications and benchmarks:

### 1. Simple XOR

A simple demonstration of evolving a neural network to solve the XOR problem. This is a great starting point as it doesn't require the full machinery of the population and experiment managers.

```elixir
# Run with default settings (population size: 100, generations: 50)
mix run -e "Bardo.Examples.Simple.Xor.run()"

# Run with custom settings
mix run -e "Bardo.Examples.Simple.Xor.run(population_size: 50, max_generations: 100)"

# Run with verbose output to see progress of evolution
mix run -e "Bardo.Examples.Simple.Xor.run(population_size: 50, max_generations: 100, verbose: true)"
```

The XOR example demonstrates several key concepts:

1. **Creating a population of neural networks**: Each with a slightly different genotype (neural structure and weights)
2. **Fitness function**: Evaluating how well each neural network solves the XOR problem
3. **Evolution process**: Selection of the best networks, mutation to create offspring
4. **Visualization**: Displaying the progress of evolution and final results

Here's a simplified view of what happens in the XOR example:

```elixir
# 1. Create initial population of random genotypes
initial_population = create_initial_population(population_size)

# 2. Evolve the population through many generations
{best_genotype, best_fitness, generations} = evolve(
  initial_population, 
  max_generations
)

# 3. Convert the best genotype to a neural network
best_neural_network = Cortex.from_genotype(best_genotype)

# 4. Test the best neural network on all XOR inputs
display_xor_results(best_neural_network)
```

This example provides a template for creating your own self-contained neuroevolution experiments.

### 2. Double Pole Balancing

A classic control problem where a neural network learns to balance two poles of different lengths on a cart.

```elixir
# Run the double pole balancing example with damping
# Parameters: experiment_id, population_size, generations, max_steps
iex -S mix
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 20, 10, 10000)

# For a longer run with more agents
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_example, 100, 50, 100000)

# Run without damping (more challenging)
iex> Bardo.Examples.Benchmarks.Dpb.run_without_damping(:dpb_wo_damping_example, 20, 10, 10000)
```

### 3. Flatland Predator-Prey Simulation

A more complex simulation where predator and prey agents co-evolve in a 2D world.

```elixir
# Run with small populations for quick testing
# Parameters: experiment_id, predator_population, prey_population, plant_quantity, simulation_steps, generations
iex -S mix
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example, 5, 5, 20, 500, 5)

# Run with default settings
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example)

# Run with custom settings for a more complex simulation
iex> Bardo.Examples.Applications.Flatland.run(:flatland_example, 20, 20, 40, 1000, 50)
```

### 4. Forex (FX) Trading

Evolves a trading strategy for foreign exchange markets using historical price data. This example demonstrates how neuroevolution can be applied to financial market forecasting and trading strategy development.

```elixir
# Run with small parameters for quick testing
# Parameters: experiment_id, population_size, data_window, generations
iex -S mix
iex> Bardo.Examples.Applications.Fx.run(:fx_example, 5, 500, 5)

# Run with default settings
iex> Bardo.Examples.Applications.Fx.run(:fx_example)

# Run with custom settings for a more thorough exploration
iex> Bardo.Examples.Applications.Fx.run(:fx_example, 50, 5000, 50)

# After running an experiment, you can test the best agent on out-of-sample data
iex> Bardo.Examples.Applications.Fx.test_best_agent(:fx_example)
```

The FX example:
- Uses EUR/USD forex historical data (located in priv/fx_tables/)
- Evolves neural networks that take price patterns as input and produce trading signals
- Evaluates agents based on trading performance metrics (profit/loss, win rate, drawdown)
- Provides a backtesting function to evaluate the best agent on out-of-sample data

When you run this example, you'll see detailed output including:
- Experiment configuration (population size, data window, generations)
- Progress indicators as the evolution runs
- Detailed test results showing trading metrics when you run test_best_agent

This example is particularly interesting for those interested in applying machine learning to financial markets, as it demonstrates how neuroevolution can discover non-linear patterns in time series data.

### 5. Algorithmic Trading

The newest and most comprehensive example that builds upon the FX Trading foundation to create a full-featured algorithmic trading system. This example provides more sophisticated market simulation, technical indicators, risk management, and broker interfaces.

```bash
# Run the algorithmic trading example with the mix task
mix run_algo_trading

# Run with specific market and timeframe
mix run_algo_trading --market forex --symbol GBPUSD --timeframe 60

# Run with optimization parameters
mix run_algo_trading --generations 200 --population 150

# Run with backtesting options
mix run_algo_trading --test-period last_month
```

You can also run the example directly from IEx:

```elixir
# Start interactive Elixir shell
iex -S mix

# Run with default settings
iex> Bardo.Examples.Applications.AlgoTrading.run(:algo_trading_example)

# Run with custom settings
iex> Bardo.Examples.Applications.AlgoTrading.run(:algo_trading_example, %{
  market: :forex,
  symbol: "EURUSD",
  timeframe: 15,
  population_size: 100,
  generations: 100
})

# Test the best agent on out-of-sample data
iex> Bardo.Examples.Applications.AlgoTrading.test_best_agent(:algo_trading_example)

# Connect to live trading (requires broker setup)
iex> Bardo.Examples.Applications.AlgoTrading.live_trading(:algo_trading_example, :metatrader, %{
  account_id: "12345678",
  risk_per_trade: 1.0
})
```

The Algorithmic Trading example offers:

- **Advanced Features**:
  - Comprehensive technical indicators (Moving Averages, RSI, MACD, Bollinger Bands, etc.)
  - Sophisticated market simulation with realistic slippage and spread
  - Risk management including position sizing and stop-loss/take-profit
  - Performance metrics calculation (Sharpe ratio, drawdown, profit factor)
  - Detailed backtesting on different historical periods
  - External broker interfaces for live trading

- **Key Components**:
  - Market simulators for different assets (forex, crypto)
  - Broker interfaces for popular trading platforms
  - Advanced sensors for market data and technical analysis
  - Multi-output actuators for trade direction and risk management
  - Detailed performance visualization and reporting

This example is ideal for those interested in applying neuroevolution to financial markets and algorithmic trading systems. It demonstrates how neural networks can learn complex trading strategies through evolutionary optimization.

See the [examples documentation](docs/examples.md) for more details on these examples, their configurations, and what to expect when running them.

### Troubleshooting Common Issues

When running the examples, you might encounter some issues:

1. **Compilation Warnings**: There may be some warnings about unused variables or aliases during compilation. These don't affect functionality and have mostly been addressed.

2. **Example Complexity**: The examples vary in complexity:
   - XOR: Simple and stable, good starting point
   - FX and Flatland: More complex but now have enhanced user experience
   - AlgoTrading: Most sophisticated example with many components
   - DPB: Most computationally intensive, requires more resources

3. **Use the New Mix Tasks**: For the best experience with complex examples, use the dedicated mix tasks which provide:
   - Interactive parameter selection
   - Real-time progress tracking
   - Better error handling and visualization

4. **Start with Small Parameters**: The examples can be resource-intensive with large populations or many generations. Start with the small parameter sets provided and increase them gradually.

5. **Memory Usage**: For very long runs, be aware of memory usage, as the system stores information about all agents throughout evolution.

6. **Interactive Output**: All examples now provide interactive output at each stage:
   - Initial configuration display
   - Real-time progress tracking with percentage
   - Completion summary with results
   - Automatic visualization/testing when available

7. **Mock Data for Demonstrations**: If an example doesn't have real data available (e.g., if an experiment didn't complete), it will automatically use mock data for visualization to demonstrate how the system works.

**Note on Complex Examples**: 
- All examples are now fully functional with enhanced user feedback and visualization.
- They showcase different aspects of the neuroevolution framework:
  - XOR: Simple pattern recognition
  - DPB: Control problem with continuous state and action spaces
  - Flatland: Multi-agent co-evolution in a 2D environment
  - FX: Time series prediction and decision making
  - AlgoTrading: Sophisticated financial system with extensive components

The **recommended way** to run these complex examples is using the dedicated mix tasks:

```bash
# Interactive menu to choose example and parameters
mix run_complex_examples

# Run specific examples directly
mix run_complex_examples --example flatland
mix run_complex_examples --example fx

# Run the algorithmic trading example
mix run_algo_trading

# Customize parameters
mix run_complex_examples --example flatland --size 5 --generations 10
mix run_algo_trading --market crypto --symbol BTCUSD --timeframe 60
```

This provides:
- Real-time progress tracking during evolution
- Automatic visualization/testing after completion
- Better error handling and feedback
- Mock data for demonstration when needed

You can also run examples with reduced parameters in iex to verify functionality:

```elixir
# Quick test runs (will complete in minutes)
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_test, 5, 3, 1000)
iex> Bardo.Examples.Applications.Flatland.run(:flatland_test, 5, 5, 10, 100, 3)
iex> Bardo.Examples.Applications.Fx.run(:fx_test, 5, 500, 3)
iex> Bardo.Examples.Applications.AlgoTrading.run(:algo_test, %{population_size: 5, generations: 3})

# Test the evolved agents
iex> Bardo.Examples.Benchmarks.Dpb.test_best_solution(:dpb_test)
iex> Bardo.Examples.Applications.Flatland.visualize(:flatland_test)
iex> Bardo.Examples.Applications.Fx.test_best_agent(:fx_test)
iex> Bardo.Examples.Applications.AlgoTrading.test_best_agent(:algo_test)
```

### Running Examples with Mix Tasks

The project includes Mix tasks to run the examples, which is the recommended way to run code in a Mix project:

1. **run_xor**: Runs just the XOR example, which is the most stable and self-contained example.

   ```bash
   # Run with default settings
   mix run_xor
   
   # Run with custom settings
   mix run_xor --size 50 --generations 20
   
   # Run without progress output
   mix run_xor --quiet
   ```

2. **run_examples**: Attempts to run all available examples and benchmarks with small parameters.

   ```bash
   # Run all available examples
   mix run_examples
   
   # Run only the XOR example
   mix run_examples --xor-only
   ```

3. **run_complex_examples**: Runs the complex examples with enhanced user experience, including real-time progress tracking and visualization.

   ```bash
   # Run interactive menu to select an example
   mix run_complex_examples
   
   # Run specific example directly
   mix run_complex_examples --example flatland
   mix run_complex_examples --example fx
   
   # Run with custom parameters
   mix run_complex_examples --example flatland --generations 10 --size 5
   mix run_complex_examples --example fx --size 20 --generations 15
   
   # Run without visualization step
   mix run_complex_examples --example fx --no-visualize
   ```

4. **run_algo_trading**: Runs the algorithmic trading example with various configuration options.

   ```bash
   # Run with default settings (EURUSD/15m)
   mix run_algo_trading
   
   # Run with specific market and timeframe
   mix run_algo_trading --market forex --symbol GBPUSD --timeframe 60
   
   # Run with optimization parameters
   mix run_algo_trading --generations 200 --population 150
   
   # Run with backtesting options
   mix run_algo_trading --test-period last_month
   ```

These Mix tasks:
- Properly load the application and all its modules
- Check if examples are available before running them
- Handle dependencies between examples
- Provide detailed error reporting and visual progress tracking
- Summarize which examples succeeded and failed
- Automatically run visualization/testing after completion

### Running Examples in IEx

You can also run the examples directly in an interactive Elixir shell:

```bash
# Start an interactive shell
$ iex -S mix

# Run the XOR example
iex> Bardo.Examples.Simple.Xor.run(population_size: 20, max_generations: 10)

# Run a benchmark example
iex> Bardo.Examples.Benchmarks.Dpb.run_with_damping(:dpb_test, 5, 3, 1000)

# Run an application example
iex> Bardo.Examples.Applications.Flatland.run(:flatland_test, 5, 5, 10, 100, 3)

# Run the algorithmic trading example
iex> Bardo.Examples.Applications.AlgoTrading.run(:algo_test, %{market: :forex, timeframe: 15})
```

This approach gives you the most flexibility and allows you to interact with the results.

### Key Implementation Modules

The following modules have been implemented or enhanced to enable the complex examples:

1. **Bardo.PolisMgr**: A facade for the Polis.Manager module, providing a simplified interface for setting up and running experiments.

2. **Bardo.PopulationManager.ExtendedMorphology**: A behavior that extends the basic Morphology behavior with additional callbacks needed for complex examples.

3. **Bardo.Models**: Extended with additional functions for data persistence, including `read/2`, `write/3`, `delete/2`, and `exists?/2`.

4. **Bardo.DB**: Enhanced with a `backup/0` function to support experiment persistence.

5. **Example-specific modules**: Each example (DPB, Flatland, FX, AlgoTrading) has dedicated sensor, actuator, and morphology modules that implement the required behaviors.

## Core Concepts

Bardo is built around these key components:

### Genotype

The genetic representation of a neural network, used for evolution and mutation.

```elixir
# Create a new genotype
genotype = Bardo.PopulationManager.Genotype.new()

# Add a new neuron
genotype = Bardo.PopulationManager.Genotype.add_neuron(genotype, :hidden)

# Mutate the genotype
mutated_genotype = Bardo.PopulationManager.GenomeMutator.mutate(genotype)
```

### Phenotype (Neural Network)

The functional neural network created from a genotype.

```elixir
# Create a neural network from a genotype
nn = Bardo.AgentManager.Cortex.from_genotype(genotype)

# Activate the neural network with inputs
output = Bardo.AgentManager.Cortex.activate(nn, [1.0, 0.0])
```

### Sensors and Actuators

Interface between neural networks and their environment.

```elixir
# Add a sensor to a neural network
nn = Bardo.AgentManager.Cortex.add_sensor(nn, MyApp.Sensors.Vision)

# Add an actuator to a neural network
nn = Bardo.AgentManager.Cortex.add_actuator(nn, MyApp.Actuators.Motor)
```

## Architecture

Bardo is organized into several key managers:

- **ExperimentManager**: Controls the overall experiment process
- **PopulationManager**: Handles populations of evolving agents
- **AgentManager**: Manages the neural networks and their interactions
- **ScapeManager**: Provides environments for agents to operate in

## Advanced Usage

See our [advanced guide](docs/advanced.md) for topics including:

- Custom fitness functions
- Specialized sensor and actuator development  
- Distributed training across multiple nodes
- Custom mutation operators

## Testing

Bardo includes both ExUnit tests and example applications for validation:

```bash
# Run the unit tests
mix test

# Run specific tests
mix test test/bardo/population_manager/genotype_test.exs

# Run the XOR example (functional test)
mix run -e "Bardo.Examples.Simple.Xor.run(verbose: true)"
```

The XOR example can be used to verify that the core components of the library are working correctly, as it demonstrates a complete neuroevolution process from initialization to evaluation.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

When contributing, please:

- Add tests for new features
- Ensure all tests pass
- Update documentation as needed
- Follow existing code style and patterns

## License

Distributed under the MIT License. See `LICENSE` for more information.

## Acknowledgements

- Based on concepts from the [Handbook of Neuroevolution Through Erlang](http://www.amazon.com/Handbook-Neuroevolution-Through-Erlang-Gene/dp/1461444624) by Gene Sher
- Inspired by DXNN and other TWEANN systems