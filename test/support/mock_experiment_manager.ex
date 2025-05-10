defmodule Bardo.TestSupport.MockExperimentManager do
  @moduledoc """
  Mock implementation of ExperimentManager for testing.
  """
  
  @doc """
  Start a population with the given ID and configuration.
  This mock immediately returns success and schedules a completion event.
  """
  def start_population(population_id, _config) do
    # Create a full mock trace with properly formatted data expected by the ExperimentManager
    mock_trace = %{
      best_fitness: 0.85,
      best_solution: %{id: "test_solution"},
      avg_fitness: 0.75,
      generations: 10,
      status: :completed
    }

    # Handle the message properly - use cast to avoid blocking
    # Need to use GenServer.cast directly to avoid module redefinition conflicts
    GenServer.cast(
      Bardo.ExperimentManager.ExperimentManager,
      {:complete, population_id, mock_trace}
    )

    # Return success immediately
    {:ok, self()}
  end
end