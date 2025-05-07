# Define dummy module to be used instead of mocking
defmodule DummySubstrate do
  def set_weight(_, _, _), do: :ok
  def set_abcn(_, _, _), do: :ok
  def set_iterative(_, _, _), do: :ok
end

defmodule Bardo.AgentManager.SubstrateCEPTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.SubstrateCEP
  
  # Save original module to restore in on_exit
  @original_module Bardo.AgentManager.Substrate
  
  setup do
    # Save the original module implementation
    original_module = @original_module

    # Override Substrate module with our dummy implementation
    :code.purge(original_module)
    :code.delete(original_module)
    
    # Redefine module for testing
    Module.create(Bardo.AgentManager.Substrate, quote do
      def set_weight(:substrate_pid, _, [4.1940298507462686]), do: :ok
      def set_abcn(:substrate_pid, _, [3.14]), do: :ok
      def set_iterative(:substrate_pid, _, [4.1940298507462686]), do: :ok
    end, __ENV__)
    
    on_exit(fn ->
      # Clean up modified module
      :code.purge(Bardo.AgentManager.Substrate)
      :code.delete(Bardo.AgentManager.Substrate)
      
      # Note: In a real test environment, we would reload the original module here
      # but for our tests this is enough to avoid conflicts
    end)
    
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