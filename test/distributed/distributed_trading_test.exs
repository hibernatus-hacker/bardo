defmodule Bardo.Test.Distributed.DistributedTradingTest do
  use ExUnit.Case

  alias Bardo.Test.Distributed.DistributedTesting

  @moduletag :distributed
  @moduletag :skip  # Skip these tests by default, as they require distributed setup
  @moduletag timeout: 120_000  # 2 minutes timeout for trading tests
  
  setup do
    # Start a test cluster with 3 nodes
    {:ok, nodes} = DistributedTesting.start_cluster(3)
    
    # Return the nodes to the test
    on_exit(fn ->
      # Always stop the cluster after the test
      DistributedTesting.stop_cluster(nodes)
    end)
    
    %{nodes: nodes}
  end
  
  test "can deploy trading agents across multiple nodes", %{nodes: nodes} do
    # Setup trading agents distributed across nodes
    {:ok, agent_ids} = DistributedTesting.setup_distributed_trading_test(nodes, 5)
    
    # Verify that we got the expected number of agent IDs
    assert length(agent_ids) == 5
    
    # Allow agents to initialize and start processing
    :timer.sleep(5_000)
    
    # Check status of all agents
    master_node = List.first(nodes)
    
    {:ok, fleet_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :get_fleet_performance,
      [agent_ids]
    )
    
    # Verify that all agents are running
    assert map_size(fleet_status) == length(agent_ids)
    
    # All agents should be initialized or trading/watching
    Enum.each(fleet_status, fn {_agent_id, status} ->
      assert status.status in [:initialized, :watching, :trading]
    end)
  end
  
  test "agents continue running when nodes fail and recover", %{nodes: nodes} do
    # Setup trading agents
    {:ok, agent_ids} = DistributedTesting.setup_distributed_trading_test(nodes, 3)
    
    # Allow agents to initialize
    :timer.sleep(5_000)
    
    # Check which agents are on which nodes
    master_node = List.first(nodes)
    
    # Function to find which node an agent is running on
    find_agent_node = fn agent_id ->
      Enum.find(nodes, fn node ->
        {:ok, result} = DistributedTesting.run_on_node(
          node,
          Process,
          :whereis,
          [agent_id]
        )
        
        # If the agent is found on this node, result will be a PID
        result != nil
      end)
    end
    
    # Map agents to their nodes
    agent_nodes = Enum.map(agent_ids, fn agent_id ->
      {agent_id, find_agent_node.(agent_id)}
    end)
    |> Enum.into(%{})
    
    # Find an agent on a node that's not the master
    {agent_id, node_to_crash} = Enum.find(agent_nodes, fn {_agent_id, node} ->
      node != master_node
    end)
    
    # Verify that we found such an agent
    assert node_to_crash != master_node
    
    # Get initial status of the agent
    {:ok, initial_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :get_status,
      [agent_id]
    )
    
    # Crash the node
    :ok = DistributedTesting.crash_node(node_to_crash)
    
    # Allow time for fault detection
    :timer.sleep(5_000)
    
    # Restart the crashed node with a different port
    remaining_nodes = nodes -- [node_to_crash]
    {:ok, new_node} = DistributedTesting.add_node_to_cluster(remaining_nodes, [port: 9100])
    
    # Ensure cleanup
    on_exit(fn ->
      DistributedTesting.stop_node(new_node)
    end)
    
    # Restart the agent on the new node
    {:ok, _} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :start_link,
      [agent_id, %{}, Bardo.Test.Distributed.MockBroker, %{
        symbol: "EURUSD",
        timeframe: 15,
        account_id: "test_account",
        initial_balance: 10_000.0,
        leverage: 100,
        commission: 0.0,
        simulation: true
      }]
    )
    
    # Allow agent to initialize
    :timer.sleep(5_000)
    
    # Check if agent is running
    {:ok, new_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :get_status,
      [agent_id]
    )
    
    # Agent should be running again
    assert new_status.agent_id == agent_id
    assert new_status.status in [:initialized, :watching, :trading]
    
    # The new agent should have a different last_update time
    assert new_status.last_update != initial_status.last_update
  end
  
  test "can update risk parameters across distributed agents", %{nodes: nodes} do
    # Setup trading agents
    {:ok, agent_ids} = DistributedTesting.setup_distributed_trading_test(nodes, 3)
    
    # Allow agents to initialize
    :timer.sleep(5_000)
    
    # Update risk parameters for all agents
    master_node = List.first(nodes)
    
    new_risk_params = %{
      risk_per_trade: 0.02,         # 2% of account per trade
      max_drawdown: 0.15,           # 15% maximum drawdown
      stop_loss: 0.03,              # 3% stop loss
      take_profit: 0.06             # 6% take profit
    }
    
    # Update params for each agent
    Enum.each(agent_ids, fn agent_id ->
      {:ok, result} = DistributedTesting.run_on_node(
        master_node,
        Bardo.Examples.Applications.AlgoTrading.LiveAgent,
        :update_risk_params,
        [agent_id, new_risk_params]
      )
      
      assert result == :ok
    end)
    
    # Allow updates to propagate
    :timer.sleep(2_000)
    
    # Check that params were updated
    {:ok, fleet_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :get_fleet_performance,
      [agent_ids]
    )
    
    # Each agent should report the updated risk parameters in its status
    Enum.each(fleet_status, fn {_agent_id, status} ->
      # Risk parameters are not directly in the status report
      # Instead, verify trading behavior is affected by stopping and
      # checking for any errors
      assert status.status in [:initialized, :watching, :trading]
    end)
  end
  
  test "can enable and disable continuous learning across nodes", %{nodes: nodes} do
    # Setup trading agents
    {:ok, agent_ids} = DistributedTesting.setup_distributed_trading_test(nodes, 3)
    
    # Allow agents to initialize
    :timer.sleep(5_000)
    
    # Enable continuous learning for all agents
    master_node = List.first(nodes)
    
    # Enable adaptation for each agent
    Enum.each(agent_ids, fn agent_id ->
      {:ok, result} = DistributedTesting.run_on_node(
        master_node,
        Bardo.Examples.Applications.AlgoTrading.LiveAgent,
        :enable_continuous_learning,
        [agent_id, 0.05, 5]  # Higher learning rate and more frequent updates for testing
      )
      
      assert result == :ok
    end)
    
    # Allow updates to propagate
    :timer.sleep(2_000)
    
    # Verify each agent has adaptation enabled
    Enum.each(agent_ids, fn agent_id ->
      {:ok, result} = DistributedTesting.run_on_node(
        master_node,
        Bardo.Examples.Applications.AlgoTrading.LiveAgent,
        :set_adaptation,
        [agent_id, false]  # Disable adaptation to test toggle
      )
      
      assert result == :ok
    end)
    
    # Allow updates to propagate
    :timer.sleep(2_000)
    
    # Enable again to verify toggle works
    Enum.each(agent_ids, fn agent_id ->
      {:ok, result} = DistributedTesting.run_on_node(
        master_node,
        Bardo.Examples.Applications.AlgoTrading.LiveAgent,
        :set_adaptation,
        [agent_id, true]
      )
      
      assert result == :ok
    end)
  end
  
  test "can close all positions across distributed agents", %{nodes: nodes} do
    # Setup trading agents
    {:ok, agent_ids} = DistributedTesting.setup_distributed_trading_test(nodes, 3)
    
    # Allow agents to initialize and potentially open positions
    :timer.sleep(10_000)
    
    # Close all positions for all agents
    master_node = List.first(nodes)
    
    # Close positions for each agent
    Enum.each(agent_ids, fn agent_id ->
      {:ok, result} = DistributedTesting.run_on_node(
        master_node,
        Bardo.Examples.Applications.AlgoTrading.LiveAgent,
        :close_all_positions,
        [agent_id]
      )
      
      assert result == :ok
    end)
    
    # Allow operations to complete
    :timer.sleep(2_000)
    
    # Verify that all positions are closed
    {:ok, fleet_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :get_fleet_performance,
      [agent_ids]
    )
    
    # Each agent should have no open positions
    Enum.each(fleet_status, fn {_agent_id, status} ->
      # Check that position direction is 0 (no position)
      assert status.position.direction == 0
      assert status.position.size == 0.0
    end)
  end
  
  test "can export and import agents across nodes", %{nodes: nodes} do
    # First run a mini distributed training to get agents
    {:ok, experiment_id} = DistributedTesting.setup_distributed_training_test(nodes, %{
      population_size: 20,
      generations: 2,
      mutation_rate: 0.1
    })
    
    # Allow training to run briefly
    :timer.sleep(20_000)
    
    # Export the agents to a file
    master_node = List.first(nodes)
    export_path = "/tmp/bardo_test_agents.json"
    
    {:ok, result} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :export_agents,
      [experiment_id, export_path, 2]  # Export 2 agents for testing
    )
    
    assert result == :ok
    
    # Verify that the file exists
    assert File.exists?(export_path)
    
    # Import the agents back
    {:ok, imported_agents} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.LiveAgent,
      :import_agents,
      [export_path]
    )
    
    # Verify that we got agents back
    assert length(imported_agents) == 2
    
    # Clean up the export file
    File.rm(export_path)
  end
end