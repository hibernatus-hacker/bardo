defmodule Bardo.Examples.Applications.AlgoTrading.DistributedTraining do
  @moduledoc """
  Distributed training for algorithmic trading neural networks.
  
  This module implements distributed training capabilities for evolutionary
  optimization of trading algorithms. It leverages Elixir's built-in distribution
  to parallelize the training process across multiple nodes.
  
  Key features:
  - Island-based evolutionary optimization
  - Migration of best individuals between nodes
  - Distributed evaluation of trading strategies
  - Fault tolerance with automatic recovery
  - Dynamic scaling of compute resources
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding
  require Logger
  
  @doc """
  Start distributed training of trading agents across multiple nodes.
  
  ## Parameters
  
  - experiment_id: Unique identifier for the experiment
  - config_opts: Configuration options (see AlgoTrading.configure/2)
  - nodes: List of node names to distribute work to (default: all connected nodes)
  - islands: Number of population islands (default: number of nodes)
  - migration_interval: How often to migrate individuals between islands (default: 10 generations)
  - migration_rate: Percentage of population to migrate (default: 0.1)
  
  ## Returns
  
  {:ok, experiment_id} if training started successfully, {:error, reason} otherwise.
  """
  def start_distributed_training(experiment_id, config_opts, opts \\ []) do
    # Get connected nodes or use provided list
    nodes = Keyword.get(opts, :nodes, Node.list())
    
    # If no nodes are connected, run locally
    if nodes == [] do
      Logger.warning("No connected nodes found. Running training on local node only.")
      nodes = [Node.self()]
    end
    
    # Configuration
    islands = Keyword.get(opts, :islands, length(nodes))
    migration_interval = Keyword.get(opts, :migration_interval, 10)
    migration_rate = Keyword.get(opts, :migration_rate, 0.1)
    
    Logger.info("Starting distributed training on #{length(nodes)} nodes with #{islands} islands")
    Logger.info("Nodes: #{inspect(nodes)}")
    
    # Create coordinator state
    coordinator_state = %{
      experiment_id: experiment_id,
      nodes: nodes,
      islands: islands,
      migration_interval: migration_interval,
      migration_rate: migration_rate,
      generation: 0,
      island_states: %{},
      status: :initializing,
      start_time: System.monotonic_time(:second)
    }
    
    # Store coordinator state in the DB
    store_coordinator_state(coordinator_state)
    
    # Create island configurations
    island_configs = create_island_configs(experiment_id, config_opts, islands)
    
    # Distribute islands to nodes (round-robin)
    node_assignments = distribute_islands_to_nodes(islands, nodes)
    
    # Start training on each node
    island_results = Enum.map(0..(islands-1), fn island_idx ->
      node = Map.get(node_assignments, island_idx)
      island_config = Enum.at(island_configs, island_idx)
      
      # Start the island on the assigned node
      case start_island_on_node(node, island_idx, island_config) do
        {:ok, island_pid} ->
          # Success - update the coordinator state
          island_state = %{
            island_idx: island_idx,
            node: node,
            pid: island_pid,
            status: :running,
            generation: 0,
            last_migration: 0,
            best_fitness: nil
          }
          
          {:ok, island_state}
          
        {:error, reason} ->
          # Failed to start island
          Logger.error("Failed to start island #{island_idx} on node #{node}: #{inspect(reason)}")
          {:error, {island_idx, reason}}
      end
    end)
    
    # Check if all islands started successfully
    case Enum.split_with(island_results, fn result -> elem(result, 0) == :ok end) do
      {successful, []} ->
        # All islands started successfully
        island_states = 
          successful
          |> Enum.map(fn {:ok, state} -> state end)
          |> Enum.reduce(%{}, fn state, acc -> Map.put(acc, state.island_idx, state) end)
        
        # Update coordinator state
        updated_state = %{coordinator_state | 
          island_states: island_states,
          status: :running
        }
        
        store_coordinator_state(updated_state)
        
        # Start coordinator process to monitor and manage islands
        spawn_link(fn -> coordinate_training(updated_state) end)
        
        {:ok, experiment_id}
        
      {successful, failed} ->
        # Some islands failed to start
        failed_islands = Enum.map(failed, fn {:error, {idx, _}} -> idx end)
        
        Logger.error("Failed to start islands: #{inspect(failed_islands)}")
        
        # Cleanup successful islands
        Enum.each(successful, fn {:ok, state} ->
          cleanup_island(state.node, state.island_idx)
        end)
        
        {:error, "Failed to start all islands: #{inspect(failed_islands)}"}
    end
  end
  
  @doc """
  Stop distributed training across all nodes.
  
  ## Parameters
  
  - experiment_id: ID of the experiment to stop
  
  ## Returns
  
  :ok if stopped successfully, {:error, reason} otherwise.
  """
  def stop_distributed_training(experiment_id) do
    # Get coordinator state
    case get_coordinator_state(experiment_id) do
      {:ok, coordinator_state} ->
        # Stop each island
        Enum.each(coordinator_state.island_states, fn {_idx, state} ->
          cleanup_island(state.node, state.island_idx)
        end)
        
        # Update coordinator state
        updated_state = %{coordinator_state | 
          status: :stopped,
          end_time: System.monotonic_time(:second)
        }
        
        store_coordinator_state(updated_state)
        
        :ok
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get the current status of distributed training.
  
  ## Parameters
  
  - experiment_id: ID of the experiment to check
  
  ## Returns
  
  A map with the current status or {:error, reason} if not found.
  """
  def get_training_status(experiment_id) do
    case get_coordinator_state(experiment_id) do
      {:ok, coordinator_state} ->
        # Calculate elapsed time
        current_time = System.monotonic_time(:second)
        elapsed = current_time - coordinator_state.start_time
        
        # Build status report
        %{
          experiment_id: experiment_id,
          status: coordinator_state.status,
          islands: map_size(coordinator_state.island_states),
          nodes: coordinator_state.nodes,
          generation: coordinator_state.generation,
          elapsed_time: elapsed,
          islands_status: map_island_status(coordinator_state.island_states),
          start_time: coordinator_state.start_time
        }
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Get the best trading agent from distributed training.
  
  ## Parameters
  
  - experiment_id: ID of the experiment
  
  ## Returns
  
  {:ok, best_genotype} if found, {:error, reason} otherwise.
  """
  def get_best_agent(experiment_id) do
    case get_coordinator_state(experiment_id) do
      {:ok, coordinator_state} ->
        # Get best fitness from each island
        best_agents = Enum.map(coordinator_state.island_states, fn {_idx, state} ->
          get_island_best_agent(state.node, state.island_idx)
        end)
        
        # Filter out errors and find the best overall
        case Enum.split_with(best_agents, fn result -> elem(result, 0) == :ok end) do
          {successful, _failed} ->
            if successful != [] do
              # Find the best agent by fitness (first element of fitness vector is profit)
              best_agent = Enum.max_by(successful, fn {:ok, agent} -> 
                case agent.fitness do
                  [profit | _] when is_number(profit) -> profit
                  _ -> -1000.0
                end
              end)
              
              best_agent
            else
              {:error, "No successful agent found"}
            end
            
          _ ->
            {:error, "Failed to get best agent from any island"}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Create configurations for each island
  defp create_island_configs(experiment_id, base_config, islands) do
    # Split the population evenly across islands
    total_population = Map.get(base_config, :population_size, 100)
    island_population = max(10, div(total_population, islands))
    
    # Create a configuration for each island with variations
    Enum.map(0..(islands-1), fn island_idx ->
      # Create a unique ID for this island
      island_id = :"#{experiment_id}_island_#{island_idx}"
      
      # Introduce some variation between islands
      # Different mutation rates, selection pressure, etc.
      island_config = Map.merge(base_config, %{
        id: island_id,
        island_idx: island_idx,
        population_size: island_population,
        mutation_rate: adjust_mutation_rate(base_config.mutation_rate || 0.1, island_idx, islands),
        tournament_size: adjust_tournament_size(base_config.tournament_size || 5, island_idx, islands),
        elite_fraction: adjust_elite_fraction(base_config.elite_fraction || 0.1, island_idx, islands),
        # Use substrate encoding for some islands
        use_substrate: island_idx < div(islands, 2)
      })
      
      island_config
    end)
  end
  
  # Distribute islands to nodes (round-robin)
  defp distribute_islands_to_nodes(islands, nodes) do
    Enum.reduce(0..(islands-1), %{}, fn island_idx, acc ->
      node_idx = rem(island_idx, length(nodes))
      node = Enum.at(nodes, node_idx)
      Map.put(acc, island_idx, node)
    end)
  end
  
  # Start an island on a remote node
  defp start_island_on_node(node, island_idx, island_config) do
    # Define the function to run on the remote node
    remote_fun = fn ->
      # Create a process to manage this island
      spawn_link(fn ->
        run_island(island_idx, island_config)
      end)
    end
    
    # Execute on remote node
    case :rpc.call(node, Kernel, :apply, [remote_fun, []]) do
      {:badrpc, reason} ->
        {:error, reason}
        
      pid when is_pid(pid) ->
        {:ok, pid}
    end
  end
  
  # Run an island for distributed training
  defp run_island(island_idx, config) do
    island_id = config.id
    island_db_id = :"#{island_id}_db"
    
    Logger.info("Starting island #{island_idx} with ID #{island_id}")
    
    # Initialize a separate DB for this island
    initialize_island_db(island_db_id)
    
    # Modify configuration for substrate encoding if enabled
    config = if config.use_substrate do
      # Use substrate encoding for this island
      substrate_config = Map.put(config, :genotype_initializer, fn ->
        SubstrateEncoding.create_substrate_genotype(%{
          input_time_points: 60,
          input_price_levels: 20,
          input_data_types: 10,
          hidden_layers: 2,
          hidden_neurons_per_layer: 20,
          output_neurons: 3
        })
      end)
      
      Map.put(substrate_config, :population_converter, fn price_data, indicators, genotype ->
        # Convert market data to substrate representation
        grid = SubstrateEncoding.convert_price_data_to_substrate(
          price_data, indicators, 60, 20, 10
        )
        
        # Flatten to neuron inputs
        SubstrateEncoding.flatten_substrate_grid(grid, genotype)
      end)
    else
      config
    end
    
    # Store island configuration
    store_island_state(island_db_id, %{
      island_idx: island_idx,
      config: config,
      generation: 0,
      status: :initializing,
      start_time: System.monotonic_time(:second),
      best_agent: nil,
      best_fitness: nil,
      last_migration: 0
    })
    
    # Start the evolutionary process
    {:ok, _} = PolisMgr.setup(config)
    
    # Update state to running
    update_island_state(island_db_id, %{status: :running})
    
    # Run the evolution loop
    run_island_evolution(island_idx, island_db_id, config)
  end
  
  # Main evolution loop for an island
  defp run_island_evolution(island_idx, island_db_id, config) do
    # Get current island state
    {:ok, island_state} = get_island_state(island_db_id)
    
    # Check if we should continue running
    if island_state.status == :running do
      # Run one generation
      case run_generation(island_idx, config) do
        {:ok, generation_results} ->
          # Update island state with results
          new_generation = island_state.generation + 1
          
          updated_state = Map.merge(island_state, %{
            generation: new_generation,
            best_agent: generation_results.best_agent,
            best_fitness: generation_results.best_fitness,
            population: generation_results.population
          })
          
          # Store updated state
          update_island_state(island_db_id, updated_state)
          
          # Check for migration
          if should_migrate?(updated_state, config) do
            # Handle migration
            handle_migration(island_idx, updated_state, config)
            
            # Update last migration time
            update_island_state(island_db_id, %{last_migration: new_generation})
          end
          
          # Continue evolution after a short delay
          :timer.sleep(100)
          run_island_evolution(island_idx, island_db_id, config)
          
        {:error, reason} ->
          # Handle error
          Logger.error("Error in island #{island_idx} generation: #{inspect(reason)}")
          
          # Update state to indicate error
          update_island_state(island_db_id, %{
            status: :error,
            error_reason: reason
          })
          
          # Retry after a delay
          :timer.sleep(5000)
          run_island_evolution(island_idx, island_db_id, config)
      end
    else
      # Island has been stopped
      Logger.info("Island #{island_idx} stopped with status #{island_state.status}")
    end
  end
  
  # Run a single generation of evolution
  defp run_generation(island_idx, config) do
    # Run one generation using PolisMgr
    case PolisMgr.evolve_generation(config.id) do
      {:ok, generation_data} ->
        # Extract results
        best_agent = Map.get(generation_data, :best_agent)
        best_fitness = Map.get(generation_data, :best_fitness)
        population = Map.get(generation_data, :population)
        
        Logger.info("Island #{island_idx} - Generation #{generation_data.generation} completed. Best fitness: #{inspect(best_fitness)}")
        
        {:ok, %{
          generation: generation_data.generation,
          best_agent: best_agent,
          best_fitness: best_fitness,
          population: population
        }}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Check if migration should happen
  defp should_migrate?(island_state, config) do
    migration_interval = Map.get(config, :migration_interval, 10)
    last_migration = Map.get(island_state, :last_migration, 0)
    
    # Migrate every migration_interval generations
    island_state.generation > 0 && 
    island_state.generation - last_migration >= migration_interval
  end
  
  # Handle migration of individuals between islands
  defp handle_migration(island_idx, island_state, config) do
    # Get migration parameters
    migration_rate = Map.get(config, :migration_rate, 0.1)
    experiment_id = config.id |> to_string() |> String.split("_island_") |> List.first() |> String.to_atom()
    
    # Get coordinator state
    case get_coordinator_state(experiment_id) do
      {:ok, coordinator_state} ->
        # Determine target island (usually the next one in sequence)
        islands_count = map_size(coordinator_state.island_states)
        target_idx = rem(island_idx + 1, islands_count)
        
        # Get target island state
        target_state = Map.get(coordinator_state.island_states, target_idx)
        
        if target_state do
          # Select individuals to migrate (best ones)
          migrants = select_migrants(island_state.population, migration_rate)
          
          # Send migrants to target island
          send_migrants(target_state.node, target_idx, migrants)
          
          Logger.info("Island #{island_idx} migrated #{length(migrants)} individuals to island #{target_idx}")
        end
        
      {:error, reason} ->
        Logger.error("Failed to get coordinator state for migration: #{inspect(reason)}")
    end
  end
  
  # Select individuals to migrate
  defp select_migrants(population, migration_rate) do
    # Calculate how many individuals to migrate
    count = max(1, trunc(length(population) * migration_rate))
    
    # Sort by fitness and take the best ones
    population
    |> Enum.sort_by(fn agent -> 
      case agent.fitness do
        [profit | _] when is_number(profit) -> -profit  # Negative for descending sort
        _ -> 0.0
      end
    end)
    |> Enum.take(count)
  end
  
  # Send migrants to target island
  defp send_migrants(target_node, target_idx, migrants) do
    # Function to run on target node
    remote_fun = fn ->
      # Get the island DB ID
      {:ok, target_state} = get_island_state_by_idx(target_idx)
      island_db_id = target_state.island_db_id
      
      # Update population with migrants (replace worst individuals)
      {:ok, current_state} = get_island_state(island_db_id)
      current_population = Map.get(current_state, :population, [])
      
      # Sort current population by fitness (ascending)
      sorted_population = Enum.sort_by(current_population, fn agent -> 
        case agent.fitness do
          [profit | _] when is_number(profit) -> profit
          _ -> -1000.0
        end
      end)
      
      # Replace worst individuals with migrants
      replaced_count = min(length(migrants), length(sorted_population))
      new_population = 
        Enum.drop(sorted_population, replaced_count) ++ 
        Enum.take(migrants, replaced_count)
      
      # Update island state
      update_island_state(island_db_id, %{
        population: new_population,
        migrants_received: replaced_count
      })
      
      # Apply changes to PolisMgr
      island_id = current_state.config.id
      PolisMgr.update_population(island_id, new_population)
      
      replaced_count
    end
    
    # Execute on target node
    case :rpc.call(target_node, Kernel, :apply, [remote_fun, []]) do
      {:badrpc, reason} ->
        Logger.error("Failed to send migrants to island #{target_idx}: #{inspect(reason)}")
        {:error, reason}
        
      replaced_count ->
        Logger.info("Island #{target_idx} received #{replaced_count} migrants")
        {:ok, replaced_count}
    end
  end
  
  # Get island state by index
  defp get_island_state_by_idx(island_idx) do
    # This function runs on the target node
    # It needs to find the island DB ID based on index
    
    # Check all DBs for matching island state
    all_dbs = :ets.all()
    
    matching_db = Enum.find(all_dbs, fn table ->
      case :ets.lookup(table, :island_state) do
        [{:island_state, state}] ->
          state.island_idx == island_idx
          
        _ ->
          false
      end
    end)
    
    case matching_db do
      nil ->
        {:error, "Island #{island_idx} not found"}
        
      db_id ->
        [{:island_state, state}] = :ets.lookup(db_id, :island_state)
        {:ok, Map.put(state, :island_db_id, db_id)}
    end
  end
  
  # Coordinate the distributed training process
  defp coordinate_training(coordinator_state) do
    # Get updated state
    {:ok, current_state} = get_coordinator_state(coordinator_state.experiment_id)
    
    # Check status
    case current_state.status do
      :running ->
        # Update generation count (max across islands)
        max_generation = Enum.reduce(current_state.island_states, 0, fn {_idx, state}, max_gen ->
          # Check island status
          island_state = 
            with node when is_atom(node) <- state.node,
                 true <- Node.ping(node) == :pong,
                 {:ok, remote_state} <- get_remote_island_state(node, state.island_idx) do
              # Node is alive and responding
              remote_state
            else
              _ -> 
                # Node is down or not responding
                handle_node_failure(current_state, state)
            end
          
          # Get the maximum generation across all islands
          max(max_gen, island_state.generation || 0)
        end)
        
        # Update coordinator state with new generation count
        updated_state = %{current_state | generation: max_generation}
        store_coordinator_state(updated_state)
        
        # Check if all islands are complete
        all_complete = Enum.all?(updated_state.island_states, fn {_idx, state} ->
          state.status == :complete || state.status == :error
        end)
        
        if all_complete do
          # All islands are complete, finalize the experiment
          finalize_experiment(updated_state)
        else
          # Continue coordination
          :timer.sleep(5000)  # Check every 5 seconds
          coordinate_training(updated_state)
        end
        
      :stopping ->
        # Stop all islands
        Enum.each(current_state.island_states, fn {_idx, state} ->
          cleanup_island(state.node, state.island_idx)
        end)
        
        # Update state to stopped
        updated_state = %{current_state | 
          status: :stopped,
          end_time: System.monotonic_time(:second)
        }
        
        store_coordinator_state(updated_state)
        
      _ ->
        # Already stopped or error
        :ok
    end
  end
  
  # Handle node failure
  defp handle_node_failure(coordinator_state, failed_state) do
    Logger.warning("Node #{failed_state.node} appears to be down. Migrating island #{failed_state.island_idx} to another node.")
    
    # Find an available node
    available_nodes = Enum.filter(coordinator_state.nodes, fn node -> 
      Node.ping(node) == :pong
    end)
    
    if available_nodes != [] do
      # Select a new node
      new_node = Enum.random(available_nodes)
      
      # Restore the island on the new node
      case restore_island_on_node(new_node, failed_state.island_idx, coordinator_state.experiment_id) do
        {:ok, new_pid} ->
          # Update island state
          updated_island_state = %{failed_state |
            node: new_node,
            pid: new_pid,
            status: :running
          }
          
          # Update coordinator state
          island_states = Map.put(coordinator_state.island_states, failed_state.island_idx, updated_island_state)
          updated_state = %{coordinator_state | island_states: island_states}
          store_coordinator_state(updated_state)
          
          Logger.info("Successfully migrated island #{failed_state.island_idx} to node #{new_node}")
          
          updated_island_state
          
        {:error, reason} ->
          Logger.error("Failed to migrate island #{failed_state.island_idx}: #{inspect(reason)}")
          %{failed_state | status: :error, error_reason: reason}
      end
    else
      Logger.error("No available nodes to migrate island #{failed_state.island_idx}")
      %{failed_state | status: :error, error_reason: "No available nodes"}
    end
  end
  
  # Restore an island on a new node after failure
  defp restore_island_on_node(node, island_idx, experiment_id) do
    # Get coordinator state
    {:ok, coordinator_state} = get_coordinator_state(experiment_id)
    
    # Get island configurations
    island_configs = create_island_configs(experiment_id, %{}, coordinator_state.islands)
    island_config = Enum.at(island_configs, island_idx)
    
    # Start a new island on the node
    start_island_on_node(node, island_idx, island_config)
  end
  
  # Finalize the experiment
  defp finalize_experiment(coordinator_state) do
    Logger.info("All islands completed. Finalizing experiment #{coordinator_state.experiment_id}")
    
    # Get the best agent from all islands
    {:ok, best_agent} = get_best_agent(coordinator_state.experiment_id)
    
    # Store the best agent in the experiment record
    experiment_record = %{
      id: coordinator_state.experiment_id,
      status: :complete,
      best_agent: best_agent,
      best_fitness: best_agent.fitness,
      islands: coordinator_state.islands,
      nodes: coordinator_state.nodes,
      generations: coordinator_state.generation,
      start_time: coordinator_state.start_time,
      end_time: System.monotonic_time(:second),
      duration: System.monotonic_time(:second) - coordinator_state.start_time
    }
    
    # Save the experiment record
    Models.store(:experiment, coordinator_state.experiment_id, experiment_record)
    
    # Update coordinator state
    updated_state = %{coordinator_state | 
      status: :complete,
      end_time: System.monotonic_time(:second)
    }
    
    store_coordinator_state(updated_state)
    
    Logger.info("Experiment #{coordinator_state.experiment_id} completed successfully")
    Logger.info("Best fitness: #{inspect(best_agent.fitness)}")
  end
  
  # Get remote island state
  defp get_remote_island_state(node, island_idx) do
    # Function to run on remote node
    remote_fun = fn ->
      get_island_state_by_idx(island_idx)
    end
    
    # Execute on remote node
    case :rpc.call(node, Kernel, :apply, [remote_fun, []]) do
      {:badrpc, reason} ->
        {:error, reason}
        
      result ->
        result
    end
  end
  
  # Cleanup an island
  defp cleanup_island(node, island_idx) do
    # Function to run on remote node
    remote_fun = fn ->
      case get_island_state_by_idx(island_idx) do
        {:ok, state} ->
          # Update state to stopping
          update_island_state(state.island_db_id, %{
            status: :stopping,
            end_time: System.monotonic_time(:second)
          })
          
          # Stop the PolisMgr experiment
          PolisMgr.stop(state.config.id)
          
          :ok
          
        {:error, reason} ->
          {:error, reason}
      end
    end
    
    # Execute on remote node
    :rpc.call(node, Kernel, :apply, [remote_fun, []])
  end
  
  # Get island best agent
  defp get_island_best_agent(node, island_idx) do
    # Function to run on remote node
    remote_fun = fn ->
      case get_island_state_by_idx(island_idx) do
        {:ok, state} ->
          # Return the best agent
          {:ok, state.best_agent}
          
        {:error, reason} ->
          {:error, reason}
      end
    end
    
    # Execute on remote node
    :rpc.call(node, Kernel, :apply, [remote_fun, []])
  end
  
  # Map island status to a report format
  defp map_island_status(island_states) do
    Enum.map(island_states, fn {idx, state} ->
      %{
        island: idx,
        node: state.node,
        status: state.status,
        generation: state.generation || 0,
        best_fitness: state.best_fitness
      }
    end)
  end
  
  # Create variations in mutation rate for different islands
  defp adjust_mutation_rate(base_rate, island_idx, islands) do
    # Create diversity in mutation rates
    # Some islands have higher mutation for exploration
    # Others have lower mutation for exploitation
    position = island_idx / (islands - 1)  # 0.0 to 1.0
    
    cond do
      position < 0.25 -> base_rate * 2.0  # High mutation (exploration)
      position > 0.75 -> base_rate * 0.5  # Low mutation (exploitation)
      true -> base_rate  # Standard mutation
    end
  end
  
  # Adjust tournament size based on island
  defp adjust_tournament_size(base_size, island_idx, islands) do
    position = island_idx / (islands - 1)  # 0.0 to 1.0
    
    cond do
      position < 0.3 -> max(2, base_size - 2)  # Lower selection pressure
      position > 0.7 -> base_size + 2  # Higher selection pressure
      true -> base_size  # Standard selection pressure
    end
  end
  
  # Adjust elite fraction based on island
  defp adjust_elite_fraction(base_fraction, island_idx, islands) do
    position = island_idx / (islands - 1)  # 0.0 to 1.0
    
    cond do
      position < 0.3 -> max(0.05, base_fraction - 0.05)  # Lower elitism
      position > 0.7 -> min(0.2, base_fraction + 0.05)   # Higher elitism
      true -> base_fraction  # Standard elitism
    end
  end
  
  # Initialize a separate database for an island
  defp initialize_island_db(db_id) do
    # Create an ETS table for this island
    :ets.new(db_id, [:set, :public, :named_table])
    
    # Initialize with empty state
    :ets.insert(db_id, {:island_state, %{}})
    
    :ok
  end
  
  # Store island state
  defp store_island_state(db_id, state) do
    :ets.insert(db_id, {:island_state, state})
    :ok
  end
  
  # Update island state (partial update)
  defp update_island_state(db_id, updates) do
    # Get current state
    [{:island_state, current_state}] = :ets.lookup(db_id, :island_state)
    
    # Update with new values
    updated_state = Map.merge(current_state, updates)
    
    # Store updated state
    :ets.insert(db_id, {:island_state, updated_state})
    
    :ok
  end
  
  # Get current island state
  defp get_island_state(db_id) do
    case :ets.lookup(db_id, :island_state) do
      [{:island_state, state}] ->
        {:ok, state}
        
      _ ->
        {:error, "Island state not found"}
    end
  end
  
  # Store coordinator state
  defp store_coordinator_state(state) do
    Models.store(:distributed_training, state.experiment_id, state)
    :ok
  end
  
  # Get coordinator state
  defp get_coordinator_state(experiment_id) do
    Models.read(experiment_id, :distributed_training)
  end
end