defmodule Bardo.DBMock do
  @moduledoc """
  Mock implementation of the DB module for testing.
  """
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{data: %{}}}
  end

  def write(key, value, type) do
    GenServer.call(__MODULE__, {:write, key, value, type})
  end

  def read(key, type) do
    GenServer.call(__MODULE__, {:read, key, type})
  end

  def delete(key, type) do
    GenServer.call(__MODULE__, {:delete, key, type})
  end

  def handle_call({:write, key, value, _type}, _from, state) do
    new_data = Map.put(state.data, key, value)
    {:reply, :ok, %{state | data: new_data}}
  end

  def handle_call({:read, key, _type}, _from, state) do
    value = Map.get(state.data, key, :not_found)
    {:reply, value, state}
  end

  def handle_call({:delete, key, _type}, _from, state) do
    new_data = Map.delete(state.data, key)
    {:reply, :ok, %{state | data: new_data}}
  end
end