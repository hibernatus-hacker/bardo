defmodule Bardo.AppConfigTest do
  use ExUnit.Case
  
  alias Bardo.AppConfig
  
  setup do
    # Set up test environment variables
    Application.put_env(:bardo, :test, :testing1)
    Application.put_env(:other_space, :test_two, :testing2)
    Application.put_env(:other_space, :test_other, :testing3)
    Application.put_env(:bardo, :test_other, :testing4)
    
    :ok
  end
  
  test "get_env/1 retrieves a value from the default keyspace" do
    assert :testing1 == AppConfig.get_env(:test)
  end
  
  test "get_env/2 retrieves a value from a specific keyspace" do
    assert :testing2 == AppConfig.get_env(:other_space, :test_two)
  end
  
  test "get_env/3 retrieves a value from a specific keyspace with default" do
    assert :testing2 == AppConfig.get_env(:other_space, :test_two, :default)
    assert :default == AppConfig.get_env(:other_space, :non_existent, :default)
  end
  
  test "get_all/0 retrieves all values from the default keyspace" do
    all_values = AppConfig.get_all()
    
    # Check that our test values are in the returned values
    assert Keyword.get(all_values, :test) == :testing1
    assert Keyword.get(all_values, :test_other) == :testing4
  end
  
  test "get_all/1 retrieves all values from a specific keyspace" do
    values = AppConfig.get_all(:other_space)
    
    # Sort both lists to ensure consistent order for comparison
    assert Enum.sort([test_other: :testing3, test_two: :testing2]) == Enum.sort(values)
  end
  
  test "set_env/2 sets a value in the default keyspace" do
    AppConfig.set_env(:new_key, :new_value)
    assert :new_value == AppConfig.get_env(:new_key)
  end
  
  test "set_env/3 sets a value in a specific keyspace" do
    AppConfig.set_env(:custom_space, :custom_key, :custom_value)
    assert :custom_value == AppConfig.get_env(:custom_space, :custom_key)
  end
end