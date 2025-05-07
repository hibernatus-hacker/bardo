defmodule Bardo.LoggerTest do
  use ExUnit.Case
  
  alias Bardo.Logger
  
  test "basic logging functions work correctly" do
    # Test each log level function
    assert :ok = Logger.debug({:debug_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.info({:info_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.notice({:notice_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.warning({:warning_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.error({:error_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.critical({:critical_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.alert({:alert_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
    
    assert :ok = Logger.emergency({:emergency_component, :testing, :ok, "testing details",
      ["test", "parameters", 1234]})
  end
  
  test "scape_filter passes through scape logs" do
    # Create a log event with a scape component
    log_event = %{
      level: :info,
      msg: {:report, %{in: :scape, what: :testing, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    # The filter should pass through this log event
    assert ^log_event = Logger.scape_filter(log_event, :log)
    
    # Non-scape logs should be ignored
    other_log_event = %{
      level: :info,
      msg: {:report, %{in: :info_component, what: :testing, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    assert :ignore = Logger.scape_filter(other_log_event, :log)
  end
  
  test "status_filter passes through status logs and error results" do
    # Create a log event with a status what field
    status_log_event = %{
      level: :info,
      msg: {:report, %{in: :info_component, what: :status, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    # The filter should pass through this log event
    assert ^status_log_event = Logger.status_filter(status_log_event, :log)
    
    # Error result logs should also pass through
    error_log_event = %{
      level: :info,
      msg: {:report, %{in: :info_component, what: :testing, result: :error, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    assert ^error_log_event = Logger.status_filter(error_log_event, :log)
    
    # Normal logs should be ignored
    normal_log_event = %{
      level: :info,
      msg: {:report, %{in: :info_component, what: :testing, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    assert :ignore = Logger.status_filter(normal_log_event, :log)
  end
  
  test "filters with stop action return :stop for matching logs" do
    log_event = %{
      level: :info,
      msg: {:report, %{in: :scape, what: :testing, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    assert :stop = Logger.scape_filter(log_event, :stop)
  end
  
  test "filter rejects invalid actions" do
    log_event = %{
      level: :info,
      msg: {:report, %{in: :scape, what: :testing, result: :ok, details: "testing details",
        params: List.to_tuple(["test", "parameters", 1234])}},
      meta: %{}
    }
    
    assert_raise ArgumentError, fn ->
      Logger.scape_filter(log_event, :invalid_action)
    end
  end
end