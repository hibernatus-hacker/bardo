# Bardo Release Notes

## Version 0.1.0

This is the initial release of Bardo, a focused neuroevolution library for Elixir.

### Key Features

- **Topology and Parameter Evolving Neural Networks (TWEANN)**: Bardo evolves both the structure and weights of neural networks over time.
- **Efficient ETS-based Storage**: Simple and fast in-memory storage with periodic backups.
- **Modular Sensor/Actuator Framework**: Easily connect networks to different environments.
- **Built-in Evolutionary Algorithms**: Includes selection algorithms and mutation operators.
- **Substrate Encoding**: Hypercube-based encoding for efficient pattern recognition.
- **Example Environments**:
  - XOR: Simple logical problem
  - Double Pole Balancing: Classic control benchmark
  - Flatland: Predator-prey simulation
  - FX: Basic forex trading simulation

### Changes in This Release

- Initial public release with Apache License 2.0
- Removed experimental HTM (Hierarchical Temporal Memory) implementation
- Updated documentation for hex.pm publication
- Full test coverage across core functionality

### Known Issues

- There are some compiler warnings that need to be addressed in future releases
- Some API functions need better documentation
- Certain modules implement behaviours incorrectly (especially in example code)

### Future Roadmap

- Improve documentation and examples
- Reduce compiler warnings
- Add more comprehensive API reference
- Create additional demo applications
- Implement distributed training support across multiple Erlang nodes
- Improve performance for large-scale simulations