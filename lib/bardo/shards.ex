defmodule :shards do
  @moduledoc """
  A minimal replacement for the :shards library for testing.
  Uses ETS tables for storage with matching functions.
  """
  
  @doc """
  Insert a record into a table.
  """
  def insert(table, record) do
    :ets.insert(table, record)
    true
  end
  
  @doc """
  Lookup a record in a table.
  """
  def lookup(table, key) do
    :ets.lookup(table, key)
  end
  
  @doc """
  Match objects in a table.
  """
  def match_object(table, pattern) do
    :ets.match_object(table, pattern)
  end
  
  @doc """
  Delete a record from a table.
  """
  def delete(table, key) do
    :ets.delete(table, key)
    true
  end
  
  @doc """
  Delete an entire table.
  """
  def delete(table) do
    :ets.delete_all_objects(table)
    true
  end
  
  @doc """
  Update a counter in a table.
  """
  def update_counter(table, key, update_op, default) do
    case :ets.lookup(table, key) do
      [] -> 
        :ets.insert(table, default)
        elem(default, 1)
      _ -> 
        :ets.update_counter(table, key, update_op)
    end
  end
  
  @doc """
  Create a new table.
  """
  def new(name, options) do
    :ets.new(name, options)
  end
end