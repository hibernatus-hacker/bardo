defmodule Bardo.Utils do
  @moduledoc """
  Utility functions for the Bardo system.
  """

  @doc """
  Seed PRNG for the current process.
  
  Uses exs1024s (not cryptographically strong, but fast).
  """
  @spec random_seed() :: {map(), any()}
  def random_seed do
    # Use Erlang's rand module for compatibility
    # For cryptographically strong but slower option, use:
    # <<i1::32-unsigned-integer, i2::32-unsigned-integer, i3::32-unsigned-integer>> = :crypto.strong_rand_bytes(12)
    # :rand.seed(:exsplus, {i1, i2, i3})
    :rand.seed(:exs1024s)
  end

  @doc """
  Safely serialize Erlang term to binary.
  """
  @spec safe_serialize_erlang(term()) :: binary()
  def safe_serialize_erlang(term) do
    t = binarify(term)
    :erlang.term_to_binary(t)
  end

  @doc """
  Safely convert binary to Erlang term.
  """
  @spec safe_binary_to_term(binary()) :: {:ok, term()} | no_return()
  def safe_binary_to_term(binary) when is_binary(binary) do
    try do
      term = :erlang.binary_to_term(binary)
      safe_terms(term)
      {:ok, term}
    catch
      _kind, _reason -> throw(:malformed_erlang)
    end
  end

  @doc """
  Return system metrics.
  """
  @spec system_metrics() :: map()
  def system_metrics do
    %{
      memory: Enum.map([:used, :allocated, :unused, :usage], fn v -> {v, :recon_alloc.memory(v)} end),
      scheduler_usage: :recon.scheduler_usage(1000)
    }
  end

  @doc """
  Return correct module syntax based on SDK environment configuration.
  """
  @spec get_module(atom()) :: atom()
  def get_module(module) when is_atom(module) do
    # First check if the module is already loaded or loadable
    if Code.ensure_loaded?(module) do
      module
    else
      # If not loaded, handle based on environment
      case Application.get_env(:bardo, :build_tool, :unknown) do
        :test ->
          # For test environment, try to find with Elixir prefix if needed
          try_find_test_module(module)
        :erlang ->
          module
        :elixir ->
          module_str = module |> Atom.to_string() |> Macro.camelize()
          String.to_atom("Elixir.#{module_str}")
        _ ->
          # Default case, try to handle based on module name
          module_str = module |> Atom.to_string() |> Macro.camelize()
          
          if String.starts_with?(module_str, "Elixir.") do
            String.to_atom(module_str)
          else
            String.to_atom("Elixir.#{module_str}")
          end
      end
    end
  end
  
  # Helper to find test modules
  defp try_find_test_module(module) do
    # Try different ways the module might be defined
    module_str = Atom.to_string(module)
    
    # Try with various prefixes
    candidates = [
      module,                                  # As is
      String.to_atom("Elixir.#{module_str}"),  # With Elixir prefix
      String.to_atom(module_str)               # Without any prefix
    ]
    
    # Return the first loadable module or the original
    Enum.find(candidates, module, &Code.ensure_loaded?/1)
  end

  @doc """
  Checks if vector A dominates vector B with a minimum improvement percentage.
  
  Returns true if all elements in A are significantly better than in B.
  """
  @spec vec1_dominates_vec2([float()], [float()], float()) :: boolean()
  def vec1_dominates_vec2(a, b, mip) do
    vec_dif = vec1_dominates_vec2(a, b, mip, [])
    tot_elems = length(vec_dif)
    dif_elems = length(Enum.filter(vec_dif, fn val -> val > 0 end))
    
    cond do
      dif_elems == tot_elems -> true  # Complete Superiority
      dif_elems == 0 -> false         # Complete Inferiority
      true -> false                   # Variation, Pareto front
    end
  end

  @doc """
  Calculate vector difference with minimum improvement percentage (MIP).
  """
  @spec vec1_dominates_vec2([float()], [float()], float(), [float()]) :: [float()]
  def vec1_dominates_vec2([val1 | vec1], [val2 | vec2], mip, acc) do
    vec1_dominates_vec2(vec1, vec2, mip, [val1 - (val2 + val2 * mip) | acc])
  end
  def vec1_dominates_vec2([], [], _mip, acc), do: acc

  # Private Functions

  @spec safe_terms(term()) :: term() | no_return()
  defp safe_terms(list) when is_list(list), do: safe_list(list)
  
  defp safe_terms(tuple) when is_tuple(tuple) do
    safe_tuple(tuple, tuple_size(tuple))
  end
  
  defp safe_terms(map) when is_map(map) do
    Enum.reduce(map, map, fn {key, value}, acc ->
      safe_terms(key)
      safe_terms(value)
      acc
    end)
  end
  
  defp safe_terms(other)
      when is_atom(other) or is_number(other) or is_bitstring(other)
      or is_pid(other) or is_reference(other),
      do: other
      
  defp safe_terms(_other), do: throw(:safe_terms)

  @spec safe_list(list()) :: :ok | no_return()
  defp safe_list([]), do: :ok
  
  defp safe_list([h | t]) when is_list(t) do
    safe_terms(h)
    safe_list(t)
  end
  
  defp safe_list([h | t]) do
    safe_terms(h)
    safe_terms(t)
  end

  @spec safe_tuple(tuple(), non_neg_integer()) :: :ok | no_return()
  defp safe_tuple(_tuple, 0), do: :ok
  
  defp safe_tuple(tuple, n) do
    safe_terms(elem(tuple, n - 1))
    safe_tuple(tuple, n - 1)
  end

  @spec binarify(term()) :: term()
  defp binarify(binary) when is_binary(binary), do: binary
  
  defp binarify(number) when is_number(number), do: number
  
  defp binarify(atom) when atom == nil or is_boolean(atom), do: atom
  
  defp binarify(atom) when is_atom(atom), do: Atom.to_string(atom)
  
  defp binarify(list) when is_list(list) do
    Enum.map(list, &binarify/1)
  end
  
  defp binarify(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&binarify/1)
  end
  
  defp binarify(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc -> 
      Map.put(acc, binarify(k), binarify(v)) 
    end)
  end
end