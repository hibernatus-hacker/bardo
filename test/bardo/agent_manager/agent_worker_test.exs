defmodule Bardo.AgentManager.AgentWorkerTest do
  use ExUnit.Case
  
  alias Bardo.AgentManager.AgentWorker
  alias Bardo.AgentManager.Exoself
  
  @agent_id {:agent, 1.334}
  @op_mode :gt
  
  setup do
    # Create the agent_ids_pids ETS table
    :ets.new(:agent_ids_pids, [:set, :public, :named_table,
      {:write_concurrency, true}, {:read_concurrency, true}])
    
    # Create mock modules using our helper
    alias Bardo.TestHelper.Mocks
    Mocks.setup_mocks([Bardo.AgentManager.Exoself])
    
    :ok
  end
  
  test "agent_worker starts and initializes an exoself" do
    # Setup mocks
    :meck.expect(Bardo.AgentManager.Exoself, :start, fn (_) -> self() end)
    :meck.expect(Bardo.AgentManager.Exoself, :init_phase2, 
      fn (_, @agent_id, @op_mode) -> :ok end)
    
    # Start the agent worker
    {:ok, _pid} = AgentWorker.start_link(@agent_id, @op_mode)
    
    # Allow time for process to initialize
    Process.sleep(50)
    
    # Verify the exoself functions were called with correct parameters
    assert :meck.validate(Bardo.AgentManager.Exoself)
  end
end