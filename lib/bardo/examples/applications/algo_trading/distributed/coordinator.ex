defmodule Bardo.Examples.Applications.AlgoTrading.Distributed.Coordinator do
  @moduledoc """
  Coordinator node for distributed algorithmic trading.
  
  This module implements the coordinator node that manages:
  - Training node registration and task distribution
  - Execution node management and monitoring
  - Agent repository and synchronization
  - Performance tracking and reporting
  """
  
  use GenServer
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  
  # Node types
  @node_type_coordinator :coordinator
  @node_type_training :training
  @node_type_execution :execution
  
  # Default configuration
  @default_config %{
    node_name: nil,
    node_type: @node_type_coordinator,
    heartbeat_interval: 5000,  # 5 seconds
    status_check_interval: 30000,  # 30 seconds
    reconnect_interval: 10000,  # 10 seconds
    repository_path: "priv/market_data/agent_repository",
    max_training_nodes: 10,
    max_execution_nodes: 10
  }
  
  # Client API
  
  @doc """
  Start the coordinator process.
  
  ## Parameters
  
  - opts: Configuration options
  
  ## Returns
  
  - `{:ok, pid}` - PID of the started process
  - `{:error, reason}` - If startup fails
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Register a new node with the coordinator.
  
  ## Parameters
  
  - node_name: Name of the node to register
  - node_type: Type of the node (:training or :execution)
  - capabilities: Map of node capabilities and resources
  
  ## Returns
  
  - `:ok` - If registration succeeds
  - `{:error, reason}` - If registration fails
  """
  def register_node(node_name, node_type, capabilities \\ %{}) do
    GenServer.call(__MODULE__, {:register_node, node_name, node_type, capabilities})
  end
  
  @doc """
  Unregister a node from the coordinator.
  
  ## Parameters
  
  - node_name: Name of the node to unregister
  
  ## Returns
  
  - `:ok` - If unregistration succeeds
  - `{:error, reason}` - If unregistration fails
  """
  def unregister_node(node_name) do
    GenServer.call(__MODULE__, {:unregister_node, node_name})
  end
  
  @doc """
  Get the current status of the distributed system.
  
  ## Returns
  
  - Status map with cluster information
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end
  
  @doc """
  Start a distributed training job.
  
  ## Parameters
  
  - job_config: Configuration for the training job
  
  ## Returns
  
  - `{:ok, job_id}` - ID of the started job
  - `{:error, reason}` - If job start fails
  """
  def start_training_job(job_config) do
    GenServer.call(__MODULE__, {:start_training_job, job_config})
  end
  
  @doc """
  Deploy a trained agent to execution nodes.
  
  ## Parameters
  
  - agent_id: ID of the agent to deploy
  - deployment_config: Configuration for deployment
  
  ## Returns
  
  - `{:ok, deployment_id}` - ID of the deployment
  - `{:error, reason}` - If deployment fails
  """
  def deploy_agent(agent_id, deployment_config) do
    GenServer.call(__MODULE__, {:deploy_agent, agent_id, deployment_config})
  end
  
  @doc """
  Store an agent in the repository.
  
  ## Parameters
  
  - agent_id: ID for the agent
  - genotype: Agent genotype to store
  - metadata: Additional metadata
  
  ## Returns
  
  - `:ok` - If storage succeeds
  - `{:error, reason}` - If storage fails
  """
  def store_agent(agent_id, genotype, metadata \\ %{}) do
    GenServer.call(__MODULE__, {:store_agent, agent_id, genotype, metadata})
  end
  
  @doc """
  Retrieve an agent from the repository.
  
  ## Parameters
  
  - agent_id: ID of the agent to retrieve
  
  ## Returns
  
  - `{:ok, {genotype, metadata}}` - The retrieved agent
  - `{:error, reason}` - If retrieval fails
  """
  def get_agent(agent_id) do
    GenServer.call(__MODULE__, {:get_agent, agent_id})
  end
  
  # Server callbacks
  
  @impl GenServer
  def init(opts) do
    # Merge provided options with defaults
    config = Map.merge(@default_config, Map.new(opts))
    
    # Set node name if not provided
    config = if config.node_name == nil do
      Map.put(config, :node_name, Node.self())
    else
      config
    end
    
    # Initialize state
    state = %{
      config: config,
      nodes: %{
        training: %{},  # training_node_name => node_info
        execution: %{}  # execution_node_name => node_info
      },
      jobs: %{},        # job_id => job_info
      deployments: %{}, # deployment_id => deployment_info
      agents: %{},      # agent_id => agent_info (in-memory cache)
      node_tasks: %{},  # node_name => [task_id]
      task_nodes: %{},  # task_id => node_name
      status: :ready
    }
    
    # Ensure repository path exists
    File.mkdir_p!(config.repository_path)
    
    # Start monitoring processes
    schedule_heartbeat(config.heartbeat_interval)
    schedule_status_check(config.status_check_interval)
    
    # Set up node monitoring
    Node.monitor_nodes(true, [:nodedown_reason])
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call({:register_node, node_name, node_type, capabilities}, _from, state) do
    # Validate node type
    if node_type != @node_type_training && node_type != @node_type_execution do
      {:reply, {:error, "Invalid node type"}, state}
    else
      # Create node info
      node_info = %{
        name: node_name,
        type: node_type,
        capabilities: capabilities,
        status: :ready,
        connected_at: DateTime.utc_now(),
        last_heartbeat: DateTime.utc_now(),
        current_tasks: []
      }
      
      # Add to appropriate node registry
      nodes = case node_type do
        @node_type_training ->
          Map.put(state.nodes.training, node_name, node_info)
          
        @node_type_execution ->
          Map.put(state.nodes.execution, node_name, node_info)
      end
      
      # Update state
      new_state = put_in(state.nodes, nodes)
      
      Logger.info("Node #{node_name} registered as #{node_type}")
      {:reply, :ok, new_state}
    end
  end
  
  @impl GenServer
  def handle_call({:unregister_node, node_name}, _from, state) do
    # Check if node exists in either registry
    training_nodes = Map.delete(state.nodes.training, node_name)
    execution_nodes = Map.delete(state.nodes.execution, node_name)
    
    # Update state
    new_state = put_in(state.nodes, %{
      training: training_nodes,
      execution: execution_nodes
    })
    
    Logger.info("Node #{node_name} unregistered")
    {:reply, :ok, new_state}
  end
  
  @impl GenServer
  def handle_call(:get_status, _from, state) do
    # Compute cluster statistics
    training_count = map_size(state.nodes.training)
    execution_count = map_size(state.nodes.execution)
    active_jobs = Enum.count(state.jobs, fn {_, job} -> job.status == :running end)
    active_deployments = Enum.count(state.deployments, fn {_, deploy} -> deploy.status == :active end)
    
    # Build status response
    status = %{
      coordinator: state.config.node_name,
      status: state.status,
      nodes: %{
        training: %{
          count: training_count,
          nodes: state.nodes.training
        },
        execution: %{
          count: execution_count,
          nodes: state.nodes.execution
        }
      },
      jobs: %{
        active: active_jobs,
        total: map_size(state.jobs)
      },
      deployments: %{
        active: active_deployments,
        total: map_size(state.deployments)
      },
      time: DateTime.utc_now()
    }
    
    {:reply, status, state}
  end
  
  @impl GenServer
  def handle_call({:start_training_job, job_config}, _from, state) do
    # Generate job ID
    job_id = "job_#{:erlang.system_time(:millisecond)}"
    
    # Select available training nodes
    available_nodes = Enum.filter(state.nodes.training, fn {_, node} -> 
      node.status == :ready
    end)
    
    if Enum.empty?(available_nodes) do
      {:reply, {:error, "No available training nodes"}, state}
    else
      # Create job record
      job = %{
        id: job_id,
        config: job_config,
        status: :initializing,
        nodes: [],
        started_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now(),
        result: nil
      }
      
      # Assign to state
      new_state = put_in(state.jobs[job_id], job)
      
      # Dispatch job to selected nodes (async)
      spawn(fn -> distribute_training_job(job_id, job_config, available_nodes) end)
      
      Logger.info("Training job #{job_id} started")
      {:reply, {:ok, job_id}, new_state}
    end
  end
  
  @impl GenServer
  def handle_call({:deploy_agent, agent_id, deployment_config}, _from, state) do
    # Check if agent exists
    case get_agent_from_repository(agent_id, state.config.repository_path) do
      {:ok, {genotype, metadata}} ->
        # Generate deployment ID
        deployment_id = "deploy_#{:erlang.system_time(:millisecond)}"
        
        # Select available execution nodes
        available_nodes = Enum.filter(state.nodes.execution, fn {_, node} -> 
          node.status == :ready
        end)
        
        if Enum.empty?(available_nodes) do
          {:reply, {:error, "No available execution nodes"}, state}
        else
          # Create deployment record
          deployment = %{
            id: deployment_id,
            agent_id: agent_id,
            config: deployment_config,
            status: :initializing,
            nodes: [],
            started_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
          
          # Assign to state
          new_state = put_in(state.deployments[deployment_id], deployment)
          
          # Dispatch deployment to selected nodes (async)
          spawn(fn -> 
            distribute_agent_deployment(deployment_id, agent_id, genotype, metadata, deployment_config, available_nodes)
          end)
          
          Logger.info("Agent #{agent_id} deployment #{deployment_id} started")
          {:reply, {:ok, deployment_id}, new_state}
        end
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl GenServer
  def handle_call({:store_agent, agent_id, genotype, metadata}, _from, state) do
    # Store agent in repository
    case store_agent_in_repository(agent_id, genotype, metadata, state.config.repository_path) do
      :ok ->
        # Update in-memory cache
        agent_info = %{
          id: agent_id,
          metadata: metadata,
          stored_at: DateTime.utc_now()
        }
        
        new_state = put_in(state.agents[agent_id], agent_info)
        
        {:reply, :ok, new_state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl GenServer
  def handle_call({:get_agent, agent_id}, _from, state) do
    # Try to get from repository
    case get_agent_from_repository(agent_id, state.config.repository_path) do
      {:ok, _} = result ->
        {:reply, result, state}
        
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end
  
  @impl GenServer
  def handle_info({:heartbeat, interval}, state) do
    # Send heartbeat to all nodes
    Enum.each(state.nodes.training, fn {node_name, _} ->
      send_heartbeat(node_name)
    end)
    
    Enum.each(state.nodes.execution, fn {node_name, _} ->
      send_heartbeat(node_name)
    end)
    
    # Schedule next heartbeat
    schedule_heartbeat(interval)
    
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info({:status_check, interval}, state) do
    # Check status of all nodes and mark offline nodes
    new_state = check_node_status(state)
    
    # Schedule next status check
    schedule_status_check(interval)
    
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_info({:nodedown, node_name, _reason}, state) do
    # Mark node as offline
    new_state = mark_node_offline(state, node_name)
    Logger.info("Node #{node_name} is down")
    
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_info({:nodeup, node_name}, state) do
    # Node is back online, it will need to re-register
    Logger.info("Node #{node_name} is up, waiting for registration")
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info({:training_complete, job_id, node_name, result}, state) do
    # Update job status
    if Map.has_key?(state.jobs, job_id) do
      job = state.jobs[job_id]
      
      updated_job = %{job |
        status: :completed,
        result: result,
        updated_at: DateTime.utc_now()
      }
      
      # Update state
      new_state = put_in(state.jobs[job_id], updated_job)
      
      Logger.info("Training job #{job_id} completed on node #{node_name}")
      {:noreply, new_state}
    else
      Logger.warning("Received training completion for unknown job #{job_id} from node #{node_name}")
      {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_info({:deployment_status, deployment_id, node_name, status}, state) do
    # Update deployment status
    if Map.has_key?(state.deployments, deployment_id) do
      deployment = state.deployments[deployment_id]
      
      updated_deployment = %{deployment |
        status: status,
        updated_at: DateTime.utc_now()
      }
      
      # Update state
      new_state = put_in(state.deployments[deployment_id], updated_deployment)
      
      Logger.info("Deployment #{deployment_id} status updated to #{status} on node #{node_name}")
      {:noreply, new_state}
    else
      Logger.warning("Received status for unknown deployment #{deployment_id} from node #{node_name}")
      {:noreply, state}
    end
  end
  
  # Private helper functions
  
  # Schedule a heartbeat check
  defp schedule_heartbeat(interval) do
    Process.send_after(self(), {:heartbeat, interval}, interval)
  end
  
  # Schedule a status check
  defp schedule_status_check(interval) do
    Process.send_after(self(), {:status_check, interval}, interval)
  end
  
  # Send a heartbeat to a node
  defp send_heartbeat(node_name) do
    if Node.connect(node_name) do
      :ok
    else
      Logger.warning("Failed to connect to node #{node_name} for heartbeat")
    end
  end
  
  # Check status of all nodes
  defp check_node_status(state) do
    # Check training nodes
    training_nodes = Enum.reduce(state.nodes.training, %{}, fn {node_name, node}, acc ->
      if Node.ping(node_name) == :pong do
        # Node is up
        last_heartbeat = DateTime.utc_now()
        updated_node = %{node | last_heartbeat: last_heartbeat, status: :ready}
        Map.put(acc, node_name, updated_node)
      else
        # Node is down
        updated_node = %{node | status: :offline}
        Map.put(acc, node_name, updated_node)
      end
    end)
    
    # Check execution nodes
    execution_nodes = Enum.reduce(state.nodes.execution, %{}, fn {node_name, node}, acc ->
      if Node.ping(node_name) == :pong do
        # Node is up
        last_heartbeat = DateTime.utc_now()
        updated_node = %{node | last_heartbeat: last_heartbeat, status: :ready}
        Map.put(acc, node_name, updated_node)
      else
        # Node is down
        updated_node = %{node | status: :offline}
        Map.put(acc, node_name, updated_node)
      end
    end)
    
    # Update state
    put_in(state.nodes, %{
      training: training_nodes,
      execution: execution_nodes
    })
  end
  
  # Mark a node as offline
  defp mark_node_offline(state, node_name) do
    # Check if it's a training node
    training_nodes = if Map.has_key?(state.nodes.training, node_name) do
      node = state.nodes.training[node_name]
      updated_node = %{node | status: :offline}
      Map.put(state.nodes.training, node_name, updated_node)
    else
      state.nodes.training
    end
    
    # Check if it's an execution node
    execution_nodes = if Map.has_key?(state.nodes.execution, node_name) do
      node = state.nodes.execution[node_name]
      updated_node = %{node | status: :offline}
      Map.put(state.nodes.execution, node_name, updated_node)
    else
      state.nodes.execution
    end
    
    # Update state
    put_in(state.nodes, %{
      training: training_nodes,
      execution: execution_nodes
    })
  end
  
  # Distribute a training job to nodes
  defp distribute_training_job(job_id, job_config, available_nodes) do
    # Currently just uses the first available node
    # In a production system, would distribute across multiple nodes
    {node_name, _} = List.first(available_nodes)
    
    if Node.connect(node_name) do
      # Update node with task assignment
      GenServer.cast({__MODULE__, node_name}, {:assign_training_job, job_id, job_config})
    else
      Logger.error("Failed to connect to node #{node_name} for job distribution")
    end
  end
  
  # Distribute agent deployment to nodes
  defp distribute_agent_deployment(deployment_id, agent_id, genotype, metadata, config, available_nodes) do
    # Currently just uses the first available node
    # In a production system, would distribute across multiple nodes
    {node_name, _} = List.first(available_nodes)
    
    if Node.connect(node_name) do
      # Update node with deployment assignment
      GenServer.cast({__MODULE__, node_name}, {:deploy_agent, deployment_id, agent_id, genotype, metadata, config})
    else
      Logger.error("Failed to connect to node #{node_name} for deployment")
    end
  end
  
  # Store an agent in the repository
  defp store_agent_in_repository(agent_id, genotype, metadata, repository_path) do
    # Generate file path
    file_path = Path.join(repository_path, "#{agent_id}.json")
    
    # Serialize and store
    AgentSerializer.save_agent(genotype, file_path, metadata)
  end
  
  # Get an agent from the repository
  defp get_agent_from_repository(agent_id, repository_path) do
    # Generate file path
    file_path = Path.join(repository_path, "#{agent_id}.json")
    
    # Load agent
    AgentSerializer.load_agent(file_path)
  end
end