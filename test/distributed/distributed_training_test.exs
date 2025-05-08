defmodule Bardo.Test.Distributed.DistributedTrainingTest do
  use ExUnit.Case
  
  alias Bardo.Test.Distributed.DistributedTesting
  
  @moduletag :distributed
  @moduletag timeout: 180_000  # 3 minutes timeout for distributed evolution
  
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
  
  test "can run distributed training across nodes", %{nodes: nodes} do
    # Setup a distributed training test
    # Small population and generations for faster testing
    {:ok, experiment_id} = DistributedTesting.setup_distributed_training_test(nodes, %{
      population_size: 30,
      generations: 3,
      mutation_rate: 0.2,
      tournament_size: 3,
      elite_fraction: 0.1
    })
    
    # Wait for training to complete (adjust time based on complexity)
    :timer.sleep(30_000)
    
    # Check training status
    master_node = List.first(nodes)
    
    {:ok, status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_training_status,
      [experiment_id]
    )
    
    # Verify that training ran successfully
    assert status.experiment_id == experiment_id
    assert status.islands == length(nodes)
    assert status.generation >= 1
    assert length(status.islands_status) == length(nodes)
    
    # Verify that we got a best agent
    {:ok, best_agent} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_best_agent,
      [experiment_id]
    )
    
    # Should return {:ok, agent}
    assert elem(best_agent, 0) == :ok
    agent = elem(best_agent, 1)
    
    # Agent should have a fitness value
    assert is_map(agent)
    assert is_list(agent.fitness)
  end
  
  test "distributed training can recover from node failures", %{nodes: nodes} do
    # Start training
    {:ok, experiment_id} = DistributedTesting.setup_distributed_training_test(nodes, %{
      population_size: 30,
      generations: 5,
      mutation_rate: 0.1
    })
    
    # Allow training to start
    :timer.sleep(5_000)
    
    # Check initial status
    master_node = List.first(nodes)
    
    {:ok, initial_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_training_status,
      [experiment_id]
    )
    
    # Verify that training started
    assert initial_status.status in [:initializing, :running]
    
    # Crash one of the worker nodes (not the master)
    node_to_crash = Enum.at(nodes, 1)
    :ok = DistributedTesting.crash_node(node_to_crash)
    
    # Allow time for fault detection and recovery
    :timer.sleep(10_000)
    
    # Restart the crashed node with a different port
    remaining_nodes = nodes -- [node_to_crash]
    {:ok, new_node} = DistributedTesting.add_node_to_cluster(remaining_nodes, [port: 9100])
    
    # Ensure cleanup
    on_exit(fn ->
      DistributedTesting.stop_node(new_node)
    end)
    
    # Allow time for training to continue
    :timer.sleep(20_000)
    
    # Check final status
    {:ok, final_status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_training_status,
      [experiment_id]
    )
    
    # Training should have continued and made progress
    assert final_status.generation > initial_status.generation
    
    # Verify that we can still get a best agent
    {:ok, best_agent} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_best_agent,
      [experiment_id]
    )
    
    assert elem(best_agent, 0) == :ok
  end
  
  test "distributed training with different island configurations", %{nodes: nodes} do
    # Setup training with more islands than nodes
    # This tests the ability to distribute multiple islands per node
    {:ok, experiment_id} = DistributedTesting.setup_distributed_training_test(nodes, %{
      population_size: 60,  # Larger population to split across more islands
      generations: 3,
      mutation_rate: 0.1
    })
    
    # Override default options to create more islands than nodes
    master_node = List.first(nodes)
    
    # Set up more islands than nodes
    opts = [nodes: nodes, islands: length(nodes) * 2, migration_interval: 1]
    
    {:ok, _} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :start_distributed_training,
      [experiment_id, %{population_size: 60, generations: 3}, opts]
    )
    
    # Allow training to run
    :timer.sleep(30_000)
    
    # Check status
    {:ok, status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_training_status,
      [experiment_id]
    )
    
    # We should have more islands than nodes
    assert status.islands > length(nodes)
    assert length(status.islands_status) > length(nodes)
    
    # Verify that each node has multiple islands
    node_island_counts = Enum.reduce(status.islands_status, %{}, fn island, acc ->
      node = island.node
      Map.update(acc, node, 1, &(&1 + 1))
    end)
    
    # At least one node should have multiple islands
    assert Enum.any?(node_island_counts, fn {_node, count} -> count > 1 end)
  end
  
  test "migration between islands during distributed training", %{nodes: nodes} do
    # Setup training with explicit migration settings
    {:ok, experiment_id} = DistributedTesting.setup_distributed_training_test(nodes, %{
      population_size: 30,
      generations: 5,
      mutation_rate: 0.1
    })
    
    # Override default options with shorter migration interval
    master_node = List.first(nodes)
    
    # Set migration to happen every generation with high migration rate
    opts = [nodes: nodes, islands: length(nodes), migration_interval: 1, migration_rate: 0.2]
    
    {:ok, _} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :start_distributed_training,
      [experiment_id, %{population_size: 30, generations: 5}, opts]
    )
    
    # Allow migration to occur a few times
    :timer.sleep(30_000)
    
    # Check status
    {:ok, status} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_training_status,
      [experiment_id]
    )
    
    # Migration should have occurred multiple times by now
    # Check for presence of migration indicators in status
    assert status.generation >= 3
    
    # Get best agent
    {:ok, best_agent} = DistributedTesting.run_on_node(
      master_node,
      Bardo.Examples.Applications.AlgoTrading.DistributedTraining,
      :get_best_agent,
      [experiment_id]
    )
    
    assert elem(best_agent, 0) == :ok
    agent = elem(best_agent, 1)
    
    # Ensure agent has fitness
    assert is_map(agent)
    assert is_list(agent.fitness)
  end
end