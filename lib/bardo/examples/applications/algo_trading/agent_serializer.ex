defmodule Bardo.Examples.Applications.AlgoTrading.AgentSerializer do
  @moduledoc """
  Module for serializing and deserializing neural network agents to/from JSON.
  
  This module provides functions for:
  - Converting neural network structures to JSON format
  - Loading neural networks from JSON files
  - Versioning and schema validation for compatibility
  """
  
  require Logger
  alias Bardo.Examples.Applications.AlgoTrading.Morphology
  alias Bardo.Models
  
  @current_schema_version "1.0"
  
  @doc """
  Serialize a trained agent to JSON format.
  
  ## Parameters
  
  - genotype: The agent's genotype to serialize
  - metadata: Additional metadata to include with the serialized agent
  
  ## Returns
  
  - `{:ok, json_string}` - Serialized agent as a JSON string
  - `{:error, reason}` - If serialization fails
  """
  def serialize(genotype, metadata \\ %{}) do
    try do
      # Create the serialization structure
      agent_data = %{
        schema_version: @current_schema_version,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        metadata: metadata,
        network: serialize_network(genotype)
      }
      
      # Convert to JSON
      {:ok, Jason.encode!(agent_data, pretty: true)}
    rescue
      e -> {:error, "Failed to serialize agent: #{inspect(e)}"}
    end
  end
  
  @doc """
  Deserialize an agent from JSON format.
  
  ## Parameters
  
  - json_string: The JSON string containing the serialized agent
  
  ## Returns
  
  - `{:ok, {genotype, metadata}}` - The deserialized genotype and metadata
  - `{:error, reason}` - If deserialization fails
  """
  def deserialize(json_string) do
    try do
      # Parse JSON
      agent_data = Jason.decode!(json_string)
      
      # Validate schema version
      schema_version = Map.get(agent_data, "schema_version", "unknown")
      
      if schema_version == @current_schema_version do
        # Extract data
        metadata = Map.get(agent_data, "metadata", %{})
        network_data = Map.get(agent_data, "network", %{})
        
        # Deserialize network
        genotype = deserialize_network(network_data)
        
        {:ok, {genotype, metadata}}
      else
        # Handle older schema versions if needed
        {:error, "Unsupported schema version: #{schema_version}"}
      end
    rescue
      e -> {:error, "Failed to deserialize agent: #{inspect(e)}"}
    end
  end
  
  @doc """
  Save a serialized agent to a file.
  
  ## Parameters
  
  - genotype: The agent's genotype to serialize
  - file_path: Path to save the serialized agent
  - metadata: Additional metadata to include
  
  ## Returns
  
  - `:ok` - If the agent was successfully saved
  - `{:error, reason}` - If saving fails
  """
  def save_agent(genotype, file_path, metadata \\ %{}) do
    # Ensure directory exists
    File.mkdir_p!(Path.dirname(file_path))
    
    # Serialize agent
    case serialize(genotype, metadata) do
      {:ok, json_string} ->
        # Write to file
        File.write(file_path, json_string)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Load a serialized agent from a file.
  
  ## Parameters
  
  - file_path: Path to the serialized agent file
  
  ## Returns
  
  - `{:ok, {genotype, metadata}}` - The loaded genotype and metadata
  - `{:error, reason}` - If loading fails
  """
  def load_agent(file_path) do
    # Read file
    case File.read(file_path) do
      {:ok, json_string} ->
        # Deserialize agent
        deserialize(json_string)
        
      {:error, reason} ->
        {:error, "Failed to read agent file: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Save the best agent from an experiment.
  
  ## Parameters
  
  - experiment_id: ID of the completed experiment
  - file_path: Path to save the serialized agent
  - metadata: Additional metadata to include
  
  ## Returns
  
  - `:ok` - If the agent was successfully saved
  - `{:error, reason}` - If saving fails
  """
  def save_best_agent(experiment_id, file_path, metadata \\ %{}) do
    # Load the experiment data
    case Models.read(experiment_id, :experiment) do
      {:ok, experiment} ->
        # Get population ID
        population_id = case Models.get(experiment, :populations) do
          populations when is_list(populations) and length(populations) > 0 ->
            List.first(populations) |> Map.get(:id)
          _ ->
            nil
        end
        
        # Find the best genotype
        case population_id && fetch_best_genotype(population_id) do
          {:ok, genotype} ->
            # Add experiment info to metadata
            enhanced_metadata = Map.merge(metadata, %{
              experiment_id: experiment_id,
              population_id: population_id,
              saved_at: DateTime.utc_now() |> DateTime.to_iso8601()
            })
            
            # Save agent
            save_agent(genotype, file_path, enhanced_metadata)
            
          {:error, reason} ->
            {:error, reason}
            
          nil ->
            {:error, "Could not find population in experiment"}
        end
        
      {:error, reason} ->
        {:error, "Failed to load experiment: #{inspect(reason)}"}
    end
  end
  
  # Private helper functions
  
  # Serialize neural network to structured format
  defp serialize_network(genotype) do
    %{
      "neurons" => serialize_neurons(genotype),
      "connections" => serialize_connections(genotype),
      "fitness" => genotype[:fitness] || []
    }
  end
  
  # Serialize neurons to structured format
  defp serialize_neurons(genotype) do
    neurons = Map.get(genotype, :neurons) || %{}
    
    Enum.map(neurons, fn {id, neuron} ->
      %{
        "id" => id,
        "layer" => atom_to_string(neuron[:layer]),
        "activation_function" => atom_to_string(neuron[:activation_function]),
        "bias" => neuron[:bias] || 0.0
      }
    end)
  end
  
  # Serialize connections to structured format
  defp serialize_connections(genotype) do
    connections = Map.get(genotype, :connections) || %{}
    
    Enum.map(connections, fn {id, connection} ->
      %{
        "id" => id,
        "from_id" => connection[:from_id],
        "to_id" => connection[:to_id],
        "weight" => connection[:weight] || 0.0
      }
    end)
  end
  
  # Deserialize network from structured format
  defp deserialize_network(network_data) do
    # Extract data
    neurons_data = Map.get(network_data, "neurons", [])
    connections_data = Map.get(network_data, "connections", [])
    fitness = Map.get(network_data, "fitness", [])
    
    # Build neurons map
    neurons = Enum.reduce(neurons_data, %{}, fn neuron, acc ->
      id = neuron["id"]
      
      neuron_map = %{
        layer: string_to_atom(neuron["layer"]),
        activation_function: string_to_atom(neuron["activation_function"])
      }
      
      # Add bias if present
      neuron_map = if Map.has_key?(neuron, "bias") do
        Map.put(neuron_map, :bias, neuron["bias"])
      else
        neuron_map
      end
      
      Map.put(acc, id, neuron_map)
    end)
    
    # Build connections map
    connections = Enum.reduce(connections_data, %{}, fn connection, acc ->
      id = connection["id"]
      
      connection_map = %{
        from_id: connection["from_id"],
        to_id: connection["to_id"],
        weight: connection["weight"]
      }
      
      Map.put(acc, id, connection_map)
    end)
    
    # Construct genotype
    %{
      neurons: neurons,
      connections: connections,
      fitness: fitness
    }
  end
  
  # Fetch the best genotype from a population
  defp fetch_best_genotype(population_id) do
    case Models.read(population_id, :population) do
      {:ok, population} ->
        # Get the population of genotypes
        genotypes = Models.get(population, :population) || []
        
        if length(genotypes) > 0 do
          # Find the genotype with the highest fitness
          best_genotype = Enum.max_by(genotypes, fn genotype -> 
            case Models.get(genotype, :fitness) do
              [profit | _] -> profit
              _ -> -1000.0  # Default for invalid fitness
            end
          end)
          
          {:ok, best_genotype}
        else
          {:error, "Empty population"}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Helper to convert atom to string
  defp atom_to_string(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp atom_to_string(value), do: to_string(value)
  
  # Helper to convert string to atom
  defp string_to_atom(string) when is_binary(string) do
    case string do
      ":" <> rest -> String.to_atom(rest)
      _ -> String.to_atom(string)
    end
  end
  defp string_to_atom(value) when is_atom(value), do: value
  defp string_to_atom(_), do: nil
end