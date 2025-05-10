defmodule Bardo.Examples.Applications.AlgoTrading.AgentRepository do
  @moduledoc """
  Module for storing and retrieving trained trading agents by currency pair.
  
  This module provides functions for:
  - Organizing agents by currency pair
  - Storing agent metadata and performance information
  - Retrieving agents based on various criteria
  - Managing agent versions and backups
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  
  # Root directory for storing agents
  @agent_repository_dir "/home/user/Desktop/bardo/priv/market_data/agent_repository"
  
  @doc """
  Store a trained agent for a specific currency pair.
  
  ## Parameters
  
  - genotype: The agent's genotype to store
  - instrument: Instrument/currency pair (e.g., "EUR_USD", "BTC/USD")
  - metadata: Additional metadata to store with the agent
  - options: Additional options
    - `:filename` - Custom filename (default: auto-generated)
    - `:overwrite` - Whether to overwrite existing file (default: false)
    - `:subdirectory` - Custom subdirectory within the pair directory
  
  ## Returns
  
  - `{:ok, file_path}` - Path to the stored agent file
  - `{:error, reason}` - If storing fails
  """
  def store_agent(genotype, instrument, metadata, options \\ %{}) do
    # Ensure the repository directory exists
    File.mkdir_p!(@agent_repository_dir)
    
    # Normalize instrument name
    instrument_dir = normalize_instrument_name(instrument)
    
    # Create full directory path
    dir_path = case Map.get(options, :subdirectory) do
      nil -> Path.join(@agent_repository_dir, instrument_dir)
      subdir -> Path.join([@agent_repository_dir, instrument_dir, subdir])
    end
    
    # Ensure directory exists
    File.mkdir_p!(dir_path)
    
    # Generate filename if not provided
    filename = case Map.get(options, :filename) do
      nil -> 
        # Generate filename based on timestamp and performance
        perf = Map.get(metadata, "performance", 0.0)
        timestamp = DateTime.utc_now() |> DateTime.to_unix()
        "#{instrument_dir}_#{perf}_#{timestamp}.json"
        
      custom -> custom
    end
    
    # Full file path
    file_path = Path.join(dir_path, filename)
    
    # Check if file exists and handle overwrite option
    if File.exists?(file_path) && !Map.get(options, :overwrite, false) do
      {:error, "File already exists: #{file_path}. Use overwrite: true to force."}
    else
      # Add instrument to metadata if not present
      metadata = if Map.has_key?(metadata, "instrument") do
        metadata
      else
        Map.put(metadata, "instrument", instrument)
      end
      
      # Add storage timestamp
      metadata = Map.put(metadata, "stored_at", DateTime.utc_now() |> DateTime.to_iso8601())
      
      # Store the agent
      case AgentSerializer.save_agent(genotype, file_path, metadata) do
        :ok -> {:ok, file_path}
        error -> error
      end
    end
  end
  
  @doc """
  Retrieve an agent by ID or filename.
  
  ## Parameters
  
  - agent_id: ID or filename of the agent
  - instrument: Instrument/currency pair (optional, improves lookup speed)
  
  ## Returns
  
  - `{:ok, {genotype, metadata, file_path}}` - The retrieved agent
  - `{:error, reason}` - If retrieval fails
  """
  def get_agent(agent_id, instrument \\ nil) do
    # Try to find the agent file
    case find_agent_file(agent_id, instrument) do
      {:ok, file_path} ->
        # Load the agent
        case AgentSerializer.load_agent(file_path) do
          {:ok, {genotype, metadata}} ->
            {:ok, {genotype, metadata, file_path}}
            
          error -> error
        end
        
      error -> error
    end
  end
  
  @doc """
  List all agents for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument/currency pair
  - options: Additional options
    - `:subdirectory` - Subdirectory to search within
    - `:sort_by` - Sort field (`:performance`, `:date`, `:filename`) (default: `:date`)
    - `:sort_order` - Sort order (`:asc` or `:desc`) (default: `:desc`)
    - `:limit` - Maximum number of agents to return (default: all)
    - `:with_metadata` - Whether to include full metadata (default: false)
  
  ## Returns
  
  - `{:ok, agents}` - List of agent information
  - `{:error, reason}` - If listing fails
  """
  def list_agents(instrument, options \\ %{}) do
    # Normalize instrument name
    instrument_dir = normalize_instrument_name(instrument)
    
    # Determine directory path
    dir_path = case Map.get(options, :subdirectory) do
      nil -> Path.join(@agent_repository_dir, instrument_dir)
      subdir -> Path.join([@agent_repository_dir, instrument_dir, subdir])
    end
    
    # Check if directory exists
    if !File.exists?(dir_path) do
      {:ok, []}
    else
      # Find all JSON files
      files = Path.wildcard(Path.join(dir_path, "*.json"))
      
      # Map files to agent info
      agents = Enum.map(files, fn file_path ->
        # Get file stats
        stats = File.stat!(file_path)
        
        # Load metadata if requested
        metadata = if Map.get(options, :with_metadata, false) do
          case AgentSerializer.load_agent(file_path) do
            {:ok, {_genotype, metadata}} -> metadata
            _ -> %{}
          end
        else
          %{}
        end
        
        # Extract performance from filename or metadata
        performance = extract_performance(file_path, metadata)
        
        # Create agent info
        %{
          id: Path.basename(file_path, ".json"),
          file_path: file_path,
          size: stats.size,
          modified: stats.mtime,
          performance: performance,
          metadata: (if Map.get(options, :with_metadata, false), do: metadata, else: nil)
        }
      end)
      
      # Sort agents
      sorted_agents = sort_agents(agents, options)
      
      # Apply limit if specified
      limited_agents = if limit = Map.get(options, :limit) do
        Enum.take(sorted_agents, limit)
      else
        sorted_agents
      end
      
      {:ok, limited_agents}
    end
  end
  
  @doc """
  Get the best performing agent for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument/currency pair
  - options: Additional options
    - `:subdirectory` - Subdirectory to search within
    - `:min_trades` - Minimum number of trades (default: 0)
    - `:with_genotype` - Whether to include genotype (default: false)
  
  ## Returns
  
  - `{:ok, agent}` - Best agent information
  - `{:error, reason}` - If retrieval fails
  """
  def get_best_agent(instrument, options \\ %{}) do
    # List agents sorted by performance
    case list_agents(instrument, Map.merge(options, %{
      sort_by: :performance,
      sort_order: :desc,
      with_metadata: true,
      limit: 10  # Get top 10 to filter by min_trades
    })) do
      {:ok, agents} ->
        # Filter by minimum trades if specified
        filtered_agents = if min_trades = Map.get(options, :min_trades) do
          Enum.filter(agents, fn agent ->
            trades = get_in(agent, [:metadata, "total_trades"]) || 0
            trades >= min_trades
          end)
        else
          agents
        end
        
        # Get the best agent
        case List.first(filtered_agents) do
          nil -> {:error, "No agents found for #{instrument}"}
          agent ->
            if Map.get(options, :with_genotype, false) do
              # Load full agent with genotype
              case AgentSerializer.load_agent(agent.file_path) do
                {:ok, {genotype, _metadata}} ->
                  {:ok, Map.put(agent, :genotype, genotype)}
                  
                error -> error
              end
            else
              {:ok, agent}
            end
        end
        
      error -> error
    end
  end
  
  @doc """
  Copy or move an agent to a different location.
  
  ## Parameters
  
  - agent_id: ID or filename of the agent
  - target_instrument: Target instrument/currency pair
  - options: Additional options
    - `:source_instrument` - Source instrument (optional, improves lookup speed)
    - `:move` - Whether to move instead of copy (default: false)
    - `:subdirectory` - Target subdirectory
    - `:new_filename` - New filename for the agent (default: keep original)
  
  ## Returns
  
  - `{:ok, new_file_path}` - Path to the copied/moved agent
  - `{:error, reason}` - If operation fails
  """
  def copy_agent(agent_id, target_instrument, options \\ %{}) do
    # Find the agent file
    source_instrument = Map.get(options, :source_instrument)
    
    case find_agent_file(agent_id, source_instrument) do
      {:ok, source_path} ->
        # Load the agent
        case AgentSerializer.load_agent(source_path) do
          {:ok, {genotype, metadata}} ->
            # Normalize target instrument
            target_dir = normalize_instrument_name(target_instrument)
            
            # Create target directory
            target_base_dir = case Map.get(options, :subdirectory) do
              nil -> Path.join(@agent_repository_dir, target_dir)
              subdir -> Path.join([@agent_repository_dir, target_dir, subdir])
            end
            
            File.mkdir_p!(target_base_dir)
            
            # Determine target filename
            target_filename = case Map.get(options, :new_filename) do
              nil -> Path.basename(source_path)
              name -> if String.ends_with?(name, ".json"), do: name, else: "#{name}.json"
            end
            
            target_path = Path.join(target_base_dir, target_filename)
            
            # Update metadata with new instrument
            updated_metadata = Map.put(metadata, "instrument", target_instrument)
            
            # Save to target location
            case AgentSerializer.save_agent(genotype, target_path, updated_metadata) do
              :ok ->
                # If move option is set, delete the source file
                if Map.get(options, :move, false) do
                  File.rm(source_path)
                end
                
                {:ok, target_path}
                
              error -> error
            end
            
          error -> error
        end
        
      error -> error
    end
  end
  
  @doc """
  Delete an agent.
  
  ## Parameters
  
  - agent_id: ID or filename of the agent
  - instrument: Instrument/currency pair (optional, improves lookup speed)
  
  ## Returns
  
  - `:ok` - If deletion is successful
  - `{:error, reason}` - If deletion fails
  """
  def delete_agent(agent_id, instrument \\ nil) do
    # Find the agent file
    case find_agent_file(agent_id, instrument) do
      {:ok, file_path} ->
        # Delete the file
        case File.rm(file_path) do
          :ok -> :ok
          {:error, reason} -> {:error, "Failed to delete agent: #{inspect(reason)}"}
        end
        
      error -> error
    end
  end
  
  @doc """
  Create a backup of all agents for a specific instrument.
  
  ## Parameters
  
  - instrument: Instrument/currency pair
  - options: Additional options
    - `:backup_dir` - Custom backup directory (default: "backups" subdirectory)
    - `:include_timestamp` - Whether to include timestamp in backup dir (default: true)
  
  ## Returns
  
  - `{:ok, backup_dir}` - Path to the backup directory
  - `{:error, reason}` - If backup fails
  """
  def backup_agents(instrument, options \\ %{}) do
    # Normalize instrument name
    instrument_dir = normalize_instrument_name(instrument)
    
    # Source directory
    source_dir = Path.join(@agent_repository_dir, instrument_dir)
    
    # Check if source directory exists
    if !File.exists?(source_dir) do
      {:error, "No agents found for #{instrument}"}
    else
      # Determine backup directory
      timestamp = if Map.get(options, :include_timestamp, true) do
        DateTime.utc_now() 
        |> Calendar.strftime("%Y%m%d_%H%M%S")
      else
        ""
      end
      
      backup_base = Map.get(options, :backup_dir, "backups")
      
      backup_dir = if timestamp != "" do
        Path.join([@agent_repository_dir, instrument_dir, backup_base, timestamp])
      else
        Path.join([@agent_repository_dir, instrument_dir, backup_base])
      end
      
      # Create backup directory
      File.mkdir_p!(backup_dir)
      
      # Find all agent files
      agent_files = Path.wildcard(Path.join(source_dir, "*.json"))
      
      # Copy each file to backup directory
      results = Enum.map(agent_files, fn file ->
        target_file = Path.join(backup_dir, Path.basename(file))
        File.copy(file, target_file)
      end)
      
      # Check if all copies were successful
      if Enum.all?(results, fn result -> elem(result, 0) == :ok end) do
        {:ok, backup_dir}
      else
        # Find first error
        {_, error} = Enum.find(results, fn {status, _} -> status != :ok end)
        {:error, "Backup failed: #{inspect(error)}"}
      end
    end
  end
  
  # Private helper functions
  
  # Normalize instrument name for directory structure
  defp normalize_instrument_name(instrument) do
    instrument
    |> String.replace("/", "_")
    |> String.replace("-", "_")
    |> String.replace(" ", "_")
    |> String.upcase()
  end
  
  # Find an agent file by ID or filename
  defp find_agent_file(agent_id, instrument) do
    if instrument do
      # If instrument is provided, look in that directory first
      instrument_dir = normalize_instrument_name(instrument)
      dir_path = Path.join(@agent_repository_dir, instrument_dir)
      
      # Check if the file exists directly
      exact_path = Path.join(dir_path, agent_id)
      exact_path_with_ext = if String.ends_with?(exact_path, ".json") do
        exact_path
      else
        "#{exact_path}.json"
      end
      
      cond do
        File.exists?(exact_path) -> {:ok, exact_path}
        File.exists?(exact_path_with_ext) -> {:ok, exact_path_with_ext}
        true ->
          # Try searching in subdirectories
          Path.wildcard(Path.join([dir_path, "**", "*.json"]))
          |> Enum.find(fn path -> 
            Path.basename(path, ".json") == agent_id
          end)
          |> case do
            nil -> {:error, "Agent not found: #{agent_id}"}
            path -> {:ok, path}
          end
      end
    else
      # If instrument is not provided, search all directories
      Path.wildcard(Path.join([@agent_repository_dir, "**", "*.json"]))
      |> Enum.find(fn path -> 
        Path.basename(path, ".json") == agent_id || Path.basename(path) == agent_id
      end)
      |> case do
        nil -> {:error, "Agent not found: #{agent_id}"}
        path -> {:ok, path}
      end
    end
  end
  
  # Extract performance from filename or metadata
  defp extract_performance(file_path, metadata) do
    # Try from metadata first
    case get_in(metadata, ["performance"]) do
      nil ->
        # Try to extract from filename
        # Expected format: INSTRUMENT_PERFORMANCE_TIMESTAMP.json
        basename = Path.basename(file_path, ".json")
        parts = String.split(basename, "_")
        
        if length(parts) >= 3 do
          # Try to parse the second-to-last part as a number
          perf_part = Enum.at(parts, length(parts) - 2)
          
          case Float.parse(perf_part) do
            {perf, _} -> perf
            :error -> 0.0  # Default if not found
          end
        else
          0.0  # Default if filename doesn't match expected format
        end
        
      perf when is_list(perf) and length(perf) > 0 -> List.first(perf)
      perf when is_number(perf) -> perf
      _ -> 0.0
    end
  end
  
  # Sort agents by the specified criteria
  defp sort_agents(agents, options) do
    sort_by = Map.get(options, :sort_by, :date)
    sort_order = Map.get(options, :sort_order, :desc)
    
    # Sort function
    sort_fn = fn agent1, agent2 ->
      case sort_by do
        :performance ->
          # Sort by performance (highest first by default)
          cmp = agent1.performance >= agent2.performance
          if sort_order == :asc, do: !cmp, else: cmp
          
        :date ->
          # Sort by modification date (most recent first by default)
          date1 = case agent1.modified do
            {{y, m, d}, {h, min, s}} -> {y, m, d, h, min, s}
            _ -> {0, 0, 0, 0, 0, 0}
          end
          
          date2 = case agent2.modified do
            {{y, m, d}, {h, min, s}} -> {y, m, d, h, min, s}
            _ -> {0, 0, 0, 0, 0, 0}
          end
          
          cmp = date1 >= date2
          if sort_order == :asc, do: !cmp, else: cmp
          
        :filename ->
          # Sort by filename (A-Z by default)
          cmp = agent1.id >= agent2.id
          if sort_order == :asc, do: !cmp, else: cmp
          
        _ ->
          # Default to date sorting
          cmp = agent1.modified >= agent2.modified
          if sort_order == :asc, do: !cmp, else: cmp
      end
    end
    
    Enum.sort(agents, sort_fn)
  end
end