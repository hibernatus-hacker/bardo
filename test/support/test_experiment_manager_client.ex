defmodule Bardo.TestSupport.TestExperimentManagerClient do
  @moduledoc """
  Test implementation of ExperimentManagerClient for use in examples tests.
  
  This provides a consistent mock for use in tests without requiring
  module redefinition.
  """
  
  def start(experiment_id) do
    # Send message to test process to verify function was called
    send(self(), {:start_called, experiment_id})
    :ok
  end
end