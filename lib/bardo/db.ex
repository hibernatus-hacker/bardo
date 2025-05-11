defmodule Bardo.DB do
  @moduledoc """
  A simple, efficient database for the Bardo neuroevolution system.

  Uses ETS (Erlang Term Storage) for in-memory storage with periodic backups.
  This implementation is designed for efficiency and simplicity, making it ideal
  for use as a library dependency in other projects.
  """

  use GenServer
  require Logger

  @table_name :bardo_db
  @backup_interval 30 * 60 * 1000  # 30 minutes

  # Client API

  @doc """
  Start the database server.

  ## Options

  * `:auto_backup` - Whether to run automatic backups (default: true)
  * `:backup_dir` - Directory to store backups (default: "backups")
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Store a value in the database.

  ## Parameters

  * `table` - The table to store the value in (e.g., :experiment, :population)
  * `key` - The key to store the value under
  * `value` - The value to store
  """
  @spec store(atom(), term(), term()) :: :ok
  def store(table, key, value) do
    GenServer.call(__MODULE__, {:store, table, key, value})
  end

  @doc """
  Fetch a value from the database.

  ## Parameters

  * `table` - The table to fetch from
  * `key` - The key to fetch

  ## Returns

  * `{:ok, value}` on success
  * `{:error, :not_found}` if the key doesn't exist
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

  ## Parameters

  * `table` - The table to delete from
  * `key` - The key to delete
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

  * `{:ok, [values]}` on success
  * `{:ok, []}` if the table is empty
  """
  @spec list(atom()) :: {:ok, [term()]} | {:ok, []}
  def list(table) do
    GenServer.call(__MODULE__, {:list, table})
  end

  @doc """
  Write a value to the database using the models format.

  This is a compatibility function for code that uses the Models module.

  ## Parameters

  * `value` - The model value to write
  * `table` - The table to write to
  """
  @spec write(term(), atom()) :: :ok
  def write(value, table) do
    id = Map.get(value.data, :id)
    store(table, id, value)
  end

  @doc """
  Read a value from the database using the models format.

  This is a compatibility function for code that uses the Models module.

  ## Parameters

  * `id` - The ID to read
  * `table` - The table to read from

  ## Returns

  * The value if found
  * `:not_found` if the key doesn't exist
  """
  @spec read(term(), atom()) :: term() | :not_found
  def read(id, table) do
    case fetch(table, id) do
      {:ok, value} -> value
      {:error, _} -> :not_found
    end
  end

  @doc """
  Back up the database to disk.

  ## Parameters

  * `backup_path` - Directory to store the backup (default: "backups")

  ## Returns

  * `{:ok, backup_file}` on success
  * `{:error, reason}` on failure
  """
  @spec backup(String.t()) :: {:ok, String.t()} | {:error, term()}
  def backup(backup_path \\ "backups") do
    GenServer.call(__MODULE__, {:backup, backup_path})
  end

  @doc """
  Restore the database from a backup file.

  ## Parameters

  * `backup_file` - Path to the backup file

  ## Returns

  * `:ok` on success
  * `{:error, reason}` on failure
  """
  @spec restore(String.t()) :: :ok | {:error, term()}
  def restore(backup_file) do
    GenServer.call(__MODULE__, {:restore, backup_file})
  end

  @doc """
  Check if a key exists in the database.

  ## Parameters

  * `table` - The table to check
  * `key` - The key to check

  ## Returns

  * `true` if the key exists
  * `false` if the key doesn't exist
  """
  @spec exists?(atom(), term()) :: boolean()
  def exists?(table, key) do
    case fetch(table, key) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    # Get configuration
    auto_backup = Keyword.get(opts, :auto_backup, true)
    backup_dir = Keyword.get(opts, :backup_dir, "backups")
    
    # Create the table
    table = :ets.new(@table_name, [:set, :public, :named_table])
    Logger.info("[DB] Initialized ETS table #{inspect(table)}")
    
    # Schedule automatic backups if enabled
    if auto_backup do
      schedule_backup()
    end
    
    {:ok, %{
      table: table,
      auto_backup: auto_backup,
      backup_dir: backup_dir
    }}
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

    {:reply, {:ok, values}, state}
  end

  @impl true
  def handle_call({:backup, backup_path}, _from, state) do
    # Create backup directory if it doesn't exist
    File.mkdir_p!(backup_path)
    
    # Generate backup filename with timestamp
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601() |> String.replace(":", "-")
    backup_file = Path.join(backup_path, "bardo_backup_#{timestamp}.bin")
    
    # Dump ETS table to disk
    try do
      :ets.tab2file(@table_name, String.to_charlist(backup_file))
      Logger.info("[DB] Backup created at #{backup_file}")
      {:reply, {:ok, backup_file}, state}
    rescue
      e ->
        Logger.error("[DB] Backup failed: #{inspect(e)}")
        {:reply, {:error, "Backup failed: #{inspect(e)}"}, state}
    end
  end

  @impl true
  def handle_call({:restore, backup_file}, _from, state) do
    # Restore ETS table from disk
    try do
      # Delete existing table
      :ets.delete(@table_name)
      
      # Restore from file
      :ets.file2tab(String.to_charlist(backup_file))
      Logger.info("[DB] Restored from #{backup_file}")
      {:reply, :ok, state}
    rescue
      e ->
        Logger.error("[DB] Restore failed: #{inspect(e)}")
        
        # Recreate empty table if restore fails
        :ets.new(@table_name, [:set, :public, :named_table])
        
        {:reply, {:error, "Restore failed: #{inspect(e)}"}, state}
    end
  end

  @impl true
  def handle_info(:backup, state) do
    # Create backup
    backup_dir = state.backup_dir
    File.mkdir_p!(backup_dir)
    {:ok, _} = backup(backup_dir)
    
    # Schedule next backup
    schedule_backup()
    
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{table: table}) do
    # Backup before shutting down
    backup_dir = Application.get_env(:bardo, :backup_dir, "backups")
    File.mkdir_p!(backup_dir)
    backup(backup_dir)
    
    :ets.delete(table)
  end

  # Private Functions

  defp encode_key(table, key) do
    # Convert atom keys to strings for consistent encoding
    string_key = cond do
      is_atom(key) -> Atom.to_string(key)
      is_binary(key) -> key
      true -> inspect(key)
    end

    "#{table}_#{string_key}"
  end

  defp schedule_backup do
    Process.send_after(self(), :backup, @backup_interval)
  end
end