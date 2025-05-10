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

  ## Returns

  {:ok, value} on success, {:error, :not_found} on failure.
  """
  @spec fetch(atom(), term()) :: {:ok, term()} | {:error, :not_found}
  def fetch(table, key) do
    result = GenServer.call(__MODULE__, {:fetch, table, key})
    if result == nil do
      {:error, :not_found}
    else
      {:ok, result}
    end
  end

  @doc """
  Delete a value from the database.
  """
  @spec delete(atom(), term()) :: :ok
  def delete(table, key) do
    GenServer.call(__MODULE__, {:delete, table, key})
  end

  @doc """
  List all values for a specific table type.

  ## Parameters
    * `table` - The table to list values from

  ## Returns
    * List of values for the specified table
  """
  @spec list(atom()) :: [term()] | []
  def list(table) do
    GenServer.call(__MODULE__, {:list, table})
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

  Note: For backward compatibility, this function returns the direct value
  rather than the {:ok, value} tuple format that fetch returns. This is to
  maintain compatibility with existing code that expects the direct value.

  ## Returns

  The value if found, nil if not found.
  """
  @spec read(term(), atom()) :: term() | nil
  def read(id, table) do
    case fetch(table, id) do
      {:ok, value} -> value
      {:error, _} -> nil
      other -> other  # Handle legacy cases
    end
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

    # First log what we have before deletion
    before_keys = :ets.tab2list(@table_name) |> Enum.map(fn {k, _} -> k end)
    Logger.debug("[DB] Before delete, keys: #{inspect(before_keys)}")

    # Perform the deletion
    result = :ets.delete(@table_name, encoded_key)
    Logger.debug("[DB] Deleted key #{inspect(encoded_key)}, result: #{inspect(result)}")

    # Verify the deletion
    after_keys = :ets.tab2list(@table_name) |> Enum.map(fn {k, _} -> k end)
    Logger.debug("[DB] After delete, keys: #{inspect(after_keys)}")

    # Manually verify the key is no longer present
    lookup_result = :ets.lookup(@table_name, encoded_key)
    Logger.debug("[DB] Post-delete lookup for #{inspect(encoded_key)}: #{inspect(lookup_result)}")

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:list, table}, _from, state) do
    # Get all keys for the table
    all_keys = :ets.tab2list(@table_name)
    |> Enum.filter(fn {key, _} ->
      # We prefix keys with table name in encode_key/2
      # We need to filter keys that start with this prefix
      key_prefix = "#{table}_"
      String.starts_with?(to_string(key), key_prefix)
    end)

    # Extract and decode the values
    values = Enum.map(all_keys, fn {_, encoded_value} ->
      :erlang.binary_to_term(encoded_value)
    end)

    # Return in the same format as the PostgreSQL adapter for consistency
    {:reply, {:ok, values}, state}
  end

  @impl true
  def terminate(_reason, %{table: table}) do
    :ets.delete(table)
  end
  
  @doc """
  Back up the database to disk. For our examples, this is a no-op.

  ## Parameters

  - backup_path: Directory to store the backup (default: "backups")

  ## Returns

  {:ok, backup_file} on success, {:error, reason} on failure.
  """
  def backup(backup_path \\ "backups") do
    Logger.info("[DB] Backup requested (simulated backup only)")
    File.mkdir_p!(backup_path)
    backup_file = Path.join(backup_path, "bardo_ets_backup_#{DateTime.utc_now() |> DateTime.to_iso8601()}.bin")

    # Dump ETS table to disk
    try do
      :ets.tab2file(@table_name, String.to_charlist(backup_file))
      Logger.info("[DB] ETS backup created at #{backup_file}")
      {:ok, backup_file}
    rescue
      e ->
        Logger.error("[DB] Backup failed: #{inspect(e)}")
        {:error, "Backup failed: #{inspect(e)}"}
    end
  end

  # Private Functions

  defp encode_key(table, key) do
    # Fix the key encoding to be consistent
    # Convert atom keys to strings for consistent encoding
    string_key = cond do
      is_atom(key) -> Atom.to_string(key)
      is_binary(key) -> key
      true -> inspect(key)
    end

    encoded = "#{table}_#{string_key}"
    Logger.debug("[DB] Encoding key - table: #{inspect(table)}, key: #{inspect(key)}, encoded: #{inspect(encoded)}")
    encoded
  end
end