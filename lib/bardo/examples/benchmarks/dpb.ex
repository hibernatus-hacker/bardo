defmodule Bardo.Examples.Benchmarks.Dpb do
  @moduledoc """
  Main setup module for the Double Pole Balancing benchmark.
  
  This module provides functions to configure and run
  DPB experiments with and without damping. DPB is a common
  benchmark problem in neuroevolution and reinforcement learning.
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.ExperimentManager.ExperimentManagerClient
  alias Bardo.Examples.Benchmarks.Dpb.{DpbWDamping, DpbWoDamping}
  
  @doc """
  Configure a Double Pole Balancing experiment with damping.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of agents (default: 100)
  - generations: Number of generations to evolve (default: 50)
  - max_steps: Maximum simulation steps for successful balance (default: 100000)
  
  Returns the experiment configuration map.
  """
  @spec configure_with_damping(atom(), pos_integer(), pos_integer(), pos_integer()) :: map()
  def configure_with_damping(experiment_id, population_size \\ 100, generations \\ 50, max_steps \\ 100000) do
    %{
      id: experiment_id,
      backup_frequency: 5,
      iterations: generations,
      
      # Scape configuration
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :dpb_scape,
          type: :private,
          sector_module: Bardo.Examples.Benchmarks.Dpb.Dpb,
          module_parameters: %{
            max_steps: max_steps
          }
        }
      ],
      
      # Define the population
      populations: [
        %{
          id: :dpb_population,
          size: population_size,
          morphology: DpbWDamping,
          mutation_rate: 0.1,
          mutation_operators: [
            {:mutate_weights, :gaussian, 0.3},  # 30% chance of weight mutation
            {:add_neuron, 0.05},                # 5% chance to add a neuron
            {:add_connection, 0.1},             # 10% chance to add a connection
            {:remove_connection, 0.05},         # 5% chance to remove a connection
            {:remove_neuron, 0.02}              # 2% chance to remove a neuron
          ],
          selection_algorithm: "TournamentSelectionAlgorithm",
          tournament_size: 5,
          elite_fraction: 0.1,                 # Keep top 10% unchanged
          scape_list: [:dpb_scape],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1       # Run each agent once per generation
        }
      ]
    }
  end
  
  @doc """
  Configure a Double Pole Balancing experiment without damping.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of agents (default: 100)
  - generations: Number of generations to evolve (default: 50)
  - max_steps: Maximum simulation steps for successful balance (default: 100000)
  
  Returns the experiment configuration map.
  """
  @spec configure_without_damping(atom(), pos_integer(), pos_integer(), pos_integer()) :: map()
  def configure_without_damping(experiment_id, population_size \\ 100, generations \\ 50, max_steps \\ 100000) do
    # Start with the damping configuration as a base
    config = configure_with_damping(experiment_id, population_size, generations, max_steps)
    
    # Replace the morphology with the version without damping
    updated_populations = update_in(
      config.populations,
      [Access.at(0)],
      fn pop -> %{pop | morphology: DpbWoDamping} end
    )
    
    %{config | populations: updated_populations}
  end
  
  @doc """
  Run a Double Pole Balancing experiment with damping.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of agents (default: 100)
  - generations: Number of generations to evolve (default: 50)
  - max_steps: Maximum simulation steps for successful balance (default: 100000)
  
  Returns :ok if the experiment was started successfully.
  """
  @spec run_with_damping(atom(), pos_integer(), pos_integer(), pos_integer()) :: :ok | {:error, any()}
  def run_with_damping(experiment_id, population_size \\ 100, generations \\ 50, max_steps \\ 100000) do
    # Create the experiment configuration
    config = configure_with_damping(experiment_id, population_size, generations, max_steps)
    
    # Set up the experiment
    case PolisMgr.setup(config) do
      {:ok, _} ->
        # Start the experiment
        ExperimentManagerClient.start(experiment_id)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Run a Double Pole Balancing experiment without damping.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of agents (default: 100)
  - generations: Number of generations to evolve (default: 50)
  - max_steps: Maximum simulation steps for successful balance (default: 100000)
  
  Returns :ok if the experiment was started successfully.
  """
  @spec run_without_damping(atom(), pos_integer(), pos_integer(), pos_integer()) :: :ok | {:error, any()}
  def run_without_damping(experiment_id, population_size \\ 100, generations \\ 50, max_steps \\ 100000) do
    # Create the experiment configuration
    config = configure_without_damping(experiment_id, population_size, generations, max_steps)
    
    # Set up the experiment
    case PolisMgr.setup(config) do
      {:ok, _} ->
        # Start the experiment
        ExperimentManagerClient.start(experiment_id)
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Test the best solution from a completed experiment.
  
  Parameters:
  - experiment_id: ID of the completed experiment
  - max_steps: Maximum simulation steps for the test run (default: 100000)
  - visualize: Whether to enable visualization (default: false)
  
  Returns results of the test run.
  """
  @spec test_best_solution(atom(), pos_integer(), boolean()) :: map() | {:error, any()}
  def test_best_solution(experiment_id, max_steps \\ 100000, visualize \\ false) do
    # Load the experiment data from the database
    case Models.read(experiment_id, :experiment) do
      {:ok, experiment} ->
        # Extract information about the best agent
        population_id = Models.get(experiment, [:populations, 0, :id])
        
        # Determine the morphology
        morphology = if experiment_uses_damping?(experiment) do
          DpbWDamping
        else
          DpbWoDamping
        end
        
        # Get the best genotype from the population
        case fetch_best_genotype(population_id) do
          {:ok, genotype} ->
            # Configure test simulation
            test_config = %{
              id: :"#{experiment_id}_test",
              
              # Scape configuration
              scapes: [
                %{
                  module: Bardo.ScapeManager.Scape,
                  name: :dpb_test_scape,
                  type: :private,
                  sector_module: Bardo.Examples.Benchmarks.Dpb.Dpb,
                  module_parameters: %{
                    max_steps: max_steps,
                    visualize: visualize
                  }
                }
              ],
              
              # Load the best agent
              agents: [
                %{
                  id: :best_balancer,
                  genotype: genotype,
                  morphology: morphology,
                  scape_name: :dpb_test_scape
                }
              ]
            }
            
            # Run the test
            {:ok, _} = PolisMgr.setup(test_config)
            
            # Wait for test to complete
            Process.sleep(5000)
            
            # Retrieve results
            retrieve_test_results(:"#{experiment_id}_test")
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Helper function to determine if experiment uses damping
  defp experiment_uses_damping?(experiment) do
    # Check the morphology module in the experiment configuration
    morphology = Models.get(experiment, [:populations, 0, :morphology])
    morphology == "DpbWDamping" or morphology == DpbWDamping
  end
  
  # Fetch the best genotype from a population
  defp fetch_best_genotype(population_id) do
    case Models.read(population_id, :population) do
      {:ok, population} ->
        # Get the genotype with the highest fitness
        best_genotype = Models.get(population, :population)
                        |> Enum.max_by(fn genotype -> 
                          fitness = Models.get(genotype, :fitness)
                          if is_number(fitness), do: fitness, else: 0.0
                        end)
        
        {:ok, best_genotype}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Retrieve test results from the database
  defp retrieve_test_results(test_id) do
    case Models.read(test_id, :test) do
      {:ok, test} ->
        # Extract agent results
        agent_id = Models.get(test, [:agents, 0, :id])
        
        case Models.read(agent_id, :agent) do
          {:ok, agent} ->
            # Get metrics
            %{
              steps: Models.get(agent, [:metrics, :steps]),
              success: Models.get(agent, [:metrics, :success]),
              jiggle: Models.get(agent, [:metrics, :jiggle])
            }
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end