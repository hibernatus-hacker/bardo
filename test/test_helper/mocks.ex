defmodule Bardo.TestHelper.Mocks do
  @moduledoc """
  Helper module for setting up mocks in tests.
  
  This module provides utility functions for setting up mocks
  and ensures that the modules being mocked exist.
  """
  
  @doc """
  Set up mocks for a test.
  
  This function creates mock modules for testing.
  
  ## Examples
  
      setup do
        Bardo.TestHelper.Mocks.setup_mocks([
          Bardo.ScapeManager.ScapeManager,
          Bardo.ScapeManager.Scape
        ])
      end
  """
  def setup_mocks(modules) when is_list(modules) do
    Enum.each(modules, fn module ->
      # Ensure module is defined if it's an Elixir module
      if is_atom(module) and (to_string(module) |> String.starts_with?("Elixir.")) do
        ensure_module_exists(module)
      end
      
      # Create mock with safe options
      try do
        :meck.new(module, [:passthrough, :non_strict])
      catch
        :error, {:already_started, _} ->
          :meck.unload(module)
          :meck.new(module, [:passthrough, :non_strict])
      end
    end)
    
    # Register cleanup function only once per test
    ExUnit.Callbacks.on_exit({__MODULE__, make_ref()}, fn ->
      Enum.each(modules, fn module ->
        try do
          :meck.unload(module)
        catch
          _kind, _reason -> :ok
        end
      end)
    end)
    
    :ok
  end
  
  @doc """
  Set up a mock for an Erlang module.
  
  This is particularly useful for mocking Erlang modules that
  might not be easily accessible in Elixir.
  
  ## Examples
  
      setup do
        Bardo.TestHelper.Mocks.setup_erlang_mock(:cortex)
      end
  """
  def setup_erlang_mock(module) when is_atom(module) do
    try do
      :meck.new(module, [:non_strict])
    catch
      :error, {:already_started, _} ->
        :meck.unload(module)
        :meck.new(module, [:non_strict])
    end
    
    # Register cleanup function
    ExUnit.Callbacks.on_exit({__MODULE__, make_ref()}, fn ->
      try do
        :meck.unload(module)
      catch
        _kind, _reason -> :ok
      end
    end)
    
    :ok
  end
  
  # Ensure the module exists so it can be mocked
  defp ensure_module_exists(module) do
    if not Code.ensure_loaded?(module) do
      # Create a placeholder module if it doesn't exist
      module_name = module |> to_string() |> String.replace_prefix("Elixir.", "")
      Code.compiler_options(ignore_module_conflict: true)
      
      ast = quote do
        defmodule unquote(Module.concat(Elixir, module_name)) do
          @moduledoc false
          # Empty placeholder module for mocking
          def unquote(:"$handle_undefined_function")(name, args) do
            :erlang.error({:undefined_function, {unquote(module), name, length(args)}})
          end
        end
      end
      
      Code.eval_quoted(ast)
      Code.compiler_options(ignore_module_conflict: false)
    end
  end
end