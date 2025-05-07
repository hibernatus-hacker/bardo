defmodule Bardo.ExperimentManager.ExperimentManagerClientTest do
  use ExUnit.Case
  
  alias Bardo.ExperimentManager.ExperimentManagerClient
  alias Bardo.ExperimentManager.ExperimentManager
  alias Bardo.TestSupport.MockHelper
  
  setup do
    # Set up mock for the ExperimentManager
    MockHelper.setup_mocks([ExperimentManager])
    :ok
  end
  
  test "start_run functionality" do
    # Set up mock for run/0
    :meck.expect(ExperimentManager, :run, fn -> :ok end)
    
    # Call the function under test
    assert :ok = ExperimentManagerClient.start_run()
    
    # Verify the mock was called correctly
    assert :meck.validate(ExperimentManager)
  end
  
  test "run_complete functionality" do
    # Set up mock for complete/2
    population_id = :population_id
    :meck.expect(ExperimentManager, :complete, fn (^population_id, []) -> :ok end)
    
    # Call the function under test
    assert :ok = ExperimentManagerClient.run_complete(population_id, [])
    
    # Verify the mock was called correctly
    assert :meck.validate(ExperimentManager)
  end
end