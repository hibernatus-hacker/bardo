# Simple Examples

This directory contains simple examples that demonstrate the basic capabilities of the Bardo framework.

## XOR Example

The XOR example is the classic "Hello World" of neural networks. It demonstrates how to evolve a neural network that can learn the XOR function:

| Input 1 | Input 2 | Output |
|---------|---------|--------|
| 0       | 0       | 0      |
| 0       | 1       | 1      |
| 1       | 0       | 1      |
| 1       | 1       | 0      |

### Running the XOR Example

You can run the XOR example in several ways:

#### Using the Mix Task

```bash
# Run with default parameters
mix run_xor

# Run with custom parameters
mix run_xor --size 100 --generations 50 --runs 3
```

#### From IEx

```elixir
# Run with default parameters
Bardo.Examples.Simple.Xor.run()

# Run with custom parameters
Bardo.Examples.Simple.Xor.run(
  population_size: 100,
  max_generations: 50,
  show_progress: true,
  verbose: true
)
```

### How It Works

The XOR example demonstrates:

1. **Creating an initial population** - Random neural networks are generated
2. **Evaluating fitness** - Each network is tested on the XOR problem
3. **Selection and reproduction** - The best networks are selected and mutated
4. **Evolution** - The process continues until a solution is found or max generations is reached

### Key Learning Points

- Basic principles of neuroevolution
- Setting up a fitness function
- Population management and selection
- Mutation strategies

### Implementation Details

The implementation in `xor.ex` includes:

- A simple fitness function based on error minimization
- Tournament selection for choosing parents
- Mutation operators to adjust weights and add neurons/connections
- Visual output of the evolved network's performance

### What to Try Next

After understanding the XOR example, try:

1. Modifying the mutation rates to see how it affects evolution speed
2. Changing the selection method to see effects on diversity
3. Moving to the more complex DPB (Double Pole Balancing) benchmark