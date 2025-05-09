defmodule Bardo.ExperimentManager.ExperimentManagerTest do
  @moduledoc """
  Tests for the ExperimentManager module.
  
  Note: To run these tests, you need to have all dependencies installed:
  
  ```
  mix deps.get
  ```
  
  The tests require a proper application environment as defined in config/test.exs.
  """
  
  use ExUnit.Case, async: false
  
  alias Bardo.ExperimentManager.ExperimentManager
  alias Bardo.Persistence
  
  # We need to mock the PopulationManagerSupervisor to avoid actually starting populations
  # during tests. This is a simplistic mock for the tests.
  defmodule MockPopulationManager do
    def start_population(population_id, _config) do
      Process.send_after(
        ExperimentManager,
        {:complete, population_id, %{best_fitness: 0.85, best_solution: %{id: "test_solution"}}},
        100
      )
      
      {:ok, self()}
    end
  end
  
  setup do
    # Define a fitness function for testing
    fitness_fn = fn _solution -> 0.85 end

    # Start DB first - using ETS implementation for tests
    {:ok, _db_pid} = start_supervised(Bardo.DB)

    # Start the ExperimentManager GenServer process
    {:ok, _pid} = start_supervised(
      {ExperimentManager, [name: ExperimentManager]}
    )

    # Start the MockPopulationManager instead of the real one
    # Inject the mock through the ExperimentManager
    original_module = ExperimentManager.population_manager_module()
    ExperimentManager.set_population_manager_module(__MODULE__.MockPopulationManager)

    # For tests that need clean up
    on_exit(fn ->
      # Restore the original module
      ExperimentManager.set_population_manager_module(original_module)

      # Clean up any test experiments
      :ok
    end)

    %{fitness_fn: fitness_fn}
  end
  
  describe "experiment lifecycle" do
    test "creates, configures, and starts an experiment", %{fitness_fn: fitness_fn} do
      # Create a new experiment
      {:ok, experiment_id} = ExperimentManager.new_experiment("Test Experiment")
      
      # Configure the experiment
      config = %{
        runs: 1,
        generations: 10,
        population_size: 10
      }
      :ok = ExperimentManager.configure(experiment_id, config)
      
      # Set the fitness function
      :ok = ExperimentManager.start_evaluation(experiment_id, fitness_fn)
      
      # Get the experiment status before starting
      {:not_started, status} = ExperimentManager.status(experiment_id)
      assert status.name == "Test Experiment"
      
      # Start the experiment - we're using the mock so it won't actually run a real population
      # In a real test with proper mocks, we'd verify the population is started
      # but for this test, we'll test the happy path
      :ok = ExperimentManager.start(experiment_id)
      
      # Verify the experiment is in progress
      {:in_progress, status} = ExperimentManager.status(experiment_id)
      assert status.name == "Test Experiment"
      assert status.total_runs == 1
      
      # Wait a bit for the mock population to complete
      Process.sleep(200)
      
      # Verify the experiment completed
      {:completed, status} = ExperimentManager.status(experiment_id)
      assert status.name == "Test Experiment"
      assert status.runs == 1
      assert Map.has_key?(status.results, :best_fitness)
      
      # Get the best solution
      {:ok, solution} = ExperimentManager.get_best_solution(experiment_id)
      assert solution.id == "test_solution"
    end
  end
  
  describe "experiment management" do
    test "lists active experiments" do
      # Create a couple of experiments
      {:ok, experiment_id1} = ExperimentManager.new_experiment("Test Experiment 1")
      {:ok, experiment_id2} = ExperimentManager.new_experiment("Test Experiment 2")
      
      # List active experiments
      {:ok, active_experiments} = ExperimentManager.list_active()
      
      # Both should be active (not_started)
      assert experiment_id1 in active_experiments
      assert experiment_id2 in active_experiments
    end
    
    test "lists all experiments" do
      # Create a couple of experiments
      {:ok, experiment_id1} = ExperimentManager.new_experiment("Test Experiment List 1")
      {:ok, experiment_id2} = ExperimentManager.new_experiment("Test Experiment List 2")
      
      # List all experiments
      {:ok, all_experiments} = ExperimentManager.list_all()
      
      # Find our experiments in the list
      exp1 = Enum.find(all_experiments, fn e -> e.id == experiment_id1 end)
      exp2 = Enum.find(all_experiments, fn e -> e.id == experiment_id2 end)
      
      # Verify they exist
      assert exp1 != nil
      assert exp2 != nil
      
      # Verify their names
      assert exp1.name == "Test Experiment List 1"
      assert exp2.name == "Test Experiment List 2"
    end
    
    test "stops an experiment" do
      # Create and start an experiment
      {:ok, experiment_id} = ExperimentManager.new_experiment("Test Stop Experiment")
      
      # Configure and set fitness function
      :ok = ExperimentManager.configure(experiment_id, %{runs: 2})
      :ok = ExperimentManager.start_evaluation(experiment_id, fn _ -> 0.5 end)
      
      # Start the experiment
      :ok = ExperimentManager.start(experiment_id)
      
      # Stop the experiment
      :ok = ExperimentManager.stop(experiment_id)
      
      # Verify it's stopped
      {status, _} = ExperimentManager.status(experiment_id)
      assert status in [:stopped, :completed]
    end
  end
  
  describe "results management" do
    test "exports experiment results", %{fitness_fn: fitness_fn} do
      # Create a temporary file for the test
      tmp_file = "/tmp/test_experiment_results_#{:rand.uniform(1000)}.json"
      
      # Create, configure, and run an experiment
      {:ok, experiment_id} = ExperimentManager.new_experiment("Export Test")
      :ok = ExperimentManager.configure(experiment_id, %{runs: 1})
      :ok = ExperimentManager.start_evaluation(experiment_id, fitness_fn)
      :ok = ExperimentManager.start(experiment_id)
      
      # Wait for completion
      Process.sleep(200)
      
      # Export the results
      :ok = ExperimentManager.export_results(experiment_id, tmp_file, :json)
      
      # Verify the file exists
      assert File.exists?(tmp_file)
      
      # Clean up
      File.rm(tmp_file)
    end
  end
  
  describe "error handling" do
    test "handles non-existent experiment" do
      result = ExperimentManager.status("nonexistent_experiment")
      assert match?({:error, _}, result)
      
      result = ExperimentManager.configure("nonexistent_experiment", %{})
      assert match?({:error, _}, result)
      
      result = ExperimentManager.start("nonexistent_experiment")
      assert match?({:error, _}, result)
    end
    
    test "requires fitness function before starting" do
      # Create a new experiment
      {:ok, experiment_id} = ExperimentManager.new_experiment("No Fitness Test")
      
      # Try to start without setting fitness function
      result = ExperimentManager.start(experiment_id)
      assert match?({:error, _}, result)
    end
  end
end