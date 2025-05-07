defmodule Bardo.AppConfig do
  @moduledoc """
  Configuration management for the Bardo application.
  """

  @default_keyspace :bardo

  @doc """
  Get environment variable from the default keyspace.
  """
  @spec get_env(atom()) :: term()
  def get_env(key) do
    get_env(@default_keyspace, key)
  end

  @doc """
  Get environment variable from a specific keyspace.
  """
  @spec get_env(atom(), atom()) :: term()
  def get_env(keyspace, key) do
    {:ok, value} = Application.fetch_env(keyspace, key)
    value
  end

  @doc """
  Get environment variable with default value.
  """
  @spec get_env(atom(), atom(), term()) :: term()
  def get_env(keyspace, key, default) do
    Application.get_env(keyspace, key, default)
  end

  @doc """
  Set environment variable in the default keyspace.
  """
  @spec set_env(atom(), term()) :: :ok
  def set_env(key, value) do
    Application.put_env(@default_keyspace, key, value)
  end

  @doc """
  Set environment variable in a specific keyspace.
  """
  @spec set_env(atom(), atom(), term()) :: :ok
  def set_env(keyspace, key, value) do
    Application.put_env(keyspace, key, value)
  end

  @doc """
  Get all environment variables from the default keyspace.
  """
  @spec get_all() :: [{atom(), term()}]
  def get_all do
    Application.get_all_env(@default_keyspace)
  end

  @doc """
  Get all environment variables from a specific keyspace.
  """
  @spec get_all(atom()) :: [{atom(), term()}]
  def get_all(keyspace) do
    Application.get_all_env(keyspace)
  end
end