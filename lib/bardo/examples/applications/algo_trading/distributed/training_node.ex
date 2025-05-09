defmodule Bardo.Examples.Applications.AlgoTrading.Distributed.TrainingNode do
  @moduledoc """
  Training node for distributed algorithmic trading.
  
  This module implements a training node that:
  - Connects to the coordinator
  - Processes training jobs
  - Runs evolutionary algorithms
  - Reports results back to the coordinator
  """
  
  use GenServer
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  alias Bardo.Examples.Applications.AlgoTrading.Distributed.Coordinator
  
  # Default configuration
  @default_config %{
    node_name: nil,
    coordinator_node: nil,
    heartbeat_interval: 5000,  # 5 seconds
    reconnect_interval: 10000,  # 10 seconds
    max_concurrent_jobs: 1,
    capabilities: %{
      ram: System.schedulers_online() * 2,  # Estimated in GB
      cpu_cores: System.schedulers_online()
    }
  }
  
  # Client API
  
  @doc """
  Start the training node process.
  
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
  Connect to a coordinator node.
  
  ## Parameters
  
  - coordinator_node: Name of the coordinator node
  
  ## Returns
  
  - `:ok` - If connection succeeds
  - `{:error, reason}` - If connection fails
  """
  def connect_to_coordinator(coordinator_node) do
    GenServer.call(__MODULE__, {:connect_to_coordinator, coordinator_node})
  end
  
  @doc """
  Disconnect from the coordinator node.
  
  ## Returns
  
  - `:ok` - Always returns ok
  """
  def disconnect_from_coordinator do
    GenServer.call(__MODULE__, :disconnect_from_coordinator)
  end
  
  @doc """
  Get the current status of the training node.
  
  ## Returns
  
  - Status map with node information
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
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
      coordinator: nil,
      connected: false,
      status: :initializing,
      current_jobs: %{},
      job_results: %{},
      last_coordinator_ping: nil
    }
    
    # Set up node monitoring
    Node.monitor_nodes(true)
    
    # Schedule heartbeat if coordinator is provided
    if config.coordinator_node do
      schedule_heartbeat(config.heartbeat_interval)
      spawn(fn -> connect_to_coordinator(config.coordinator_node) end)
      state = %{state | coordinator: config.coordinator_node}
    end
    
    # Initialize EPMD if not already started
    :net_kernel.start([config.node_name, :shortnames])
    
    # Node is ready
    state = %{state | status: :ready}
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call({:connect_to_coordinator, coordinator_node}, _from, state) do
    if Node.connect(coordinator_node) do
      # Register with coordinator
      case Coordinator.register_node(state.config.node_name, :training, state.config.capabilities) do
        :ok ->
          Logger.info("Successfully connected to coordinator #{coordinator_node}")
          
          # Update state
          new_state = %{state | 
            coordinator: coordinator_node,
            connected: true,
            last_coordinator_ping: DateTime.utc_now()
          }
          
          # Start heartbeat
          schedule_heartbeat(state.config.heartbeat_interval)
          
          {:reply, :ok, new_state}
          
        {:error, reason} ->
          Logger.error("Failed to register with coordinator: #{inspect(reason)}")
          {:reply, {:error, reason}, state}
      end
    else
      Logger.error("Failed to connect to coordinator node #{coordinator_node}")
      {:reply, {:error, "Connection failed"}, state}
    end
  end
  
  @impl GenServer
  def handle_call(:disconnect_from_coordinator, _from, state) do
    if state.coordinator && state.connected do
      # Unregister from coordinator
      Coordinator.unregister_node(state.config.node_name)
      
      # Update state
      new_state = %{state | 
        connected: false,
        last_coordinator_ping: nil
      }
      
      Logger.info("Disconnected from coordinator #{state.coordinator}")
      {:reply, :ok, new_state}
    else
      # Not connected
      {:reply, :ok, state}
    end
  end
  
  @impl GenServer
  def handle_call(:get_status, _from, state) do
    # Build status response
    status = %{
      node: state.config.node_name,
      status: state.status,
      coordinator: state.coordinator,
      connected: state.connected,
      capabilities: state.config.capabilities,
      jobs: %{
        current: map_size(state.current_jobs),
        completed: map_size(state.job_results)
      },
      time: DateTime.utc_now()
    }
    
    {:reply, status, state}
  end
  
  @impl GenServer
  def handle_cast({:assign_training_job, job_id, job_config}, state) do
    if map_size(state.current_jobs) >= state.config.max_concurrent_jobs do
      Logger.warning("Received job assignment but already at max capacity")
      {:noreply, state}
    else
      # Start job processing (in separate process)
      spawn_link(fn -> process_training_job(job_id, job_config, state) end)
      
      # Update state
      current_jobs = Map.put(state.current_jobs, job_id, %{
        id: job_id,
        config: job_config,
        started_at: DateTime.utc_now(),
        status: :running
      })
      
      new_state = %{state | current_jobs: current_jobs, status: :training}
      
      Logger.info("Started training job #{job_id}")
      {:noreply, new_state}
    end
  end
  
  @impl GenServer
  def handle_info({:heartbeat, interval}, state) do
    if state.coordinator && state.connected do
      # Send heartbeat to coordinator by pinging
      connected = case Node.ping(state.coordinator) do
        :pong ->
          Logger.debug("Heartbeat sent to coordinator #{state.coordinator}")
          true
          
        :pang ->
          Logger.warning("Coordinator #{state.coordinator} not responding to heartbeat")
          schedule_reconnect(state.config.reconnect_interval)
          false
      end
      
      # Update state
      new_state = %{state | 
        connected: connected,
        last_coordinator_ping: if(connected, do: DateTime.utc_now(), else: state.last_coordinator_ping)
      }
      
      # Schedule next heartbeat
      schedule_heartbeat(interval)
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_info({:reconnect, coordinator_node}, state) do
    if !state.connected do
      Logger.info("Attempting to reconnect to coordinator #{coordinator_node}")
      
      # Attempt to reconnect and register
      spawn(fn -> connect_to_coordinator(coordinator_node) end)
    end
    
    {:noreply, state}
  end
  
  @impl GenServer
  def handle_info({:training_complete, job_id, result}, state) do
    # Update job status
    current_jobs = Map.delete(state.current_jobs, job_id)
    job_results = Map.put(state.job_results, job_id, %{
      id: job_id,
      result: result,
      completed_at: DateTime.utc_now()
    })
    
    # Update node status if no more jobs
    status = if map_size(current_jobs) == 0, do: :ready, else: :training
    
    # Update state
    new_state = %{state | 
      current_jobs: current_jobs,
      job_results: job_results,
      status: status
    }
    
    # Notify coordinator
    if state.coordinator && state.connected do
      send({Coordinator, state.coordinator}, {:training_complete, job_id, state.config.node_name, result})
    end
    
    Logger.info("Training job #{job_id} completed")
    {:noreply, new_state}
  end
  
  @impl GenServer
  def handle_info({:nodedown, node_name}, state) do
    if node_name == state.coordinator do
      # Coordinator is down
      Logger.warning("Coordinator node #{node_name} is down")
      
      # Update state
      new_state = %{state | connected: false}
      
      # Schedule reconnection attempt
      schedule_reconnect(state.config.reconnect_interval)
      
      {:noreply, new_state}
    else
      {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_info({:nodeup, node_name}, state) do
    if node_name == state.coordinator && !state.connected do
      # Coordinator is back up
      Logger.info("Coordinator node #{node_name} is back up")
      
      # Attempt to reconnect and register
      spawn(fn -> connect_to_coordinator(node_name) end)
    end
    
    {:noreply, state}
  end
  
  # Private helper functions
  
  # Schedule a heartbeat check
  defp schedule_heartbeat(interval) do
    Process.send_after(self(), {:heartbeat, interval}, interval)
  end
  
  # Schedule a reconnection attempt
  defp schedule_reconnect(interval) do
    Process.send_after(self(), {:reconnect, self()}, interval)
  end
  
  # Process a training job
  defp process_training_job(job_id, job_config, state) do
    Logger.info("Processing training job #{job_id}")
    
    # Run the training algorithm based on job configuration
    result = case run_training_algorithm(job_config) do
      {:ok, agent_result} ->
        # If training succeeded, store the agent
        case store_trained_agent(job_id, agent_result, job_config) do
          {:ok, agent_id} ->
            %{
              status: :success,
              agent_id: agent_id,
              performance: agent_result.performance
            }
            
          {:error, reason} ->
            %{
              status: :partial_failure,
              error: "Failed to store agent: #{inspect(reason)}",
              raw_result: agent_result
            }
        end
        
      {:error, reason} ->
        %{
          status: :failure,
          error: reason
        }
    end
    
    # Notify the main process
    send(self(), {:training_complete, job_id, result})
  end
  
  # Run a training algorithm based on configuration
  defp run_training_algorithm(job_config) do
    # Extract configuration
    algorithm = Map.get(job_config, :algorithm, :evolutionary)
    instrument = Map.get(job_config, :instrument, "EURUSD")
    timeframe = Map.get(job_config, :timeframe, "M15")
    population_size = Map.get(job_config, :population_size, 100)
    generations = Map.get(job_config, :generations, 100)
    
    # In a real implementation, this would use the Bardo framework
    # For now, just simulate a training process
    
    # Simulate training time based on complexity
    training_time = population_size * generations * 0.001
    :timer.sleep(trunc(training_time))
    
    # Create a mock agent result
    mock_agent = %{
      genotype: create_mock_genotype(),
      metadata: %{
        instrument: instrument,
        timeframe: timeframe,
        training_params: %{
          algorithm: algorithm,
          population_size: population_size,
          generations: generations
        },
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      performance: %{
        profit_loss: :rand.uniform() * 1000,
        win_rate: :rand.uniform(),
        trades: trunc(:rand.uniform() * 100)
      }
    }
    
    {:ok, mock_agent}
  end
  
  # Store a trained agent
  defp store_trained_agent(job_id, agent_result, job_config) do
    # Generate a unique agent ID
    agent_id = "agent_#{job_id}_#{:erlang.system_time(:millisecond)}"
    
    # Extract agent information
    genotype = agent_result.genotype
    metadata = Map.merge(agent_result.metadata, %{
      job_id: job_id,
      performance: agent_result.performance
    })
    
    # Store locally
    file_path = "priv/market_data/agent_repository/#{agent_id}.json"
    case AgentSerializer.save_agent(genotype, file_path, metadata) do
      :ok ->
        # If a coordinator is connected, also store there
        if process_alive?(Coordinator) do
          case Coordinator.store_agent(agent_id, genotype, metadata) do
            :ok -> {:ok, agent_id}
            {:error, reason} -> {:error, reason}
          end
        else
          {:ok, agent_id}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Check if a process is alive
  defp process_alive?(module) do
    case Process.whereis(module) do
      nil -> false
      pid -> Process.alive?(pid)
    end
  end
  
  # Create a mock genotype for testing
  defp create_mock_genotype do
    %{
      neurons: %{
        "input_1" => %{layer: :input, activation_function: :sigmoid},
        "input_2" => %{layer: :input, activation_function: :sigmoid},
        "hidden_1" => %{layer: :hidden, activation_function: :tanh},
        "hidden_2" => %{layer: :hidden, activation_function: :tanh},
        "output_1" => %{layer: :output, activation_function: :tanh}
      },
      connections: %{
        "conn_1" => %{from_id: "input_1", to_id: "hidden_1", weight: 0.5},
        "conn_2" => %{from_id: "input_1", to_id: "hidden_2", weight: -0.3},
        "conn_3" => %{from_id: "input_2", to_id: "hidden_1", weight: 0.2},
        "conn_4" => %{from_id: "input_2", to_id: "hidden_2", weight: 0.7},
        "conn_5" => %{from_id: "hidden_1", to_id: "output_1", weight: 0.6},
        "conn_6" => %{from_id: "hidden_2", to_id: "output_1", weight: -0.4}
      }
    }
  end
end