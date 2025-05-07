defmodule Bardo.Logger do
  @moduledoc """
  Custom logging functionality for the Bardo system.
  
  Provides structured logging capabilities and integration with the standard
  Elixir Logger. Also includes filters for specialized log handling.
  """
  
  require Logger
  
  @typedoc """
  A structured log entry with component information.
  """
  @type log_body :: {
    in_mod :: atom(),      # The subcomponent taking action and logging data
    what :: atom(),        # A value defining the purpose
    result :: :ok | :error, # The result of a given operation being reported
    details :: String.t() | nil, # Additional information explaining the result
    params :: [any()] | []  # Additional parameters for the above
  }
  
  @doc """
  Log a debug message.
  """
  @spec debug(log_body() | String.t()) :: :ok
  def debug(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.debug(fn -> format_structured_log(:debug, module, function, status, details, data) end)
  end
  
  def debug(message) when is_binary(message) do
    Logger.debug(message)
  end
  
  @doc """
  Log an info message.
  """
  @spec info(log_body() | String.t()) :: :ok
  def info(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.info(fn -> format_structured_log(:info, module, function, status, details, data) end)
  end
  
  def info(message) when is_binary(message) do
    Logger.info(message)
  end
  
  @doc """
  Log a notice message.
  """
  @spec notice(log_body() | String.t()) :: :ok
  def notice(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.notice(fn -> format_structured_log(:notice, module, function, status, details, data) end)
  end
  
  def notice(message) when is_binary(message) do
    Logger.notice(message)
  end
  
  @doc """
  Log a warning message.
  """
  @spec warning(log_body() | String.t()) :: :ok
  def warning(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.warning(fn -> format_structured_log(:warning, module, function, status, details, data) end)
  end
  
  def warning(message) when is_binary(message) do
    Logger.warning(message)
  end
  
  @doc """
  Log an error message.
  """
  @spec error(log_body() | String.t()) :: :ok
  def error(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.error(fn -> format_structured_log(:error, module, function, status, details, data) end)
  end
  
  def error(message) when is_binary(message) do
    Logger.error(message)
  end
  
  @doc """
  Log a critical message.
  """
  @spec critical(log_body() | String.t()) :: :ok
  def critical(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.critical(fn -> format_structured_log(:critical, module, function, status, details, data) end)
  end
  
  def critical(message) when is_binary(message) do
    Logger.critical(message)
  end
  
  @doc """
  Log an alert message.
  """
  @spec alert(log_body() | String.t()) :: :ok
  def alert(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.alert(fn -> format_structured_log(:alert, module, function, status, details, data) end)
  end
  
  def alert(message) when is_binary(message) do
    Logger.alert(message)
  end
  
  @doc """
  Log an emergency message.
  """
  @spec emergency(log_body() | String.t()) :: :ok
  def emergency(message) when is_tuple(message) do
    {module, function, status, details, data} = normalize_message(message)
    Logger.emergency(fn -> format_structured_log(:emergency, module, function, status, details, data) end)
  end
  
  def emergency(message) when is_binary(message) do
    Logger.emergency(message)
  end
  
  @doc """
  Filter to only show logs from scape modules.
  """
  @spec scape_filter(map(), :log | :stop) :: map() | :ignore | :stop
  def scape_filter(log_event, action) when action in [:log, :stop] do
    filter_scape(log_event, on_match(action, log_event))
  end
  
  def scape_filter(_log_event, action) do
    raise ArgumentError, "Invalid action: #{inspect(action)}"
  end
  
  @doc """
  Filter to only show status messages or error results.
  """
  @spec status_filter(map(), :log | :stop) :: map() | :ignore | :stop
  def status_filter(log_event, action) when action in [:log, :stop] do
    filter_status(log_event, on_match(action, log_event))
  end
  
  def status_filter(_log_event, action) do
    raise ArgumentError, "Invalid action: #{inspect(action)}"
  end
  
  # Private Functions
  
  defp normalize_message({in_mod, what, result, details, params}) do
    {in_mod, what, result, details, params}
  end
  
  defp normalize_message({in_mod, what, result, details}) do
    {in_mod, what, result, details, []}
  end
  
  defp normalize_message(message) do
    {:undefined, :undefined, :undefined, inspect(message), []}
  end
  
  # Function removed to eliminate warning
  # This function was for future functionality but was causing warnings
  # 
  # defp _format_message(module, function, status, message, data) do
  #   data_str = if Enum.empty?(data), do: "", else: " data=#{inspect(data)}"
  #   "[#{module}:#{function}] (#{status}) #{message}#{data_str}"
  # end
  
  defp format_structured_log(level, in_mod, what, result, details, params) do
    %{
      level: level,
      in: in_mod,
      what: what,
      result: result,
      details: details,
      params: List.to_tuple(params)
    }
  end
  
  defp filter_scape(%{msg: {:report, %{in: :scape}}}, on_match), do: on_match
  defp filter_scape(_, _), do: :ignore
  
  defp filter_status(%{msg: {:report, %{what: :status}}}, on_match), do: on_match
  defp filter_status(%{msg: {:report, %{result: :error}}}, on_match), do: on_match
  defp filter_status(_, _), do: :ignore
  
  defp on_match(:log, log_event), do: log_event
  defp on_match(:stop, _), do: :stop
end