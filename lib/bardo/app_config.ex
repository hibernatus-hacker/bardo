defmodule Bardo.AppConfig do
  @moduledoc """
  Configuration management for the Bardo application.
  """

  @doc """
  Get environment variable from application config.
  """
  @spec get_env(atom()) :: term()
  def get_env(key) do
    Application.get_env(:bardo, key)
  end

  @doc """
  Get environment variable with default value.
  """
  @spec get_env(atom(), term()) :: term()
  def get_env(key, default) do
    Application.get_env(:bardo, key, default)
  end

  @doc """
  Set environment variable.
  """
  @spec set_env(atom(), term()) :: :ok
  def set_env(key, value) do
    Application.put_env(:bardo, key, value)
  end
end