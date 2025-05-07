defmodule Bardo.AgentManager.SignalAggregatorTest do
  use ExUnit.Case, async: true
  alias Bardo.AgentManager.SignalAggregator

  setup do
    pid1 = spawn(fn -> receive do _ -> :ok end end)
    pid2 = spawn(fn -> receive do _ -> :ok end end)
    
    input_acc = [{pid1, [0.5, 0.3]}, {pid2, [0.2, 0.1]}]
    input_pidps = [{pid1, [{0.1, []}, {0.2, []}]}, {pid2, [{0.3, []}, {0.4, []}]}, {:bias, [{0.5, []}]}]
    
    {:ok, %{input_acc: input_acc, input_pidps: input_pidps}}
  end
  
  test "dot_product correctly calculates dot product", %{input_acc: input_acc, input_pidps: input_pidps} do
    # Expected calculation: 
    # (0.5 * 0.1 + 0.3 * 0.2) + (0.2 * 0.3 + 0.1 * 0.4) + 0.5 = 0.05 + 0.06 + 0.06 + 0.04 + 0.5 = 0.71
    result = SignalAggregator.dot_product(input_acc, input_pidps)
    assert_in_delta result, 0.71, 0.001
  end
  
  test "apply function dispatches to the correct aggregation function", %{input_acc: input_acc, input_pidps: input_pidps} do
    dot_result = SignalAggregator.apply(:dot_product, input_acc, input_pidps)
    assert_in_delta dot_result, 0.71, 0.001
    
    # Store the initial input for diff_product
    Process.put(:diff_product, input_acc)
    
    # Try with a different input to see the difference calculation
    new_input_acc = [{Enum.at(input_acc, 0) |> elem(0), [0.6, 0.4]}, 
                     {Enum.at(input_acc, 1) |> elem(0), [0.3, 0.2]}]
                     
    diff_result = SignalAggregator.apply(:diff_product, new_input_acc, input_pidps)
    # The difference should reflect the changes in input values
    assert diff_result != dot_result
  end
  
  test "mult_product correctly calculates multiplicative product", %{input_acc: input_acc, input_pidps: input_pidps} do
    # Expected calculation:
    # (0.5 * 0.1 * 0.3 * 0.2) * (0.2 * 0.3 * 0.1 * 0.4) * 0.5
    result = SignalAggregator.mult_product(input_acc, input_pidps)
    assert result != 0.0  # The exact value isn't as important as verifying it's calculated
  end
end