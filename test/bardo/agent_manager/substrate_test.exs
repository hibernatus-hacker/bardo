defmodule Bardo.AgentManager.SubstrateTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.Substrate
  
  setup do
    :ok
  end
  
  test "substrate abcn plasticity rule" do
    # Test the ABCN plasticity rule
    input = 0.5
    output = 0.8
    weight = 0.3
    parameters = [0.1, 0.2, 0.3, 0.5] # [a, b, c, n]
    
    # a*input*output + b*input + c*output
    expected_delta = 0.5 * (0.1 * 0.5 * 0.8 + 0.2 * 0.5 + 0.3 * 0.8)
    expected_new_weight = weight + expected_delta
    
    new_weight = Substrate.abcn(input, output, weight, parameters)
    assert_in_delta new_weight, expected_new_weight, 0.0001
  end
  
  test "substrate initialization" do
    # start/2
    pid = Substrate.start(node(), self())
    
    # Create test data
    sensors = [%{id: :sensor1, vl: 2, format: nil}]
    actuators = [%{id: :actuator1, vl: 2, format: nil}]
    spids = [self()]
    apids = [self()]
    cpp_pids = [self()]
    cep_pids = [self()]
    densities = [2, 3, 3]  # depth, width, height
    plasticity = :none
    linkform = :l2l_feedforward
    
    # init_phase2/11
    assert :ok = Substrate.init_phase2(
      pid,
      self(),
      sensors,
      actuators,
      spids,
      apids,
      cpp_pids,
      cep_pids,
      densities,
      plasticity,
      linkform
    )
    
    # Test API functions
    assert :ok = Substrate.set_weight(pid, self(), [0.5])
    assert :ok = Substrate.set_abcn(pid, self(), [0.5, 0.1, 0.2, 0.3, 0.4])
    assert :ok = Substrate.set_iterative(pid, self(), [0.1])
    assert :ok = Substrate.weight_expression(pid, self(), [0.5, 1.0])
    
    # Test substrate state management
    assert :ok = Substrate.backup_substrate(pid, self())
    assert :ok = Substrate.reset_substrate(pid, self())
    assert :ok = Substrate.revert_substrate(pid, self())
    
    # Simulate a sensor input
    assert :ok = Substrate.forward(pid, hd(spids), 0.5)
    
    # Stop the substrate
    assert :ok = Substrate.stop(pid, self())
  end
  
  test "substrate linkform types" do
    linkforms = [:l2l_feedforward, :fully_interconnected, :jordan_recurrent, :neuronself_recurrent]
    
    for linkform <- linkforms do
      # start/2
      pid = Substrate.start(node(), self())
      
      # Create test data
      sensors = [%{id: :sensor1, vl: 2, format: nil}]
      actuators = [%{id: :actuator1, vl: 2, format: nil}]
      spids = [self()]
      apids = [self()]
      cpp_pids = [self()]
      cep_pids = [self()]
      densities = [1, 3, 3]  # depth, width, height
      plasticity = :none
      
      # init_phase2/11
      assert :ok = Substrate.init_phase2(
        pid,
        self(),
        sensors,
        actuators,
        spids,
        apids,
        cpp_pids,
        cep_pids,
        densities,
        plasticity,
        linkform
      )
      
      # Simulate a sensor input to activate substrate construction
      assert :ok = Substrate.forward(pid, hd(spids), 0.5)
      
      # Stop the substrate
      assert :ok = Substrate.stop(pid, self())
    end
  end
  
  test "substrate plasticity modes" do
    plasticity_modes = [:none, :iterative, :abcn]
    
    for plasticity <- plasticity_modes do
      # start/2
      pid = Substrate.start(node(), self())
      
      # Create test data
      sensors = [%{id: :sensor1, vl: 2, format: nil}]
      actuators = [%{id: :actuator1, vl: 2, format: nil}]
      spids = [self()]
      apids = [self()]
      cpp_pids = [self()]
      cep_pids = [self()]
      densities = [1, 3, 3]  # depth, width, height
      linkform = :l2l_feedforward
      
      # init_phase2/11
      assert :ok = Substrate.init_phase2(
        pid,
        self(),
        sensors,
        actuators,
        spids,
        apids,
        cpp_pids,
        cep_pids,
        densities,
        plasticity,
        linkform
      )
      
      # Simulate a sensor input to activate substrate construction
      assert :ok = Substrate.forward(pid, hd(spids), 0.5)
      
      # Stop the substrate
      assert :ok = Substrate.stop(pid, self())
    end
  end
  
  test "substrate sensor formats" do
    formats = [
      nil,
      :no_geo,
      {:symmetric, [3, 3]},
      {:coorded, 2, [3, 3], [{[0.1, 0.2], 0, :void}, {[0.3, 0.4], 0, :void}]}
    ]
    
    for format <- formats do
      # start/2
      pid = Substrate.start(node(), self())
      
      # Create test data with the specific format
      sensors = [%{id: :sensor1, vl: 2, format: format}]
      actuators = [%{id: :actuator1, vl: 2, format: format}]
      spids = [self()]
      apids = [self()]
      cpp_pids = [self()]
      cep_pids = [self()]
      densities = [1, 3, 3]  # depth, width, height
      plasticity = :none
      linkform = :l2l_feedforward
      
      # init_phase2/11
      assert :ok = Substrate.init_phase2(
        pid,
        self(),
        sensors,
        actuators,
        spids,
        apids,
        cpp_pids,
        cep_pids,
        densities,
        plasticity,
        linkform
      )
      
      # Simulate a sensor input to activate substrate construction
      assert :ok = Substrate.forward(pid, hd(spids), 0.5)
      
      # Stop the substrate
      assert :ok = Substrate.stop(pid, self())
    end
  end
end