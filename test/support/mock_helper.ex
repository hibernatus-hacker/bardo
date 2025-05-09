defmodule Bardo.TestSupport.MockHelper do
  @moduledoc """
  Enhanced helper module for mocking in tests.
  
  This module provides comprehensive mocking capabilities without
  redefining modules, which avoids the module redefinition warnings.
  """
  
  @doc """
  Set up mocks for a test using :meck.
  
  ## Parameters
    * `modules` - List of modules to mock
    * `opts` - Options for mocking
      * `:passthrough` - Whether to pass through calls to original implementation (default: true)
      * `:non_strict` - Allow undefined functions (default: true)
  
  ## Examples
      setup do
        MockHelper.setup_mocks([Bardo.PopulationManager])
        :ok
      end
  """
  def setup_mocks(modules, opts \\ []) when is_list(modules) do
    passthrough = Keyword.get(opts, :passthrough, true)
    non_strict = Keyword.get(opts, :non_strict, true)
    
    meck_opts = []
    meck_opts = if passthrough, do: [:passthrough | meck_opts], else: meck_opts
    meck_opts = if non_strict, do: [:non_strict | meck_opts], else: meck_opts
    
    Enum.each(modules, fn module ->
      try do
        :meck.new(module, meck_opts)
      catch
        :error, {:already_started, _} ->
          :meck.unload(module)
          :meck.new(module, meck_opts)
      end
    end)
    
    # Register cleanup function
    ExUnit.Callbacks.on_exit({__MODULE__, make_ref()}, fn ->
      Enum.each(modules, fn module ->
        try do
          if :meck.validate(module) do
            :meck.unload(module)
          else
            IO.puts("Warning: Mock validation failed for #{inspect(module)}")
            :meck.unload(module)
          end
        catch
          _kind, _reason -> :ok
        end
      end)
    end)
    
    :ok
  end
  
  @doc """
  Temporarily overrides a module's function with a test implementation.
  
  This uses :meck to override specific functions while allowing other
  functions to behave normally.
  
  ## Parameters
    * `module` - The module containing the function to override
    * `function` - The function name (atom)
    * `implementation` - Function that implements the override
  
  ## Examples
      # Override Neuron.forward/3 function for this test
      test "test with override" do
        MockHelper.override_function(Neuron, :forward, fn(pid, neuron_id, input) ->
          assert input == [1.0, 2.0]
          :ok
        end)
        
        # Test code that calls Neuron.forward/3
        assert :ok = MyModule.function_that_calls_neuron_forward()
      end
  """
  def override_function(module, function, implementation) when is_atom(module) and is_atom(function) and is_function(implementation) do
    # Set up mock if not already done
    try do
      :meck.new(module, [:passthrough, :non_strict])
    catch
      :error, {:already_started, _} -> :ok
    end
    
    # Override the function
    :meck.expect(module, function, implementation)
    
    # Register cleanup if not already registered
    ExUnit.Callbacks.on_exit({__MODULE__, {module, function, make_ref()}}, fn ->
      try do
        :meck.unload(module)
      catch
        _kind, _reason -> :ok
      end
    end)
    
    :ok
  end
  
  @doc """
  Mock a module to redirect calls to a test implementation module.
  
  This is useful when you want to provide an alternative implementation
  of a module without redefining the original module.
  
  ## Parameters
    * `module` - The module to redirect
    * `test_module` - The module containing test implementations
  
  ## Examples
      # Redirect calls to Substrate to TestSubstrate
      setup do
        MockHelper.redirect_module(Bardo.AgentManager.Substrate, 
                                   Bardo.TestSupport.TestSubstrate)
        :ok
      end
  """
  def redirect_module(module, test_module) when is_atom(module) and is_atom(test_module) do
    # Get all functions from the test module
    functions = test_module.__info__(:functions)

    # Set up mock if not already done
    try do
      :meck.new(module, [:passthrough, :non_strict])
    catch
      :error, {:already_started, _} ->
        :meck.unload(module)
        # Wait a little bit before creating the new mock to avoid race conditions
        Process.sleep(50)
        :meck.new(module, [:passthrough, :non_strict])
    end

    # Redirect each function to the test module
    try do
      Enum.each(functions, fn {function, arity} ->
        args = Macro.generate_arguments(arity, __MODULE__)
        apply_fn = quote do
          fn unquote_splicing(args) ->
            apply(unquote(test_module), unquote(function), [unquote_splicing(args)])
          end
        end
        apply_fn = Code.eval_quoted(apply_fn) |> elem(0)

        # Wrap the expect call in a try/catch to handle potential errors
        try do
          :meck.expect(module, function, apply_fn)
        catch
          :error, reason ->
            # Log the error but continue with other functions
            IO.puts("Warning: Failed to mock #{inspect(module)}.#{function}/#{arity}: #{inspect(reason)}")
        end
      end)
    rescue
      e ->
        # Handle any exceptions during the mocking process
        IO.puts("Error during mocking of #{inspect(module)}: #{inspect(e)}")
    end

    # Register cleanup with a more robust unloading strategy
    ExUnit.Callbacks.on_exit({__MODULE__, {module, test_module, make_ref()}}, fn ->
      try do
        # First try normal unload
        :meck.unload(module)
      catch
        # If it fails, try force unload
        :error, _reason ->
          try do
            :meck.reset(module)
            Process.sleep(50)
            :meck.unload(module)
          catch
            _kind, _inner_reason ->
              # Last resort: try to kill any processes related to this mock
              Process.whereis(:"#{module}_meck")
              |> case do
                nil -> :ok
                pid when is_pid(pid) ->
                  Process.exit(pid, :kill)
                  :ok
              end
          end
      end
    end)

    :ok
  end
end