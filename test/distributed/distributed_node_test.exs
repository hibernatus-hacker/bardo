defmodule Bardo.Test.Distributed.DistributedNodeTest do
  use ExUnit.Case
  
  alias Bardo.Test.Distributed.DistributedTesting
  
  @moduletag :distributed
  @moduletag timeout: 120_000  # 2 minutes timeout for distributed tests
  
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
  
  test "nodes can communicate with each other", %{nodes: nodes} do
    # Verify that all nodes can see each other
    results = DistributedTesting.run_on_all_nodes(nodes, Node, :list, [])
    
    # Each node should see all other nodes
    Enum.each(results, fn {node, connected_nodes} ->
      # A node should see all other nodes, but not itself
      expected_nodes = nodes -- [node]
      assert length(connected_nodes) == length(expected_nodes)
      assert Enum.sort(connected_nodes) == Enum.sort(expected_nodes)
    end)
  end
  
  test "can run code on remote nodes", %{nodes: nodes} do
    # Define a test module to run on remote nodes
    test_module = Module.concat(__MODULE__, Helper)
    
    unless Code.ensure_loaded?(test_module) do
      module_body = quote do
        def hello_world do
          {:ok, Node.self()}
        end
        
        def get_system_info do
          %{
            node: Node.self(),
            system_time: System.system_time(),
            memory: :erlang.memory(),
            process_count: length(Process.list())
          }
        end
      end
      
      Module.create(test_module, module_body, Macro.Env.location(__ENV__))
    end
    
    # Run the hello_world function on the first node
    first_node = List.first(nodes)
    {:ok, result} = DistributedTesting.run_on_node(first_node, test_module, :hello_world)
    
    # Verify that it returns the correct node name
    assert result == {:ok, first_node}
    
    # Run get_system_info on all nodes
    results = DistributedTesting.run_on_all_nodes(nodes, test_module, :get_system_info)
    
    # Verify that we got results from all nodes
    assert map_size(results) == length(nodes)
    
    # Verify that each result contains the expected keys
    Enum.each(results, fn {node, info} ->
      assert info.node == node
      assert is_integer(info.system_time)
      assert is_map(info.memory)
      assert is_integer(info.process_count)
    end)
  end
  
  test "can simulate network partitions", %{nodes: nodes} do
    # Create a network partition
    {disconnected, connected} = DistributedTesting.create_network_partition(nodes, 1)
    
    # Verify partition
    assert length(disconnected) == 1
    assert length(connected) == 2
    
    # Disconnected node should not see connected nodes
    {:ok, visible_from_disconnected} = DistributedTesting.run_on_node(List.first(disconnected), Node, :list, [])
    assert visible_from_disconnected == []
    
    # Connected nodes should see each other but not disconnected nodes
    Enum.each(connected, fn node ->
      {:ok, visible} = DistributedTesting.run_on_node(node, Node, :list, [])
      assert length(visible) == 1
      assert List.first(visible) in connected
      assert List.first(visible) != node
    end)
    
    # Heal the partition
    :ok = DistributedTesting.heal_network_partition(disconnected, connected)
    
    # Verify that all nodes can see each other again
    :timer.sleep(1000)
    results = DistributedTesting.run_on_all_nodes(nodes, Node, :list, [])
    
    Enum.each(results, fn {node, connected_nodes} ->
      expected_nodes = nodes -- [node]
      assert length(connected_nodes) == length(expected_nodes)
      assert Enum.sort(connected_nodes) == Enum.sort(expected_nodes)
    end)
  end
  
  test "can add nodes to an existing cluster", %{nodes: nodes} do
    # Add a new node to the cluster
    {:ok, new_node} = DistributedTesting.add_node_to_cluster(nodes)
    
    # Ensure cleanup
    on_exit(fn ->
      DistributedTesting.stop_node(new_node)
    end)
    
    # Verify that the new node can see all existing nodes
    {:ok, visible_from_new} = DistributedTesting.run_on_node(new_node, Node, :list, [])
    assert length(visible_from_new) == length(nodes)
    assert Enum.sort(visible_from_new) == Enum.sort(nodes)
    
    # Verify that all existing nodes can see the new node
    Enum.each(nodes, fn node ->
      {:ok, visible} = DistributedTesting.run_on_node(node, Node, :list, [])
      assert new_node in visible
    end)
  end
  
  test "can recover from node crashes", %{nodes: nodes} do
    # Crash one node
    node_to_crash = List.first(nodes)
    :ok = DistributedTesting.crash_node(node_to_crash)
    
    # Wait for the crash to be detected
    :timer.sleep(1000)
    
    # Verify that the crashed node is no longer visible
    remaining_nodes = nodes -- [node_to_crash]
    Enum.each(remaining_nodes, fn node ->
      {:ok, visible} = DistributedTesting.run_on_node(node, Node, :list, [])
      assert node_to_crash not in visible
    end)
    
    # Restart the crashed node
    {:ok, new_node} = DistributedTesting.add_node_to_cluster(remaining_nodes, [port: 9100])
    
    # Ensure cleanup
    on_exit(fn ->
      DistributedTesting.stop_node(new_node)
    end)
    
    # Verify that the new node can see all remaining nodes
    {:ok, visible_from_new} = DistributedTesting.run_on_node(new_node, Node, :list, [])
    assert length(visible_from_new) == length(remaining_nodes)
    assert Enum.sort(visible_from_new) == Enum.sort(remaining_nodes)
    
    # Verify that all remaining nodes can see the new node
    Enum.each(remaining_nodes, fn node ->
      {:ok, visible} = DistributedTesting.run_on_node(node, Node, :list, [])
      assert new_node in visible
    end)
  end
end