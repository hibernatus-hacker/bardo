# Bardo Test Support

This directory contains test support modules for the Bardo neuroevolution framework. These modules provide a consistent and robust testing infrastructure without causing module redefinition warnings.

## Overview

The test support modules provide:

1. **Mock implementations** of core components for isolated testing
2. **Helper functions** for common testing operations
3. **Test-specific modules** to avoid redefining actual application modules

## Key Components

### MockHelper

`MockHelper` provides tools for setting up mocks without redefining modules. It includes:

- `setup_mocks/2`: Set up mocks for specified modules
- `redirect_module/2`: Redirect calls from one module to a test implementation
- `override_function/3`: Override a specific function in a module

Example:
```elixir
# Redirect calls to Substrate to our test implementation
MockHelper.redirect_module(Bardo.AgentManager.Substrate, TestSubstrate)
```

### Test Implementation Modules

Instead of redefining modules in test files, we provide test implementations:

- `TestSubstrate`: Mock implementation of Substrate for testing
- `TestNeuron`: Mock implementation of Neuron for testing
- `TestFunctions`: Mock implementation of Functions for testing
- `TestPolisMgr`: Mock implementation of PolisMgr for testing
- `TestExperimentManagerClient`: Mock implementation of ExperimentManagerClient for testing

## Best Practices

1. **Avoid Module Redefinition**: Never redefine modules in tests. Instead, use `MockHelper.redirect_module/2` to redirect calls to test implementations.

2. **Use Test-Specific Modules**: Create test-specific modules in the `support` directory rather than redefining existing modules.

3. **Clean Up After Tests**: Always clean up any mocking in the `on_exit` callback to avoid affecting other tests.

4. **Isolate Tests**: Keep tests isolated from each other to avoid interference.

## Example Usage

```elixir
defmodule MyTest do
  use ExUnit.Case
  alias Bardo.TestSupport.TestSubstrate
  alias Bardo.TestSupport.MockHelper
  
  setup do
    # Redirect calls to Substrate to our test implementation
    MockHelper.redirect_module(Bardo.AgentManager.Substrate, TestSubstrate)
    :ok
  end
  
  test "my test" do
    # Test code that calls Substrate functions
    # These will be redirected to TestSubstrate implementations
  end
end
```

## Adding New Test Support Modules

To add a new test support module:

1. Create a file in the `support` directory with a descriptive name
2. Define a module with the same function signatures as the module you're mocking
3. Implement the mock functionality to suit your test needs
4. Use `MockHelper.redirect_module/2` to redirect calls to your test module

## Notes on Module Redefinition Warnings

Elixir and Erlang warn about module redefinition because it can cause unexpected behavior in applications. By using the approach in this directory, we avoid these warnings while still getting the benefits of mocking for isolated testing.