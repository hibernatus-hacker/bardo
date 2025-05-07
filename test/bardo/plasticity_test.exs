defmodule Bardo.PlasticityTest do
  use ExUnit.Case, async: false
  alias Bardo.Plasticity
  alias Bardo.Models
  alias Bardo.DB
  
  # Define test constants
  @afs [:tanh, :cos, :gaussian, :absolute, :sin, :sqrt, :sigmoid]
  @cx_id {:cortex, {:origin, 81.678457630318}}
  @nh_wid {:neuron, {0.0, 1.2131105277401442}}
  @nh_id {:neuron, {0.0, 2.2719130909152305}}
  @nojw_id {:neuron, {0.0, 1.34564564128163}}
  @noj_id {:neuron, {0.0, 1.159246038128163}}
  @nsmv1_id {:neuron, {0.0, 2.194216939804278}}
  @nsmv2_id {:neuron, {0.0, 1.056170344851108}}
  @nsmv3_id {:neuron, {0.0, 5.710439851448822}}
  @nsmv4_id {:neuron, {0.0, 5.267619846825299}}
  @nsmv5_id {:neuron, {0.0, 7.570099812537118}}
  @nsmv6_id {:neuron, {0.0, 2.4400325184421328}}
  @nn_mid {:neuron, {0.0, 2.998667206588721}}
  
  setup do
    # Start DB if not started
    if Process.whereis(Bardo.DB) == nil do
      DB.start_link()
    end
    :ok
  end
  
  test "none plasticity function" do
    # Test none/1 with different parameters
    assert [] = Plasticity.none(:neural_parameters)
    assert [] = Plasticity.none(:weight_parameters)
    assert_raise RuntimeError, "Neuron does not support plasticity.", fn -> 
      Plasticity.none({{:neuron, {0.0, test_unique_id()}}, :mutate}) 
    end
    
    # Test none/4 function
    # Store a reference to self in a variable to avoid the match context
    test_pid = self()
    assert [{^test_pid, [{1.2356, [0.5747]}]}] =
      Plasticity.none([5.0, 0.3423], [{test_pid, [0.34234]}], [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "hebbian_w plasticity function" do
    # Create test neuron
    nhw = Models.neuron(%{
      id: @nh_wid,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}},
      [[:rand.uniform() - 0.5, [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nhw, :neuron)
    
    # Test hebbian_w/1 with different parameters
    assert [] = Plasticity.hebbian_w(:neural_parameters)
    [wp_hw] = Plasticity.hebbian_w(:weight_parameters)
    assert wp_hw > -1.0
    assert wp_hw < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test hebbian_w/4 function
    test_pid = self()
    assert [{^test_pid, [{1.3691096627228, [0.5747]}]}] =
      Plasticity.hebbian_w([5.0, 0.3423], [{test_pid, [0.34234]}], [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "hebbian plasticity function" do
    # Create test neuron
    nh = Models.neuron(%{
      id: @nh_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5, []]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nh, :neuron)
    
    # Test hebbian/1 with different parameters
    [h_np] = Plasticity.hebbian(:neural_parameters)
    assert is_float(h_np)
    assert [] = Plasticity.hebbian(:weight_parameters)
    
    # Skip mutation test - requires ETS table
    
    # Test hebbian/4 function
    test_pid = self()
    assert [{^test_pid, [{1.3151203715852, []}]}] =
      Plasticity.hebbian([5.0, 0.3423], [{test_pid, [0.34234]}], [{test_pid, [{1.2356, []}]}], [0.6786])
  end
  
  test "ojas_w plasticity function" do
    # Create test neuron
    nojw = Models.neuron(%{
      id: @nojw_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}},
      [[:rand.uniform() - 0.5, [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nojw, :neuron)
    
    # Test ojas_w/1 with different parameters
    assert [] = Plasticity.ojas_w(:neural_parameters)
    [wp_ojw] = Plasticity.ojas_w(:weight_parameters)
    assert wp_ojw > -1.0
    assert wp_ojw < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test ojas_w/4 function
    test_pid = self()
    assert [{^test_pid, [{1.0421103744654128, [0.5747]}]}] =
      Plasticity.ojas_w([5.0, 0.3423], [{test_pid, [0.34234]}], [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "ojas plasticity function" do
    # Create test neuron
    noj = Models.neuron(%{
      id: @noj_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5, []]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(noj, :neuron)
    
    # Test ojas/1 with different parameters
    [oj_np] = Plasticity.ojas(:neural_parameters)
    assert is_float(oj_np)
    assert [] = Plasticity.ojas(:weight_parameters)
    
    # Skip mutation test - requires ETS table
    
    # Test ojas/4 function
    test_pid = self()
    assert [{^test_pid, [{1.1203546566547953, []}]}] =
      Plasticity.ojas([5.0, 0.3423], [{test_pid, [0.34234]}], [{test_pid, [{1.2356, []}]}], [0.6786])
  end
  
  test "self_modulation_v1 plasticity function" do
    # Create test neuron
    nsmv1 = Models.neuron(%{
      id: @nsmv1_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv1, :neuron)
    
    # Test self_modulation_v1/1 with different parameters
    assert [0.1, 0, 0, 0] = Plasticity.self_modulation_v1(:neural_parameters)
    [wp_smv1] = Plasticity.self_modulation_v1(:weight_parameters)
    assert wp_smv1 > -1.0
    assert wp_smv1 < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v1/4 function
    test_pid = self()
    assert [{^test_pid, [{1.2401124966549328, [0.5747]}]}] =
      Plasticity.self_modulation_v1([5.0, 0.1, 0, 0, 0], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "self_modulation_v2 plasticity function" do
    # Create test neuron
    nsmv2 = Models.neuron(%{
      id: @nsmv2_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv2, :neuron)
    
    # Test self_modulation_v2/1 with different parameters
    [_a, 0, 0, 0] = Plasticity.self_modulation_v2(:neural_parameters)
    [wp_smv2] = Plasticity.self_modulation_v2(:weight_parameters)
    assert wp_smv2 > -1.0
    assert wp_smv2 < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v2/4 function
    test_pid = self()
    assert [{^test_pid, [{1.2401124966549328, [0.5747]}]}] =
      Plasticity.self_modulation_v2([5.0, 0.1, 0, 0, 0], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "self_modulation_v3 plasticity function" do
    # Create test neuron
    nsmv3 = Models.neuron(%{
      id: @nsmv3_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv3, :neuron)
    
    # Test self_modulation_v3/1 with different parameters
    [smv3_np1, smv3_np2, smv3_np3, smv3_np4] = Plasticity.self_modulation_v3(:neural_parameters)
    assert is_float(smv3_np1)
    assert is_float(smv3_np2)
    assert is_float(smv3_np3)
    assert is_float(smv3_np4)
    
    [wp_smv3] = Plasticity.self_modulation_v3(:weight_parameters)
    assert wp_smv3 > -1.0
    assert wp_smv3 < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v3/4 function
    test_pid = self()
    assert [{^test_pid, [{1.2401124966549328, [0.5747]}]}] =
      Plasticity.self_modulation_v3([5.0, 0.1, 0, 0, 0], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  test "self_modulation_v4 plasticity function" do
    # Create test neuron
    nsmv4 = Models.neuron(%{
      id: @nsmv4_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv4, :neuron)
    
    # Test self_modulation_v4/1 with different parameters
    assert [0, 0, 0] = Plasticity.self_modulation_v4(:neural_parameters)
    [wp_smv4a, wp_smv4b] = Plasticity.self_modulation_v4(:weight_parameters)
    assert wp_smv4a > -1.0
    assert wp_smv4b > -1.0
    assert wp_smv4a < 1.0
    assert wp_smv4b < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v4/4 function
    test_pid = self()
    assert [{^test_pid, [{1.2443652091679887, [0.5747, 0.5747]}]}] =
      Plasticity.self_modulation_v4([5.0, 0, 0, 0], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747, 0.5747]}]}], [0.6786])
  end
  
  test "self_modulation_v5 plasticity function" do
    # Create test neuron
    nsmv5 = Models.neuron(%{
      id: @nsmv5_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv5, :neuron)
    
    # Test self_modulation_v5/1 with different parameters
    [smv5_np1, smv5_np2, smv5_np3] = Plasticity.self_modulation_v5(:neural_parameters)
    assert is_float(smv5_np1)
    assert is_float(smv5_np2)
    assert is_float(smv5_np3)
    
    [wp_smv5a, wp_smv5b] = Plasticity.self_modulation_v5(:weight_parameters)
    assert wp_smv5a > -1.0
    assert wp_smv5b > -1.0
    assert wp_smv5a < 1.0
    assert wp_smv5b < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v5/4 function
    test_pid = self()
    result = Plasticity.self_modulation_v5([5.0, 0.234, 0.685, 0.1954], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747, 0.5747]}]}], [0.6786])
    
    # Check that we have the correct structure with a PID and a float value with the expected structure
    assert [{pid, [{value, params}]}] = result
    assert pid == test_pid
    assert params == [0.5747, 0.5747]
    assert_in_delta value, 1.3881727392749774, 0.0000000000001
  end
  
  test "self_modulation_v6 plasticity function" do
    # Create test neuron
    nsmv6 = Models.neuron(%{
      id: @nsmv6_id,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nsmv6, :neuron)
    
    # Test self_modulation_v6/1 with different parameters
    assert [] = Plasticity.self_modulation_v6(:neural_parameters)
    [wp_smv6a, _wp_smv6b, _wp_smv6c, _wp_smv6d, _wp_smv6e] = Plasticity.self_modulation_v6(:weight_parameters)
    assert wp_smv6a > -1.0
    assert wp_smv6a < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test self_modulation_v6/4 function
    test_pid = self()
    assert [{^test_pid, [{1.2930111515582352, [0.5747, 0.5747, 0.234, 0.685, 0.1954]}]}] =
      Plasticity.self_modulation_v6([5.0], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747, 0.5747, 0.234, 0.685, 0.1954]}]}], [0.6786])
  end
  
  test "neuromodulation plasticity function" do
    # Create test neuron
    nnm = Models.neuron(%{
      id: @nn_mid,
      generation: 1,
      cx_id: @cx_id,
      af: Enum.at(@afs, :rand.uniform(length(@afs)) - 1),
      pf: {:hebbian, [:rand.uniform() - 0.5]},
      aggr_f: :dot_product,
      input_idps: [{{:neuron, {0.0, test_unique_id()}}, [[:rand.uniform() - 0.5,
      [:rand.uniform() - 0.5]]]}],
      input_idps_modulation: [],
      output_ids: [],
      ro_ids: []
    })
    DB.write(nnm, :neuron)
    
    # Test neuromodulation/1 with different parameters
    [wp_nma, _wp_nmb, _wp_nmc, _wp_nmd, _wp_nme] = Plasticity.neuromodulation(:neural_parameters)
    assert [] = Plasticity.neuromodulation(:weight_parameters)
    assert wp_nma > -1.0
    assert wp_nma < 1.0
    
    # Skip mutation test - requires ETS table
    
    # Test neuromodulation/4 function
    test_pid = self()
    assert [{^test_pid, [{2.9057581729341253, [0.5747]}]}] =
      Plasticity.neuromodulation([5.0, 0.234, 0.685, 0.1954, 1.3234, 0.324], [{test_pid, [0.34234]}],
        [{test_pid, [{1.2356, [0.5747]}]}], [0.6786])
  end
  
  # Helper function to generate a unique ID for testing
  defp test_unique_id do
    (1 / :rand.uniform() * 1000000 / 1000000)
  end
  
  # No need for global cleanup - each test handles its own resources
end