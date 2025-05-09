defmodule Bardo.AgentManager.SubstrateCPPTest do
  use ExUnit.Case

  alias Bardo.AgentManager.SubstrateCPP
  alias Bardo.TestSupport.TestNeuron
  alias Bardo.TestSupport.TestFunctions
  alias Bardo.TestSupport.MockHelper

  setup do
    # Use our improved mock helper to redirect calls
    MockHelper.redirect_module(Bardo.AgentManager.Neuron, TestNeuron)

    # Redirect calls to Functions if needed
    if Code.ensure_loaded?(Bardo.Functions) do
      MockHelper.redirect_module(Bardo.Functions, TestFunctions)
    else
      # If Functions module doesn't exist yet, we need to override specific functions
      MockHelper.setup_mocks([Bardo.Functions])
      # Define separate expectations for different arities
      :meck.expect(Bardo.Functions, :cartesian, 2, fn([px], [py]) ->
        TestFunctions.cartesian([px], [py])
      end)
      :meck.expect(Bardo.Functions, :cartesian, 3, fn([px], [py], [a, b, c]) ->
        TestFunctions.cartesian([px], [py], [a, b, c])
      end)
    end

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

  # Mock cartesian/2
  :meck.expect(Bardo.Functions, :cartesian, 2, fn(icoord, coord) ->
    # Implementation for cartesian/2
    icoord ++ coord
  end)

  # Mock cartesian/3
  :meck.expect(Bardo.Functions, :cartesian, 3, fn(icoord, coord, iow) ->
    # Implementation for cartesian/3
    # Extract values from iow which should contain [i, o, w]
    [i, o, w] = iow
    [i, o, w | icoord ++ coord]
  end)

end
