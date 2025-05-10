defmodule Bardo.DBInterface do
  @moduledoc """
  Database interface for Bardo.
  
  This module provides a wrapper around the configured database adapter,
  allowing for seamless switching between different storage backends.
  
  ## Usage
  
  In your code, instead of directly calling `Bardo.DB` or `Bardo.DBPostgres`,
  use this module, which will automatically route calls to the configured adapter:
  
  ```elixir
  # Read a value
  value = Bardo.DBInterface.read(id, :experiment)
  
  # Write a value
  :ok = Bardo.DBInterface.write(value, :experiment)
  ```
  
  ## Configuration
  
  In your config/config.exs:
  
  ```elixir
  # For ETS storage:
  config :bardo, :db, adapter: Bardo.DB
  
  # For PostgreSQL storage:
  config :bardo, :db, adapter: Bardo.DBPostgres
  ```
  """
  
  require Logger
  
  @doc """
  Get the configured database adapter.
  """
  def adapter do
    Application.get_env(:bardo, :db, :adapter) || Bardo.DB
  end
  
  @doc """
  Store a value in the database.
  
  ## Parameters
  
  - type: Type of data being stored (e.g., :experiment, :population, :genotype)
  - id: Unique identifier for the data
  - value: The data to store
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def store(type, id, value) do
    adapter().store(type, id, value)
  end
  
  @doc """
  Read a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to read (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  The value if found, nil otherwise.
  """
  def read(id, type) do
    adapter().read(id, type)
  end
  
  @doc """
  Fetch a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to read (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  {:ok, value} on success, {:error, reason} on failure.
  """
  def fetch(id, type) do
    adapter().fetch(id, type)
  end
  
  @doc """
  Delete a value from the database.
  
  ## Parameters
  
  - id: Unique identifier for the data
  - type: Type of data to delete (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def delete(id, type) do
    adapter().delete(id, type)
  end
  
  @doc """
  Write a value to the database.
  
  ## Parameters
  
  - value: The value to store (must have an :id field in its data map)
  - table: The table/type to write to
  
  ## Returns
  
  :ok on success, {:error, reason} on failure.
  """
  def write(value, table) do
    adapter().write(value, table)
  end
  
  @doc """
  List all values of a given type.
  
  ## Parameters
  
  - type: Type of data to list (e.g., :experiment, :population, :genotype)
  
  ## Returns
  
  List of values on success, [] on failure.
  """
  def list(type) do
    case adapter().list(type) do
      {:ok, values} when is_list(values) -> values
      {:ok, []} -> []
      values when is_list(values) -> values
      [] -> []
      nil -> []
      _error -> []
    end
  end
  
  @doc """
  Create a backup of the database.
  
  ## Parameters
  
  - backup_path: Directory to store the backup (default: "backups")
  
  ## Returns
  
  {:ok, backup_file} on success, {:error, reason} on failure.
  """
  def backup(backup_path \\ "backups") do
    adapter().backup(backup_path)
  end
end