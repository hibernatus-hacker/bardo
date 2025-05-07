defmodule Bardo.ExperimentManager.ExperimentManagerClientTest do
  use ExUnit.Case
  
  alias Bardo.ExperimentManager.ExperimentManagerClient
  alias Bardo.ExperimentManager.ExperimentManager
  alias Bardo.TestHelper.Mocks
  
  setup do
    # Create mock modules using our helper
    Mocks.setup_mocks([Bardo.ExperimentManager.ExperimentManager])
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