defmodule Bardo.DB do
  @moduledoc """
  A simple database for the Bardo system.
  
  Handles storage and retrieval of data using RocksDB.
  """
  
  use GenServer
  require Logger
  
  # Client API

  @doc """
  Start the database server.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store a value in the database.
  """
  @spec store(atom(), term(), term()) :: :ok
  def store(table, key, value) do
    GenServer.call(__MODULE__, {:store, table, key, value})
  end

  @doc """
  Fetch a value from the database.
  """
  @spec fetch(atom(), term()) :: term() | nil
  def fetch(table, key) do
    GenServer.call(__MODULE__, {:fetch, table, key})
  end

  @doc """
  Delete a value from the database.
  """
  @spec delete(atom(), term()) :: :ok
  def delete(table, key) do
    GenServer.call(__MODULE__, {:delete, table, key})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    db_path = db_path()
    File.mkdir_p!(db_path)
    
    {:ok, db} = :rocksdb.open(to_charlist(db_path), create_if_missing: true)
    Logger.info("[DB] Initialized at #{db_path}")
    
    {:ok, %{db: db}}
  end

  @impl true
  def handle_call({:store, table, key, value}, _from, %{db: db} = state) do
    encoded_key = encode_key(table, key)
    encoded_value = :erlang.term_to_binary(value)
    
    case :rocksdb.put(db, encoded_key, encoded_value, []) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        Logger.error("[DB] Failed to store #{inspect(key)} in #{inspect(table)}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:fetch, table, key}, _from, %{db: db} = state) do
    encoded_key = encode_key(table, key)
    
    case :rocksdb.get(db, encoded_key, []) do
      {:ok, binary} ->
        value = :erlang.binary_to_term(binary)
        {:reply, value, state}
      :not_found ->
        {:reply, nil, state}
      {:error, reason} ->
        Logger.error("[DB] Failed to fetch #{inspect(key)} from #{inspect(table)}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:delete, table, key}, _from, %{db: db} = state) do
    encoded_key = encode_key(table, key)
    
    case :rocksdb.delete(db, encoded_key, []) do
      :ok ->
        {:reply, :ok, state}
      {:error, reason} ->
        Logger.error("[DB] Failed to delete #{inspect(key)} from #{inspect(table)}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, %{db: db}) do
    :rocksdb.close(db)
  end

  # Private Functions

  defp db_path do
    Path.join([System.tmp_dir!(), "bardo_db"])
  end

  defp encode_key(table, key) do
    "#{table}_#{:erlang.term_to_binary(key)}"
  end
end