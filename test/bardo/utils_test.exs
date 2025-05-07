defmodule Bardo.UtilsTest do
  use ExUnit.Case, async: true
  alias Bardo.Utils

  # For proper testing, we'd need a mock for Bardo.AppConfig
  # but we'll create a simple stub for the Utils.get_module test
  defmodule TestAppConfig do
    def get_env(:build_tool), do: :elixir
  end

  test "random_seed returns a valid random state" do
    {state, _} = Utils.random_seed()
    assert is_map(state)
    assert Map.has_key?(state, :type)
  end

  test "safe_serialize_erlang converts term to binary" do
    term = %{key: "value", list: [1, 2, 3]}
    binary = Utils.safe_serialize_erlang(term)
    assert is_binary(binary)
  end

  test "safe_binary_to_term validates and converts binary to term" do
    original = %{key: "value", list: [1, 2, 3]}
    binary = :erlang.term_to_binary(original)
    
    assert {:ok, ^original} = Utils.safe_binary_to_term(binary)
  end

  test "vec1_dominates_vec2 identifies vector dominance" do
    # Complete superiority
    assert Utils.vec1_dominates_vec2([10.0, 20.0, 30.0], [5.0, 10.0, 15.0], 0.1) == true
    
    # Complete inferiority
    assert Utils.vec1_dominates_vec2([5.0, 10.0, 15.0], [10.0, 20.0, 30.0], 0.1) == false
    
    # Mixed comparison
    assert Utils.vec1_dominates_vec2([10.0, 10.0, 10.0], [5.0, 20.0, 5.0], 0.1) == false
  end

  test "vec1_dominates_vec2 calculates vector difference" do
    result = Utils.vec1_dominates_vec2([10.0, 20.0, 30.0], [5.0, 10.0, 15.0], 0.1, [])
    
    # For each element: val1 - (val2 + val2 * mip)
    # 10.0 - (5.0 + 5.0 * 0.1) = 10.0 - 5.5 = 4.5
    # 20.0 - (10.0 + 10.0 * 0.1) = 20.0 - 11.0 = 9.0
    # 30.0 - (15.0 + 15.0 * 0.1) = 30.0 - 16.5 = 13.5
    assert length(result) == 3
    
    # The order might be reversed, so we sort both lists
    sorted_result = Enum.sort(result)
    expected = [4.5, 9.0, 13.5]
    
    Enum.zip(sorted_result, expected)
    |> Enum.each(fn {actual, expect} ->
      assert_in_delta actual, expect, 0.000001
    end)
  end
end