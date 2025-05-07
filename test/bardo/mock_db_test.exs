defmodule Bardo.MockDBTest do
  @moduledoc """
  This module creates a mock DB adapter for tests that don't require a real database.
  This allows us to run tests without setting up PostgreSQL.
  """
  use ExUnit.Case
  
  # Define a mock DB module for tests
  defmodule MockDB do
    @moduledoc false
    
    # In-memory storage for tests
    @storage_ref :mock_db_storage
    
    # Initialize the storage
    def init do
      :ets.new(@storage_ref, [:set, :public, :named_table])
    end
    
    # Store a value
    def store(type, id, value) do
      :ets.insert(@storage_ref, {{type, id}, value})
      :ok
    end
    
    # Retrieve a value
    def fetch(type, id) do
      case :ets.lookup(@storage_ref, {type, id}) do
        [{{^type, ^id}, value}] -> {:ok, value}
        [] -> {:error, :not_found}
      end
    end
    
    # Delete a value
    def delete(type, id) do
      :ets.delete(@storage_ref, {type, id})
      :ok
    end
    
    # List values of a type
    def list(type) do
      :ets.match_object(@storage_ref, {{type, :_}, :_})
      |> Enum.map(fn {{^type, id}, value} -> {id, value} end)
    end
    
    # Check if a value exists
    def exists?(type, id) do
      case :ets.lookup(@storage_ref, {type, id}) do
        [_] -> true
        [] -> false
      end
    end
    
    # Basic backup for tests
    def backup do
      :ok
    end
  end
  
  # Replace the DB module for tests
  setup do
    # Store the original DB module
    orig_db = Application.get_env(:bardo, :db_module, Bardo.DB)
    
    # Replace with our mock
    Application.put_env(:bardo, :db_module, MockDB)
    MockDB.init()
    
    on_exit(fn ->
      # Restore the original DB module
      Application.put_env(:bardo, :db_module, orig_db)
    end)
    
    :ok
  end
  
  # A simple test to verify the mock works
  test "mock DB works" do
    assert :ok == MockDB.store(:test, "test_id", %{value: 42})
    assert {:ok, %{value: 42}} == MockDB.fetch(:test, "test_id")
  end
end