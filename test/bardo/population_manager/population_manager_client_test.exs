defmodule Bardo.PopulationManager.PopulationManagerClientTest do
  use ExUnit.Case
  
  alias Bardo.PopulationManager.PopulationManagerClient
  alias Bardo.PopulationManager.PopulationManagerSupervisor
  alias Bardo.PopulationManager.PopulationManager
  
  @agent_id {:agent, 5.92352455}
  @specie_id {:specie, 5.92352455}
  
  setup do
    # Create mock modules using our helper
    alias Bardo.TestHelper.Mocks
    Mocks.setup_mocks([
      Bardo.PopulationManager.PopulationManager,
      Bardo.PopulationManager.PopulationManagerSupervisor
    ])
    
    :ok
  end
  
  test "new_run starts a new population manager run" do
    # Set up mock for start_population_manager
    :meck.expect(PopulationManagerSupervisor, :start_population_manager, fn -> {:ok, self()} end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.new_run()
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManagerSupervisor)
  end
  
  test "restart_run restarts the population manager" do
    # Set up mock for restart_population_manager
    :meck.expect(PopulationManagerSupervisor, :restart_population_manager, fn -> {:ok, self()} end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.restart_run()
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManagerSupervisor)
  end
  
  test "agent_terminated notifies the population manager" do
    # Set up mock for agent_terminated
    :meck.expect(PopulationManager, :agent_terminated, fn (@agent_id) -> :ok end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.agent_terminated(@agent_id)
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManager)
  end
  
  test "set_goal_reached notifies the population manager" do
    # Set up mock for set_goal_reached
    :meck.expect(PopulationManager, :set_goal_reached, fn -> :ok end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.set_goal_reached()
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManager)
  end
  
  test "set_evaluations sends evaluation data to the population manager" do
    # Set up mock for set_evaluations
    :meck.expect(PopulationManager, :set_evaluations, fn (@specie_id, 1, 1, 1) -> :ok end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.set_evaluations(@specie_id, 1, 1, 1)
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManager)
  end
  
  test "validation_complete notifies the population manager" do
    # Set up mock for validation_complete
    :meck.expect(PopulationManager, :validation_complete, fn (@agent_id, 1.0) -> :ok end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.validation_complete(@agent_id, 1.0)
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManager)
  end
  
  test "set_op_tag sets the operation tag" do
    # Set up mock for set_op_tag
    :meck.expect(PopulationManager, :set_op_tag, fn (:pause) -> :ok end)
    
    # Call the function under test
    assert :ok = PopulationManagerClient.set_op_tag(:pause)
    
    # Verify the mock was called correctly
    assert :meck.validate(PopulationManager)
  end
end