defmodule Bardo.DBPostgresTest do
  use ExUnit.Case, async: false
  
  alias Bardo.Schemas.{
    Experiment,
    Population,
    Genotype,
    Result,
    DistributedNode,
    DistributedJob
  }
  
  # This test is marked as pending because it requires a PostgreSQL database
  # To run it, you need to:
  # 1. Have PostgreSQL running
  # 2. Set the DATABASE_URL environment variable
  # 3. Run the test with: mix test test/bardo/db_postgres_test.exs --include pending
  @moduletag :pending
  
  setup do
    # Skip this test if we don't have PostgreSQL configured
    if System.get_env("DATABASE_URL") do
      # Start the repo
      {:ok, _} = Application.ensure_all_started(:ecto_sql)
      {:ok, _} = Bardo.Repo.start_link()
      
      # Start the adapter
      {:ok, pid} = Bardo.DBPostgres.start_link()
      
      on_exit(fn ->
        # Clean up after the test
        Process.exit(pid, :normal)
      end)
      
      :ok
    else
      :skip
    end
  end
  
  describe "PostgreSQL database adapter" do
    test "can store and read experiments" do
      experiment_id = "test_experiment_#{:rand.uniform(1000)}"
      experiment_data = %{
        name: "Test Experiment",
        description: "A test experiment",
        config: %{population_size: 10},
        status: "pending"
      }
      
      # Store the experiment
      assert :ok = Bardo.DBPostgres.store(:experiment, experiment_id, experiment_data)
      
      # Read it back
      experiment = Bardo.DBPostgres.read(experiment_id, :experiment)
      assert experiment != nil
      assert experiment.name == "Test Experiment"
      assert experiment.status == "pending"
      
      # List experiments
      {:ok, experiments} = Bardo.DBPostgres.list(:experiment)
      assert Enum.any?(experiments, fn {id, _} -> id == String.to_atom(experiment_id) end)
      
      # Delete it
      assert :ok = Bardo.DBPostgres.delete(experiment_id, :experiment)
      
      # Verify it's gone
      assert Bardo.DBPostgres.read(experiment_id, :experiment) == nil
    end
    
    test "can store and read genotypes" do
      # First create an experiment and population
      experiment_id = "test_experiment_#{:rand.uniform(1000)}"
      Bardo.DBPostgres.store(:experiment, experiment_id, %{
        name: "Test Experiment",
        description: "A test experiment",
        config: %{},
        status: "running"
      })
      
      population_id = "test_population_#{:rand.uniform(1000)}"
      Bardo.DBPostgres.store(:population, population_id, %{
        experiment_id: experiment_id,
        name: "Test Population",
        generation: 1,
        config: %{},
        status: "running"
      })
      
      # Now create a genotype
      genotype_id = "test_genotype_#{:rand.uniform(1000)}"
      genotype_data = %{
        population_id: population_id,
        data: %{
          neurons: %{
            "input_1" => %{layer: :input},
            "hidden_1" => %{layer: :hidden},
            "output_1" => %{layer: :output}
          },
          connections: %{
            "conn_1" => %{from_id: "input_1", to_id: "hidden_1", weight: 0.5},
            "conn_2" => %{from_id: "hidden_1", to_id: "output_1", weight: 0.7}
          }
        },
        fitness: 0.85,
        fitness_details: %{error: 0.15},
        metadata: %{created_at: DateTime.utc_now() |> DateTime.to_iso8601()}
      }
      
      # Store the genotype
      assert :ok = Bardo.DBPostgres.store(:genotype, genotype_id, genotype_data)
      
      # Read it back
      genotype = Bardo.DBPostgres.read(genotype_id, :genotype)
      assert genotype != nil
      assert genotype.fitness == 0.85
      assert genotype.population_id == population_id
      
      # Cleanup
      assert :ok = Bardo.DBPostgres.delete(genotype_id, :genotype)
      assert :ok = Bardo.DBPostgres.delete(population_id, :population)
      assert :ok = Bardo.DBPostgres.delete(experiment_id, :experiment)
    end
    
    test "can manage distributed nodes" do
      node_name = "test_node@localhost"
      node_info = %{
        hostname: "localhost",
        system_info: %{
          os_type: :unix,
          system_architecture: "x86_64-unknown-linux-gnu",
          otp_release: "25"
        }
      }
      
      # Register a node
      assert :ok = Bardo.DBPostgres.register_node(node_name, node_info)
      
      # List nodes
      {:ok, nodes} = Bardo.DBPostgres.list_nodes()
      assert Enum.any?(nodes, fn node -> node.node_name == node_name end)
      
      # Update node status
      assert :ok = Bardo.DBPostgres.update_node_status(node_name, "busy")
      
      # Send heartbeat
      assert :ok = Bardo.DBPostgres.heartbeat(node_name)
      
      # Cleanup
      node = Enum.find(nodes, fn node -> node.node_name == node_name end)
      if node do
        Bardo.Repo.delete(node)
      end
    end
    
    test "can manage distributed jobs" do
      # First register a node
      node_name = "test_node@localhost"
      Bardo.DBPostgres.register_node(node_name, %{hostname: "localhost"})
      
      # Create a job
      job_id = "test_job_#{:rand.uniform(1000)}"
      job_config = %{
        task: "train",
        parameters: %{
          population_size: 10,
          generations: 5
        }
      }
      
      assert :ok = Bardo.DBPostgres.create_job(job_id, job_config)
      
      # Assign the job to a node
      assert :ok = Bardo.DBPostgres.assign_job(job_id, node_name)
      
      # Get job info
      {:ok, job} = Bardo.DBPostgres.get_job_info(job_id)
      assert job.status == "running"
      assert job.assigned_node_name == node_name
      
      # Update job status
      results = %{
        success: true,
        fitness: 0.95,
        generations: 5,
        elapsed_time: 10.5
      }
      assert :ok = Bardo.DBPostgres.update_job_status(job_id, "completed", results)
      
      # List jobs
      {:ok, completed_jobs} = Bardo.DBPostgres.list_jobs("completed")
      assert Enum.any?(completed_jobs, fn job -> job.id == job_id end)
      
      # Cleanup
      job = Enum.find(completed_jobs, fn job -> job.id == job_id end)
      if job do
        Bardo.Repo.delete(job)
      end
      
      # Also cleanup the node
      {:ok, nodes} = Bardo.DBPostgres.list_nodes()
      node = Enum.find(nodes, fn node -> node.node_name == node_name end)
      if node do
        Bardo.Repo.delete(node)
      end
    end
  end
end