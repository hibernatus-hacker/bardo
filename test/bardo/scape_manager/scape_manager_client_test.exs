defmodule Bardo.ScapeManager.ScapeManagerClientTest do
  use ExUnit.Case
  
  alias Bardo.ScapeManager.ScapeManagerClient
  alias Bardo.TestHelper.Mocks
  
  # Constants
  @agent_id {:agent, 5.92352455}
  
  setup do
    # Setup mocks using our helper
    Mocks.setup_mocks([
      Bardo.ScapeManager.ScapeManager,
      Bardo.ScapeManager.Scape
    ])
    
    :ok
  end
  
  test "scape manager client functionality" do
    # Test start_scape
    :meck.expect(Bardo.ScapeManager.ScapeManager, :start_scape,
      fn(1.0, 1.0, 1.0, 1.0, :testmod) -> :ok end)
    
    assert :ok = ScapeManagerClient.start_scape(1.0, 1.0, 1.0, 1.0, :testmod)
    assert :meck.validate(Bardo.ScapeManager.ScapeManager)
    
    # Test stop_scape
    :meck.expect(Bardo.ScapeManager.ScapeManager, :stop_scape,
      fn(:testmod) -> :ok end)
    
    assert :ok = ScapeManagerClient.stop_scape(:testmod)
    assert :meck.validate(Bardo.ScapeManager.ScapeManager)
    
    # Test enter
    :meck.expect(Bardo.ScapeManager.Scape, :enter,
      fn(@agent_id, []) -> :ok end)
    
    assert :ok = ScapeManagerClient.enter(@agent_id, [])
    assert :meck.validate(Bardo.ScapeManager.Scape)
    
    # Test sense
    :meck.expect(Bardo.ScapeManager.Scape, :sense,
      fn(@agent_id, :pid, []) -> :ok end)
    
    assert :ok = ScapeManagerClient.sense(@agent_id, :pid, [])
    assert :meck.validate(Bardo.ScapeManager.Scape)
    
    # Test actuate
    :meck.expect(Bardo.ScapeManager.Scape, :actuate,
      fn(@agent_id, :pid, :some_fun, []) -> :ok end)
    
    assert :ok = ScapeManagerClient.actuate(@agent_id, :pid, :some_fun, [])
    assert :meck.validate(Bardo.ScapeManager.Scape)
    
    # Test leave
    :meck.expect(Bardo.ScapeManager.Scape, :leave,
      fn(@agent_id, []) -> :ok end)
    
    assert :ok = ScapeManagerClient.leave(@agent_id, [])
    assert :meck.validate(Bardo.ScapeManager.Scape)
  end
end