defmodule Bardo.Logger do
  @moduledoc """
  Custom logging functionality for the Bardo system.
  
  Provides structured logging capabilities and integration with the standard
  Elixir Logger.
  """
  
  require Logger
  
  @doc """
  Log a debug message.
  """
  @spec debug(tuple() | String.t()) :: :ok
  def debug(message) when is_tuple(message) do
    {module, function, status, message, data} = normalize_message(message)
    Logger.debug(format_message(module, function, status, message, data))
  end
  
  def debug(message) when is_binary(message) do
    Logger.debug(message)
  end
  
  @doc """
  Log an info message.
  """
  @spec info(tuple() | String.t()) :: :ok
  def info(message) when is_tuple(message) do
    {module, function, status, message, data} = normalize_message(message)
    Logger.info(format_message(module, function, status, message, data))
  end
  
  def info(message) when is_binary(message) do
    Logger.info(message)
  end
  
  @doc """
  Log a warning message.
  """
  @spec warning(tuple() | String.t()) :: :ok
  def warning(message) when is_tuple(message) do
    {module, function, status, message, data} = normalize_message(message)
    Logger.warning(format_message(module, function, status, message, data))
  end
  
  def warning(message) when is_binary(message) do
    Logger.warning(message)
  end
  
  @doc """
  Log an error message.
  """
  @spec error(tuple() | String.t()) :: :ok
  def error(message) when is_tuple(message) do
    {module, function, status, message, data} = normalize_message(message)
    Logger.error(format_message(module, function, status, message, data))
  end
  
  def error(message) when is_binary(message) do
    Logger.error(message)
  end
  
  # Private Functions
  
  defp normalize_message({module, function, status, message, data}) do
    {module, function, status, message, data}
  end
  
  defp normalize_message({module, function, status, message}) do
    {module, function, status, message, []}
  end
  
  defp normalize_message(message) do
    {:undefined, :undefined, :undefined, inspect(message), []}
  end
  
  defp format_message(module, function, status, message, data) do
    data_str = if Enum.empty?(data), do: "", else: " data=#{inspect(data)}"
    "[#{module}:#{function}] (#{status}) #{message}#{data_str}"
  end
end