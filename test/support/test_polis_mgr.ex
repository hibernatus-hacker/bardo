defmodule Bardo.TestSupport.TestPolisMgr do
  @moduledoc """
  Test implementation of PolisMgr for use in examples tests.
  
  This provides a consistent mock for use in tests without requiring
  module redefinition.
  """
  
  def setup(config) do
    # Send message to test process to verify function was called
    send(self(), {:setup_called, config.id})
    {:ok, %{id: config.id}}
  end
end