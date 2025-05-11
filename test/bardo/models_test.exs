defmodule Bardo.ModelsTest do
  use ExUnit.Case, async: true
  import Bardo.Models
  
  test "create and manipulate topology summary" do
    data = %{
      type: :neural,
      tot_neurons: 10,
      tot_n_ils: 20,
      tot_n_ols: 30,
      tot_n_ros: 5,
      af_distribution: [tanh: 5, sigmoid: 5]
    }

    model = topology_summary(data)

    # Debug the model structure
    IO.inspect(model, label: "Model structure")

    assert get(:type, model) == :neural
    assert get(:tot_neurons, model) == 10

    updated = set({:tot_neurons, 15}, model)
    assert get(:tot_neurons, updated) == 15

    multi_updated = set([{:tot_n_ils, 25}, {:tot_n_ols, 35}], model)
    assert get(:tot_n_ils, multi_updated) == 25
    assert get(:tot_n_ols, multi_updated) == 35
  end
  
  test "create and manipulate agent model" do
    data = %{
      id: {:agent, 1.0},
      encoding_type: :neural,
      generation: 10,
      fitness: 0.75
    }
    
    model = agent(data)
    assert get(:id, model) == {:agent, 1.0}
    assert get(:fitness, model) == 0.75
    
    updated = set({:fitness, 0.85}, model)
    assert get(:fitness, updated) == 0.85
    
    # Test getting multiple keys
    values = get([:id, :encoding_type, :generation], model)
    assert values == [{:agent, 1.0}, :neural, 10]
  end
  
  test "handle not found keys" do
    model = sensor(%{id: {:sensor, 1.0}})
    assert get(:unknown_key, model) == :not_found
    
    values = get([:id, :unknown_key], model)
    assert values == [{:sensor, 1.0}, :not_found]
  end
end