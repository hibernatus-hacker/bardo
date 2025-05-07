# Bardo Testing Guide

This document provides comprehensive guidance for testing the Bardo neuroevolution framework, including best practices, patterns, and recommendations for writing effective tests.

## Testing Philosophy

The Bardo testing approach follows these key principles:

1. **Comprehensive Coverage**: Tests should cover all core components and critical paths
2. **Isolation**: Tests should be isolated from each other and external dependencies
3. **Realism**: Tests should mirror real-world usage as much as possible
4. **Maintainability**: Tests should be easy to understand, modify, and extend

## Test Organization

Tests are organized to match the structure of the application code:

```
test/
├── bardo/
│   ├── agent_manager/        # Tests for AgentManager subsystem
│   ├── experiment_manager/   # Tests for ExperimentManager subsystem
│   ├── population_manager/   # Tests for PopulationManager subsystem
│   ├── scape_manager/        # Tests for ScapeManager subsystem
│   └── examples/             # Tests for example applications
├── support/                  # Test support modules
│   ├── test_substrate.ex     # Mock implementation of Substrate
│   ├── test_neuron.ex        # Mock implementation of Neuron
│   ├── mock_helper.ex        # Helper module for mocking
│   └── ...
├── test_helper/
│   ├── mocks.ex              # General mocking helpers
│   └── model_helper.ex       # Helpers for working with models
└── test_helper.exs           # Test initialization
```

## Writing Effective Tests

### General Guidelines

1. **Test What Matters**: Focus on testing behavior, not implementation details
2. **One Assertion Per Test**: Keep tests focused on a single behavior
3. **Descriptive Test Names**: Name tests clearly to describe behavior being tested
4. **Arrange-Act-Assert Pattern**: Structure tests with clear setup, action, and verification
5. **Clean Setup and Teardown**: Ensure tests clean up after themselves

### Testing GenServers and OTP Components

For testing GenServers and other OTP components:

1. **Isolate Process Tests**: Test process behavior in isolation
2. **Mock Dependencies**: Use MockHelper to mock external dependencies
3. **Test Process Lifecycles**: Test the full lifecycle (start, interact, stop)
4. **Verify Messages**: Test that processes send and receive the correct messages
5. **Test Error Handling**: Verify that processes handle errors correctly

Example:
```elixir
test "process sends correct message" do
  # Start the process
  {:ok, pid} = MyProcess.start_link([])
  
  # Set up test process to receive messages
  Process.register(self(), :test_receiver)
  
  # Trigger behavior
  MyProcess.do_something(pid)
  
  # Verify message was received
  assert_received {:action_completed, result}
  assert result == :expected_value
end
```

### Testing Neural Network Components

For testing neural network components:

1. **Test Network Construction**: Verify networks are constructed correctly
2. **Test Signal Propagation**: Verify signals propagate through networks correctly
3. **Test Learning Rules**: Verify learning rules update networks correctly
4. **Use Simple Test Cases**: Use simple test cases with known outcomes
5. **Test Edge Cases**: Test boundary conditions and special cases

Example:
```elixir
test "neuron processes input correctly" do
  # Create a test neuron
  {:ok, pid} = Neuron.start_link(node(), :exo_pid)
  
  # Initialize the neuron
  Neuron.init_phase2(pid, :exo_pid, :id, :cortex_pid, :sigmoid, [], [:from_pid])
  
  # Mock dependent modules
  MockHelper.override_function(Cortex, :forward, fn(_, _, output) ->
    assert output == [0.5]  # Expected output after sigmoid
    :ok
  end)
  
  # Send input to the neuron
  Neuron.forward(pid, :from_pid, [0.0])  # Should produce 0.5 after sigmoid
end
```

### Testing Evolutionary Algorithms

For testing evolutionary algorithms:

1. **Test Selection Algorithms**: Verify selection algorithms select correctly
2. **Test Mutation Operators**: Verify mutation operators modify genomes correctly
3. **Test Crossover Operators**: Verify crossover operators combine genomes correctly
4. **Test Fitness Functions**: Verify fitness functions evaluate correctly
5. **Test Population Dynamics**: Verify populations evolve correctly

Example:
```elixir
test "tournament selection selects fitter individuals" do
  # Create a test population
  population = [
    %{id: 1, fitness: 0.1},
    %{id: 2, fitness: 0.5},
    %{id: 3, fitness: 0.9}
  ]
  
  # Run tournament selection
  selected = TournamentSelection.select(population, 2, 10)
  
  # Verify selection favors fitter individuals
  selected_ids = Enum.map(selected, & &1.id)
  # ID 3 should appear more often than ID 1
  assert Enum.count(selected_ids, & &1 == 3) > Enum.count(selected_ids, & &1 == 1)
end
```

## Mocking Strategy

To avoid module redefinition warnings, we use a sophisticated mocking strategy:

1. **Test-Specific Implementations**: Create test-specific implementations in the `support` directory
2. **MockHelper for Redirection**: Use `MockHelper.redirect_module/2` to redirect calls to test implementations
3. **Function-Level Mocking**: Use `MockHelper.override_function/3` for fine-grained control

Example:
```elixir
setup do
  # Redirect calls to Substrate to our test implementation
  MockHelper.redirect_module(Bardo.AgentManager.Substrate, TestSubstrate)
  
  # Override specific functions
  MockHelper.override_function(Bardo.Functions, :sigmoid, fn x -> 0.5 end)
  
  :ok
end
```

## Test Data Management

For managing test data:

1. **Use Factory Functions**: Create factory functions for common test data
2. **Set Up in Setup Blocks**: Set up test data in setup blocks
3. **Clean Up in Teardown**: Clean up test data in on_exit callbacks
4. **Use ETS for Test Storage**: Use ETS for in-memory test storage
5. **Avoid External Dependencies**: Minimize dependencies on external services

Example:
```elixir
defmodule TestFactory do
  def create_test_morphology(opts \\ []) do
    %{
      id: Keyword.get(opts, :id, "test_morph_#{:erlang.unique_integer([:positive])}"),
      name: Keyword.get(opts, :name, "Test Morphology"),
      # ... other fields
    }
  end
end

# In tests
test "morphology operations" do
  morphology = TestFactory.create_test_morphology()
  # ... test code
end
```

## Test Coverage

For ensuring good test coverage:

1. **Track Code Coverage**: Use ExCoveralls to track code coverage
2. **Focus on Critical Paths**: Prioritize covering critical paths and core functionality
3. **Test Edge Cases**: Identify and test edge cases and error conditions
4. **Test Public API**: Ensure all public API functions are tested
5. **Integration Tests**: Add integration tests for key workflows

To run coverage:
```bash
mix coveralls
# or for HTML output
mix coveralls.html
```

## Continuous Integration

For continuous integration:

1. **Run Tests on Every PR**: Ensure tests pass on every PR
2. **Check Coverage Thresholds**: Enforce minimum coverage thresholds
3. **Check Dialyzer**: Enforce type checking with Dialyzer
4. **Check Formatting**: Enforce consistent formatting
5. **Check Credo**: Enforce code quality with Credo

## Property-Based Testing

For more thorough testing, consider adding property-based tests:

1. **Identify Properties**: Identify invariants and properties that should hold
2. **Use StreamData**: Use StreamData for property-based testing
3. **Test with Many Inputs**: Test properties with many generated inputs
4. **Shrink Counterexamples**: When properties fail, examine the minimal counterexample

Example:
```elixir
property "network activation is within range" do
  check all weights <- list_of(float()),
            inputs <- list_of(float()) do
    {outputs, _} = Network.activate(weights, inputs)
    
    # All outputs should be between 0 and 1
    for output <- outputs do
      assert output >= 0.0 and output <= 1.0
    end
  end
end
```

## Performance Testing

For performance testing:

1. **Benchmark Critical Operations**: Benchmark performance-critical operations
2. **Test Scalability**: Test how performance scales with input size
3. **Test Concurrency**: Test how performance scales with concurrency
4. **Identify Bottlenecks**: Use profiling to identify bottlenecks
5. **Set Performance Thresholds**: Establish performance thresholds

Example:
```elixir
benchmark "network activation performance" do
  inputs = List.duplicate(0.5, 1000)
  weights = List.duplicate(0.5, 1000)
  
  # Should activate network in less than 1ms
  {time, _result} = :timer.tc(fn -> Network.activate(weights, inputs) end)
  assert time < 1000
end
```

## Testing Distributed Systems

For testing distributed systems:

1. **Test Node Communication**: Verify nodes communicate correctly
2. **Test Node Failures**: Verify system handles node failures gracefully
3. **Test Distributed Algorithms**: Verify distributed algorithms behave correctly
4. **Test Scaling**: Verify system scales with number of nodes
5. **Test Network Partitions**: Verify system handles network partitions

## Conclusion

By following the guidelines in this document, you can write effective tests for the Bardo neuroevolution framework that ensure correct behavior, catch regressions, and make refactoring safer. The improved testing approach using test-specific implementations and MockHelper also eliminates module redefinition warnings while maintaining comprehensive test coverage.