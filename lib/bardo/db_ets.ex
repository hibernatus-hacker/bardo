defmodule Bardo.DBETS do
  @moduledoc """
  ETS-based implementation of the DB module for testing.
  This replaces the RocksDB-based implementation with a simple in-memory ETS table.
  """
  use GenServer

  @table_name :bardo_db

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    table = :ets.new(@table_name, [:set, :public, :named_table])
    {:ok, %{table: table}}
  end

  def write(key, value, type) do
    encoded_key = :erlang.term_to_binary({key, type})
    encoded_value = :erlang.term_to_binary(value)
    :ets.insert(@table_name, {encoded_key, encoded_value})
    :ok
  end

  def read(key, type) do
    encoded_key = :erlang.term_to_binary({key, type})
    case :ets.lookup(@table_name, encoded_key) do
      [{^encoded_key, encoded_value}] ->
        :erlang.binary_to_term(encoded_value)
      [] ->
        :not_found
    end
  end

  def delete(key, type) do
    encoded_key = :erlang.term_to_binary({key, type})
    :ets.delete(@table_name, encoded_key)
    :ok
  end

  # GenServer API - For handling calls from the original DB module
  def handle_call({:write, key, value, type}, _from, state) do
    result = write(key, value, type)
    {:reply, result, state}
  end

  def handle_call({:read, key, type}, _from, state) do
    result = read(key, type)
    {:reply, result, state}
  end

  def handle_call({:delete, key, type}, _from, state) do
    result = delete(key, type)
    {:reply, result, state}
  end

  def terminate(_reason, _state) do
    :ets.delete(@table_name)
  end
end