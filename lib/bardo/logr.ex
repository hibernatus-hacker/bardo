defmodule Bardo.LogR do
  @moduledoc """
  A logging module for the Bardo system.
  This is a simplified implementation for testing.
  """
  
  require Logger
  
  def debug(message) do
    Logger.debug(format_message(message))
  end
  
  def info(message) do
    Logger.info(format_message(message))
  end
  
  def notice(message) do
    Logger.info(format_message(message))
  end
  
  def warning(message) do
    Logger.warning(format_message(message))
  end
  
  def error(message) do
    Logger.error(format_message(message))
  end
  
  defp format_message({component, action, result, details, params}) do
    param_str = if is_list(params) and length(params) > 0 do
      " params=#{inspect(params)}"
    else
      ""
    end
    
    "[#{component}:#{action}] (#{result}) #{details}#{param_str}"
  end
  
  defp format_message(message) when is_binary(message) do
    message
  end
  
  defp format_message(message) do
    inspect(message)
  end
end