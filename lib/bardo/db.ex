defmodule Bardo.DB do
  @moduledoc """
  A simple database for the Bardo system.
  
  Uses ETS (Erlang Term Storage) for in-memory storage.
  """
  
  use GenServer
  require Logger
  
  @table_name :bardo_db
  
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
  
  @doc """
  Write a value to the database. This is a direct wrapper for store.
  """
  @spec write(term(), atom()) :: :ok
  def write(value, table) do
    id = Map.get(value.data, :id)
    store(table, id, value)
  end
  
  @doc """
  Read a value from the database. This is a direct wrapper for fetch.
  """
  @spec read(term(), atom()) :: term() | nil
  def read(id, table) do
    fetch(table, id)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    Logger.info("[DB] Initialized ETS table #{inspect(table)}")
    
    {:ok, %{table: table}}
  end

  @impl true
  def handle_call({:store, table, key, value}, _from, state) do
    encoded_key = encode_key(table, key)
    encoded_value = :erlang.term_to_binary(value)
    
    :ets.insert(@table_name, {encoded_key, encoded_value})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fetch, table, key}, _from, state) do
    encoded_key = encode_key(table, key)
    
    case :ets.lookup(@table_name, encoded_key) do
      [{^encoded_key, encoded_value}] ->
        value = :erlang.binary_to_term(encoded_value)
        {:reply, value, state}
      [] ->
        {:reply, nil, state}
    end
  end

  @impl true
  def handle_call({:delete, table, key}, _from, state) do
    encoded_key = encode_key(table, key)
    :ets.delete(@table_name, encoded_key)
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, %{table: table}) do
    :ets.delete(table)
  end

  # Private Functions

  defp encode_key(table, key) do
    "#{table}_#{:erlang.term_to_binary(key)}"
  end
end