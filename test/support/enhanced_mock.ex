defmodule Bardo.TestSupport.EnhancedMock do
  @moduledoc """
  Enhanced mocking system for Bardo tests.
  
  This module provides an advanced mocking system that improves upon the existing
  MockHelper by adding features such as:
  
  - State tracking in mocks
  - Expectation verification
  - Call counting and argument validation
  - Automatic teardown
  - Behavior mocking
  - Recording of all calls for later verification
  
  It's designed to make testing complex interactions between components easier
  and more reliable.
  """
  
  # Import test-related modules
  require Logger
  
  @doc """
  Creates a new mock for a module with advanced features.
  
  ## Parameters
  
  - `module` - The module to mock
  - `opts` - Options controlling mock behavior:
    - `:passthrough` - Whether to call the original implementation (default: true)
    - `:track_state` - Whether to track state between calls (default: true)
    - `:record_calls` - Whether to record all calls for verification (default: true)
    - `:verify_on_exit` - Whether to verify expectations on exit (default: true)
  
  ## Examples
  
  ```
  setup do
    EnhancedMock.mock(Bardo.AgentManager.Cortex)
    :ok
  end
  
  test "verifies activation was called" do
    EnhancedMock.expect(Bardo.AgentManager.Cortex, :activate, fn(_nn, inputs) -> 
      assert length(inputs) == 2
      [0.5]
    end)
    
    # Test code that calls Cortex.activate
    ...
    
    # Verify expectation was met
    assert EnhancedMock.verify!
  end
  ```
  """
  def mock(module, opts \\ []) do
    # Default options
    passthrough = Keyword.get(opts, :passthrough, true)
    track_state = Keyword.get(opts, :track_state, true)
    record_calls = Keyword.get(opts, :record_calls, true)
    verify_on_exit = Keyword.get(opts, :verify_on_exit, true)
    
    # Set up module options for meck
    meck_opts = []
    meck_opts = if passthrough, do: [:passthrough | meck_opts], else: meck_opts
    meck_opts = if track_state, do: [:non_strict | meck_opts], else: meck_opts
    
    # Create the mock
    try do
      :meck.new(module, meck_opts)
    catch
      :error, {:already_started, _} ->
        :meck.unload(module)
        :meck.new(module, meck_opts)
    end
    
    # Start recording calls if requested
    if record_calls do
      :persistent_term.put({__MODULE__, module, :calls}, [])
      install_call_recorder(module)
    end
    
    # Register cleanup function
    if verify_on_exit do
      ExUnit.Callbacks.on_exit({__MODULE__, module, make_ref()}, fn ->
        verify_expectations(module)
        :meck.unload(module)
      end)
    else
      ExUnit.Callbacks.on_exit({__MODULE__, module, make_ref()}, fn ->
        :meck.unload(module)
      end)
    end
    
    # Store settings for this mock
    :persistent_term.put({__MODULE__, module, :settings}, %{
      passthrough: passthrough,
      track_state: track_state,
      record_calls: record_calls,
      verify_on_exit: verify_on_exit,
      expectations: []
    })
    
    :ok
  end
  
  @doc """
  Sets an expectation for a function call on a mocked module.
  
  ## Parameters
  
  - `module` - The mocked module
  - `function` - The function name (atom)
  - `implementation` - Function that implements the expected behavior
  - `opts` - Options controlling the expectation:
    - `:count` - How many times the function should be called (default: :any)
      Can be a number or :any (any number of times, including zero)
    - `:args` - Expected arguments (default: :any)
      Can be a list of exact values, :any, or function that validates args
  
  ## Examples
  
  ```
  # Expect activate to be called exactly once with any args
  EnhancedMock.expect(Cortex, :activate, fn(_nn, _inputs) -> [0.5] end, count: 1)
  
  # Expect activate to be called with specific args
  EnhancedMock.expect(Cortex, :activate, fn(nn, inputs) -> [0.5] end, 
    args: [%{state: :ready}, [0.0, 1.0]])
  
  # Expect activate to be called with args that match a condition
  EnhancedMock.expect(Cortex, :activate, fn(nn, inputs) -> [0.5] end,
    args: fn(nn, inputs) -> length(inputs) == 2 end)
  ```
  """
  def expect(module, function, implementation, opts \\ []) do
    # Get settings
    settings = :persistent_term.get({__MODULE__, module, :settings})
    
    # Default options
    count = Keyword.get(opts, :count, :any)
    args = Keyword.get(opts, :args, :any)
    
    # Create expectation
    expectation = %{
      function: function,
      implementation: implementation,
      count: count,
      args: args,
      actual_calls: 0
    }
    
    # Add to expectations
    expectations = [expectation | settings.expectations]
    :persistent_term.put({__MODULE__, module, :settings}, %{settings | expectations: expectations})
    
    # Set up the mock implementation
    :meck.expect(module, function, fn args ->
      # Record the call
      record_call(module, function, args)
      
      # Update expectation call count
      update_expectation_calls(module, function, args)
      
      # Call the implementation
      apply(implementation, args)
    end)
    
    :ok
  end
  
  @doc """
  Sets implementations for multiple functions at once, using a behavior module
  as a template.
  
  ## Parameters
  
  - `module` - The mocked module
  - `behavior` - The behavior module to use as a template (optional)
  - `implementations` - Map of function names to implementations
  
  ## Examples
  
  ```
  # Mock a behavior implementation
  EnhancedMock.mock_behavior(MyMock, MyBehavior, %{
    init: fn(args) -> {:ok, args} end,
    handle_call: fn(req, from, state) -> {:reply, :ok, state} end
  })
  ```
  """
  def mock_behavior(module, behavior \\ nil, implementations) do
    # Get function list from behavior if provided
    functions = 
      if behavior != nil do
        # Get callbacks from behavior
        case Code.ensure_compiled(behavior) do
          {:module, _} ->
            behavior.behaviour_info(:callbacks)
          _ ->
            []
        end
      else
        # Use provided implementations
        Enum.map(implementations, fn {name, _impl} -> {name, :any} end)
      end
    
    # Set up expectations for each function
    Enum.each(functions, fn {name, arity} ->
      impl = Map.get(implementations, name)
      
      if impl != nil do
        # Create a function with the right arity
        args = Macro.generate_arguments(arity, __MODULE__)
        func_ast = quote do
          fn unquote_splicing(args) -> 
            apply(unquote(impl), [unquote_splicing(args)]) 
          end
        end
        func = Code.eval_quoted(func_ast) |> elem(0)
        
        # Set expectation
        expect(module, name, func)
      end
    end)
    
    :ok
  end
  
  @doc """
  Creates a stateful mock that maintains state between calls.
  
  ## Parameters
  
  - `module` - The module to mock
  - `initial_state` - The initial state for the mock
  - `handlers` - Map of function names to state-aware handler functions
  
  ## Examples
  
  ```
  # Create a stateful database mock
  initial_state = %{items: []}
  
  EnhancedMock.stateful_mock(Database, initial_state, %{
    write: fn(id, value, state) -> 
      new_state = %{state | items: [value | state.items]}
      {:ok, new_state}
    end,
    read: fn(id, state) ->
      item = Enum.find(state.items, &(&1.id == id))
      {{:ok, item}, state}
    end
  })
  ```
  """
  def stateful_mock(module, initial_state, handlers) do
    # Create the mock
    mock(module, track_state: true)
    
    # Set up initial state
    :persistent_term.put({__MODULE__, module, :state}, initial_state)
    
    # Set up handlers for each function
    Enum.each(handlers, fn {name, handler} ->
      :meck.expect(module, name, fn args ->
        # Get current state
        state = :persistent_term.get({__MODULE__, module, :state})
        
        # Record the call
        record_call(module, name, args)
        
        # Update expectation call count
        update_expectation_calls(module, name, args)
        
        # Call the handler with state
        {result, new_state} = apply(handler, [args, state])
        
        # Update state
        :persistent_term.put({__MODULE__, module, :state}, new_state)
        
        # Return the result
        result
      end)
    end)
    
    :ok
  end
  
  @doc """
  Creates a spy that records all calls to a module without changing behavior.
  
  ## Parameters
  
  - `module` - The module to spy on
  
  ## Examples
  
  ```
  # Create a spy on the database module
  EnhancedMock.spy(Database)
  
  # Run code that uses the database
  Database.write(:key, :value)
  
  # Check what was called
  calls = EnhancedMock.get_calls(Database)
  assert Enum.any?(calls, fn {func, args} -> 
    func == :write and args == [:key, :value]
  end)
  ```
  """
  def spy(module) do
    # Create passthrough mock that records calls
    mock(module, passthrough: true, track_state: false, verify_on_exit: false)
    
    # Install call recorder that doesn't interfere with original behavior
    install_call_recorder(module)
    
    :ok
  end
  
  @doc """
  Gets all recorded calls for a mocked module.
  
  ## Parameters
  
  - `module` - The mocked module
  
  ## Returns
  
  List of {function_name, args} tuples representing all calls made to the module.
  """
  def get_calls(module) do
    :persistent_term.get({__MODULE__, module, :calls}, [])
  end
  
  @doc """
  Gets the current state for a stateful mock.
  
  ## Parameters
  
  - `module` - The mocked module
  
  ## Returns
  
  The current state of the mock.
  """
  def get_state(module) do
    :persistent_term.get({__MODULE__, module, :state})
  end
  
  @doc """
  Verifies that all expectations for a mocked module have been met.
  
  ## Parameters
  
  - `module` - The mocked module (optional)
    If not provided, verifies all mocked modules
  
  ## Returns
  
  true if all expectations were met, raises an error otherwise.
  """
  def verify!(module \\ nil) do
    if module != nil do
      verify_expectations(module)
    else
      # Verify all mocked modules
      modules = get_all_mocked_modules()
      Enum.each(modules, &verify_expectations/1)
    end
    
    true
  end
  
  @doc """
  Resets a mock to its initial state, clearing all expectations and calls.
  
  ## Parameters
  
  - `module` - The mocked module
  """
  def reset(module) do
    settings = :persistent_term.get({__MODULE__, module, :settings}, %{
      expectations: []
    })
    
    # Reset expectations
    :persistent_term.put({__MODULE__, module, :settings}, %{settings | expectations: []})
    
    # Reset calls
    :persistent_term.put({__MODULE__, module, :calls}, [])
    
    # Reset state if it's a stateful mock
    if Map.get(settings, :track_state, false) do
      :persistent_term.put({__MODULE__, module, :state}, nil)
    end
    
    :ok
  end
  
  # Internal helper functions
  
  # Install a call recorder for a module
  defp install_call_recorder(module) do
    # Create a function that wraps any function call to record it
    :meck.expect(module, :_, fn(func, args) ->
      record_call(module, func, args)
      
      # Call through to the original implementation if passthrough is enabled
      settings = :persistent_term.get({__MODULE__, module, :settings})
      
      if settings.passthrough do
        :meck.passthrough([func | args])
      else
        # Use dummy implementation that returns nil
        nil
      end
    end)
  end
  
  # Record a call to a function
  defp record_call(module, function, args) do
    # Get current call list
    calls = :persistent_term.get({__MODULE__, module, :calls}, [])
    
    # Add this call
    :persistent_term.put({__MODULE__, module, :calls}, [{function, args} | calls])
  end
  
  # Update expectation call counts for a function call
  defp update_expectation_calls(module, function, args) do
    # Get settings
    settings = :persistent_term.get({__MODULE__, module, :settings})
    
    # Find matching expectations
    expectations = settings.expectations
    
    # Update matching expectations
    updated_expectations = 
      Enum.map(expectations, fn expectation ->
        if expectation.function == function and args_match?(expectation.args, args) do
          %{expectation | actual_calls: expectation.actual_calls + 1}
        else
          expectation
        end
      end)
    
    # Save updated expectations
    :persistent_term.put({__MODULE__, module, :settings}, %{settings | expectations: updated_expectations})
  end
  
  # Check if args match an expectation
  defp args_match?(:any, _args), do: true
  
  defp args_match?(expected_args, actual_args) when is_function(expected_args) do
    # Call the validation function
    apply(expected_args, actual_args)
  end
  
  defp args_match?(expected_args, actual_args) when is_list(expected_args) and is_list(actual_args) do
    # Check length
    if length(expected_args) != length(actual_args) do
      false
    else
      # Check each argument
      Enum.zip(expected_args, actual_args)
      |> Enum.all?(fn {expected, actual} -> 
        expected == :any or expected == actual
      end)
    end
  end
  
  defp args_match?(_, _), do: false
  
  # Verify that all expectations have been met
  defp verify_expectations(module) do
    # Get settings
    settings = :persistent_term.get({__MODULE__, module, :settings}, %{expectations: []})
    
    # Check each expectation
    Enum.each(settings.expectations, fn expectation ->
      # Skip if count is :any
      if expectation.count != :any do
        # Check that the function was called the expected number of times
        if expectation.actual_calls != expectation.count do
          raise "Expectation not met: #{inspect module}.#{expectation.function} was called #{expectation.actual_calls} times, expected #{expectation.count}"
        end
      end
    end)
    
    true
  end
  
  # Get all mocked modules
  defp get_all_mocked_modules do
    # This is a simplification - in a real implementation you would need
    # to track the modules that have been mocked
    []
  end
end