defmodule Bardo.AgentManager.SubstrateCEPTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.SubstrateCEP
  alias Bardo.TestSupport.TestSubstrate
  alias Bardo.TestSupport.MockHelper
  
  setup do
    # Use our improved mock helper to redirect calls to Substrate to our test module
    MockHelper.redirect_module(Bardo.AgentManager.Substrate, TestSubstrate)
    
    :ok
  end
  
  test "substrate_cep set_weight functionality" do
    # start/2
    pid = SubstrateCEP.start(node(), :exo_pid)
    
    # init_phase2/8
    assert :ok = SubstrateCEP.init_phase2(
      pid, 
      :exo_pid, 
      :id, 
      :cortex_pid,
      :substrate_pid, 
      :set_weight, 
      [], 
      [:from_pid]
    )
    
    # forward/3
    SubstrateCEP.forward(pid, :from_pid, [3.14])
    
    # Stop the process
    assert :ok = SubstrateCEP.stop(pid, :exo_pid)
  end
  
  test "substrate_cep set_abcn functionality" do
    # start/2
    pid = SubstrateCEP.start(node(), :exo_pid)
    
    # init_phase2/8
    assert :ok = SubstrateCEP.init_phase2(
      pid, 
      :exo_pid, 
      :id, 
      :cortex_pid,
      :substrate_pid, 
      :set_abcn, 
      [], 
      [:from_pid]
    )
    
    # forward/3
    SubstrateCEP.forward(pid, :from_pid, [3.14])
    
    # stop/2
    assert :ok = SubstrateCEP.stop(pid, :exo_pid)
  end
  
  test "substrate_cep delta_weight functionality" do
    # start/2
    pid = SubstrateCEP.start(node(), :exo_pid)
    
    # init_phase2/8
    assert :ok = SubstrateCEP.init_phase2(
      pid, 
      :exo_pid, 
      :id, 
      :cortex_pid,
      :substrate_pid, 
      :delta_weight, 
      [], 
      [:from_pid]
    )
    
    # forward/3
    SubstrateCEP.forward(pid, :from_pid, [3.14])
    
    # stop/2
    assert :ok = SubstrateCEP.stop(pid, :exo_pid)
  end
end