# Bardo Test Suite

This directory contains tests for the Bardo neuroevolution framework. The tests are organized by module and cover all core components of the system.

## Running Tests

To run the tests, you need to have all dependencies installed:

```
mix deps.get
```

Then you can run the entire test suite with:

```
mix test
```

Or run specific tests with:

```
mix test test/path/to/test_file.exs
```

## Test Organization

Tests are organized to match the structure of the application code:

- `/test/bardo/` - Tests for core modules in `/lib/bardo/`
- `/test/bardo/agent_manager/` - Tests for the AgentManager subsystem
- `/test/bardo/experiment_manager/` - Tests for the ExperimentManager subsystem
- `/test/bardo/population_manager/` - Tests for the PopulationManager subsystem
- `/test/bardo/scape_manager/` - Tests for the ScapeManager subsystem

## Key Test Files

### Core Components

- `morphology_test.exs` - Tests for the Morphology module
- `persistence_test.exs` - Tests for the Persistence module
- `supervisor_test.exs` - Tests for the supervision tree structure
- `models_test.exs` - Tests for the Models module

### Agent Manager

- `agent_manager_client_test.exs` - Tests for the AgentManager client
- `agent_worker_test.exs` - Tests for individual agent workers
- `cortex_test.exs` - Tests for the neural network cortex
- `neuron_test.exs` - Tests for neuron functionality
- `substrate_test.exs` - Tests for the substrate encoding

### Experiment Manager

- `experiment_manager_test.exs` - Tests for experiment lifecycle management
- `experiment_manager_client_test.exs` - Tests for the ExperimentManager client

### Population Manager

- `genome_mutator_test.exs` - Tests for genome mutation
- `genotype_test.exs` - Tests for genotype representation
- `morphology_test.exs` - Tests for population-specific morphology
- `population_manager_client_test.exs` - Tests for the PopulationManager client
- `selection_algorithm_test.exs` - Tests for selection algorithms

## Test Configuration

Tests use a separate configuration defined in `/config/test.exs`. This includes:

- An in-memory database for faster tests
- Reduced verbosity for cleaner test output
- Mock implementations of certain components for isolated testing

## Test Helpers

Helper modules for testing are in `/test/test_helper/`:

- `mocks.ex` - Mock implementations for testing
- `model_helper.ex` - Helper functions for working with model data structures

## Coverage

Test coverage can be generated with:

```
mix coveralls
```

Or for HTML output:

```
mix coveralls.html
```

## Notes for Contributors

When adding new functionality:

1. Always add corresponding tests
2. Try to keep tests isolated and independent
3. Use helpers and mocks to avoid testing external dependencies
4. For database tests, always clean up after the test
5. Keep tests fast whenever possible