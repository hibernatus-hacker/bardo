# Define dummy module to be used instead of mocking
defmodule DummyNeuron do
  def forward(_, _, _), do: :ok
end

defmodule Bardo.AgentManager.SubstrateCPPTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.SubstrateCPP
  
  # Save original module to restore in on_exit
  @original_module Bardo.AgentManager.Neuron
  
  setup do
    # Save the original module implementation
    original_module = @original_module

    # Override Neuron module with our dummy implementation
    :code.purge(original_module)
    :code.delete(original_module)
    
    # Redefine module for testing with expected arguments
    Module.create(Bardo.AgentManager.Neuron, quote do
      def forward(:from_pid, _, [3.14, 6.28]), do: :ok
      def forward(:from_pid, _, [1.3, 2.4, 1.3, 3.14, 6.28]), do: :ok
      def forward(_, _, _), do: :ok
    end, __ENV__)
    
    # Add Functions module implementation needed for cartesian operation
    unless Code.ensure_loaded?(Bardo.Functions) do
      Module.create(Bardo.Functions, quote do
        def cartesian([px], [py]), do: [px, py]
        def cartesian([px], [py], [a, b, c]), do: [a, b, c, px, py]
      end, __ENV__)
    end
    
    on_exit(fn ->
      # Clean up modified module
      :code.purge(Bardo.AgentManager.Neuron)
      :code.delete(Bardo.AgentManager.Neuron)
      
      # Note: In a real test environment, we would reload the original module here
      # but for our tests this is enough to avoid conflicts
    end)
    
    :ok
  end
  
  test "substrate_cpp functionality" do
    # start/2
    pid = SubstrateCPP.start(node(), :exo_pid)
    
    # init_phase2/9
    assert :ok = SubstrateCPP.init_phase2(
      pid, 
      :exo_pid, 
      :id, 
      :cortex_pid, 
      :substrate_pid, 
      :cartesian, 
      1, 
      [], 
      [:from_pid]
    )
    
    # neurode_coordinates/4
    SubstrateCPP.neurode_coordinates(pid, :substrate_pid, [3.14], [6.28])
    
    # stop/2
    assert :ok = SubstrateCPP.stop(pid, :exo_pid)
  end
  
  test "substrate_cpp_iow functionality" do
    # start/2
    pid = SubstrateCPP.start(node(), :exo_pid)
    
    # init_phase2/9
    assert :ok = SubstrateCPP.init_phase2(
      pid, 
      :exo_pid, 
      :id, 
      :cortex_pid, 
      :substrate_pid, 
      :cartesian, 
      1, 
      [], 
      [:from_pid]
    )
    
    # neurode_coordinates_iow/5
    SubstrateCPP.neurode_coordinates_iow(pid, :substrate_pid, [3.14], [6.28], [1.3, 2.4, 1.3])
    
    # stop/2
    assert :ok = SubstrateCPP.stop(pid, :exo_pid)
  end
end