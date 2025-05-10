defmodule Bardo.Persistence do
  @moduledoc """
  Core persistence module for Bardo.
  
  This module provides a high-level API for saving and loading models,
  supporting both the default ETS-based storage and PostgreSQL storage
  for distributed environments.
  
  It handles serialization, compression, migrations, and provides a
  consistent interface regardless of the underlying storage technology.
  """
  
  require Logger
  alias Bardo.Models
  
  @doc """
  Save a model to storage.
  
  ## Parameters
    * `model` - The model to save
    * `type` - The type of model (e.g., :experiment, :population, :genotype)
    * `id` - Optional ID for the model (if not provided, extracted from the model)
    * `opts` - Additional options:
      * `:compress` - Whether to compress the model (default: false)
      * `:format` - Format to save in (:erlang or :json, default: :erlang)
      * `:version` - Schema version for future migrations
      
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{name: "Test"})
      iex> Bardo.Persistence.save(morphology, :morphology)
      :ok
      
      iex> experiment = %{id: "exp_123", data: %{name: "Test Experiment"}}
      iex> Bardo.Persistence.save(experiment, :experiment)
      :ok
  """
  @spec save(map(), atom(), binary() | nil, keyword()) :: :ok | {:error, term()}
  def save(model, type, id \\ nil, opts \\ []) do
    # Extract ID from model if not provided
    model_id = id || extract_id(model)
    
    if is_nil(model_id) do
      {:error, "No ID provided and could not extract ID from model"}
    else
      # Prepare model for storage
      prepared_model = prepare_model_for_storage(model, opts)
      
      # Save to database
      # Models.write expects (model, type, id) - fixing the order
      Models.write(prepared_model, type, model_id)
    end
  end
  
  @doc """
  Load a model from storage.
  
  ## Parameters
    * `type` - The type of model to load (e.g., :experiment, :population, :genotype)
    * `id` - The ID of the model to load
    * `opts` - Additional options:
      * `:decompress` - Whether to decompress the model (default: auto-detect)
      * `:format` - Expected format (:erlang or :json, default: auto-detect)
      
  ## Returns
    * `{:ok, model}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.load(:morphology, "morph_123")
      {:ok, %{id: "morph_123", name: "Test", ...}}
      
      iex> Bardo.Persistence.load(:experiment, "exp_123")
      {:ok, %{id: "exp_123", data: %{name: "Test Experiment"}}}
  """
  @spec load(atom(), binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def load(type, id, opts \\ []) do
    case Models.read(id, type) do
      {:ok, model} ->
        # Process loaded model
        processed_model = process_loaded_model(model, opts)
        {:ok, processed_model}
        
      error ->
        error
    end
  end
  
  @doc """
  Check if a model exists in storage.
  
  ## Parameters
    * `type` - The type of model to check (e.g., :experiment, :population, :genotype)
    * `id` - The ID of the model to check
    
  ## Returns
    * `true` if the model exists
    * `false` if the model does not exist
    
  ## Examples
      iex> Bardo.Persistence.exists?(:morphology, "morph_123")
      true
      
      iex> Bardo.Persistence.exists?(:experiment, "nonexistent")
      false
  """
  @spec exists?(atom(), binary()) :: boolean()
  def exists?(type, id) do
    # The Models.exists? function expects (id, type), so we need to swap parameters
    Models.exists?(id, type)
  end
  
  @doc """
  Delete a model from storage.
  
  ## Parameters
    * `type` - The type of model to delete (e.g., :experiment, :population, :genotype)
    * `id` - The ID of the model to delete
    
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.delete(:morphology, "morph_123")
      :ok
  """
  @spec delete(atom(), binary()) :: :ok | {:error, term()}
  def delete(type, id) do
    # Bug fix: The Models.delete function has the parameters in the wrong order
    # compared to how Models.exists? calls DB.fetch
    # We should call DB.delete directly with the correct parameter order
    Bardo.DB.delete(type, id)
  end
  
  @doc """
  List all models of a given type.
  
  ## Parameters
    * `type` - The type of models to list (e.g., :experiment, :population, :genotype)
    
  ## Returns
    * `{:ok, [model]}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.list(:morphology)
      {:ok, [%{id: "morph_123", name: "Test", ...}, ...]}
  """
  @spec list(atom()) :: {:ok, [map()]} | {:error, term()}
  def list(type) do
    try do
      case Bardo.DB do
        Bardo.DBPostgres ->
          Bardo.DBPostgres.list(type)
        _ ->
          case Bardo.DB.list(type) do
            {:ok, results} when is_list(results) -> {:ok, results}
            {:ok, []} -> {:ok, []}
            [] -> {:ok, []}
            nil -> {:ok, []}
            results when is_list(results) -> {:ok, results}
            error -> {:error, "Unexpected response format: #{inspect(error)}"}
          end
      end
    rescue
      e -> {:error, "Error listing #{type}: #{inspect(e)}"}
    end
  end
  
  @doc """
  Create a backup of the database.
  
  ## Parameters
    * `path` - Path to store the backup (default: "backups")
    
  ## Returns
    * `{:ok, backup_file}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.backup("my_backups")
      {:ok, "my_backups/bardo_backup_2025-05-07.db"}
  """
  @spec backup(binary()) :: {:ok, binary()} | {:error, term()}
  def backup(path \\ "backups") do
    try do
      case Bardo.DB do
        Bardo.DBPostgres -> Bardo.DBPostgres.backup(path)
        _ -> 
          # For ETS, create a simple backup
          File.mkdir_p!(path)
          timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
          backup_file = Path.join(path, "bardo_backup_#{timestamp}.db")

          # Pass the path to DB.backup()
          result = Bardo.DB.backup(path)
          File.write!(backup_file, "ETS backup created at #{timestamp}")

          # Return the result from DB.backup instead of creating our own success response
          result
      end
    rescue
      e -> {:error, "Error creating backup: #{inspect(e)}"}
    end
  end
  
  @doc """
  Restore from a backup.
  
  ## Parameters
    * `backup_file` - Path to the backup file
    
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.restore("backups/bardo_backup_2025-05-07.db")
      :ok
  """
  @spec restore(binary()) :: :ok | {:error, term()}
  def restore(backup_file) do
    try do
      case Bardo.DB do
        Bardo.DBPostgres -> Bardo.DBPostgres.restore(backup_file)
        _ -> {:error, "Restore not supported for ETS database"}
      end
    rescue
      e -> {:error, "Error restoring from backup: #{inspect(e)}"}
    end
  end
  
  @doc """
  Export a model to a file.
  
  ## Parameters
    * `model` - The model to export
    * `file_path` - Path to save the file
    * `opts` - Additional options:
      * `:format` - Format to export in (:erlang, :json, or :etf, default: :erlang)
      * `:compress` - Whether to compress the file (default: false)
      
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{name: "Test"})
      iex> Bardo.Persistence.export(morphology, "test_morphology.etf")
      :ok
  """
  @spec export(map(), binary(), keyword()) :: :ok | {:error, term()}
  def export(model, file_path, opts \\ []) do
    try do
      format = Keyword.get(opts, :format, :erlang)
      compress = Keyword.get(opts, :compress, false)
      
      # Prepare model for export
      prepared_model = prepare_model_for_storage(model, compress: compress)
      
      # Convert to the desired format
      encoded_data = case format do
        :erlang -> :erlang.term_to_binary(prepared_model)
        :json -> Jason.encode!(prepared_model)
        :etf -> :erlang.term_to_binary(prepared_model)
        _ -> :erlang.term_to_binary(prepared_model)
      end
      
      # Create the directory if it doesn't exist
      File.mkdir_p!(Path.dirname(file_path))
      
      # Write to file
      File.write!(file_path, encoded_data)
      
      :ok
    rescue
      e -> {:error, "Error exporting model: #{inspect(e)}"}
    end
  end
  
  @doc """
  Import a model from a file.
  
  ## Parameters
    * `file_path` - Path to the file to import
    * `opts` - Additional options:
      * `:format` - Format of the file (:erlang, :json, or :etf, default: auto-detect)
      * `:decompress` - Whether to decompress the file (default: auto-detect)
      
  ## Returns
    * `{:ok, model}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Persistence.import("test_morphology.etf")
      {:ok, %{id: "morph_123", name: "Test", ...}}
  """
  @spec import(binary(), keyword()) :: {:ok, map()} | {:error, term()}
  def import(file_path, opts \\ []) do
    try do
      format = Keyword.get(opts, :format, :auto)
      
      # Read the file
      data = File.read!(file_path)
      
      # Detect format if auto
      detected_format = if format == :auto do
        cond do
          String.starts_with?(data, "{") -> :json
          true -> :erlang
        end
      else
        format
      end
      
      # Decode based on format
      decoded_data = case detected_format do
        :erlang -> :erlang.binary_to_term(data)
        :json -> Jason.decode!(data)
        :etf -> :erlang.binary_to_term(data)
        _ -> {:error, "Unsupported format"}
      end
      
      # Process the loaded model
      model = process_loaded_model(decoded_data, opts)
      
      {:ok, model}
    rescue
      e -> {:error, "Error importing model: #{inspect(e)}"}
    end
  end
  
  # Private helpers
  
  # Extract ID from a model
  defp extract_id(model) do
    cond do
      is_map(model) && Map.has_key?(model, :id) ->
        model.id
      is_map(model) && Map.has_key?(model, "id") ->
        model["id"]
      is_map(model) && Map.has_key?(model, :data) && is_map(model.data) && Map.has_key?(model.data, :id) ->
        model.data.id
      is_map(model) && Map.has_key?(model, "data") && is_map(model["data"]) && Map.has_key?(model["data"], "id") ->
        model["data"]["id"]
      true ->
        nil
    end
  end
  
  # Prepare a model for storage
  defp prepare_model_for_storage(model, opts) do
    compress = Keyword.get(opts, :compress, false)
    format = Keyword.get(opts, :format, :erlang)
    version = Keyword.get(opts, :version, 1)
    
    # Add metadata
    model_with_meta = add_metadata(model, %{
      format: format,
      version: version,
      compressed: compress,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    })
    
    # Compress if requested
    if compress do
      compress_model(model_with_meta)
    else
      model_with_meta
    end
  end
  
  # Process a loaded model
  defp process_loaded_model(model, opts) do
    # Check if the model is compressed
    compressed? = model_compressed?(model)
    explicit_decompress = Keyword.get(opts, :decompress, nil)
    
    # Decompress if needed
    model = if (compressed? && explicit_decompress != false) || explicit_decompress == true do
      decompress_model(model)
    else
      model
    end
    
    # Remove any internal metadata if present
    remove_metadata(model)
  end
  
  # Add metadata to a model
  defp add_metadata(model, metadata) do
    # Add metadata based on model structure
    cond do
      is_map(model) && Map.has_key?(model, :data) && is_map(model.data) ->
        metadata_key = :__bardo_metadata__
        updated_data = Map.put(model.data, metadata_key, metadata)
        %{model | data: updated_data}
        
      is_map(model) ->
        metadata_key = :__bardo_metadata__
        Map.put(model, metadata_key, metadata)
        
      true ->
        model
    end
  end
  
  # Remove metadata from a model
  defp remove_metadata(model) do
    # Remove metadata based on model structure
    cond do
      is_map(model) && Map.has_key?(model, :data) && is_map(model.data) ->
        metadata_key = :__bardo_metadata__
        updated_data = Map.drop(model.data, [metadata_key])
        %{model | data: updated_data}
        
      is_map(model) ->
        metadata_key = :__bardo_metadata__
        Map.drop(model, [metadata_key])
        
      true ->
        model
    end
  end
  
  # Compress a model
  defp compress_model(model) do
    # Convert to binary and compress
    binary_data = :erlang.term_to_binary(model)
    compressed_data = :zlib.compress(binary_data)
    
    # Return a wrapper that indicates compression
    %{
      __compressed__: true,
      data: compressed_data
    }
  end
  
  # Decompress a model
  defp decompress_model(model) do
    if model_compressed?(model) do
      # Extract and decompress the data
      compressed_data = model.data
      binary_data = :zlib.uncompress(compressed_data)
      :erlang.binary_to_term(binary_data)
    else
      model
    end
  end
  
  # Check if a model is compressed
  defp model_compressed?(model) do
    is_map(model) && Map.has_key?(model, :__compressed__) && model.__compressed__ == true
  end
end