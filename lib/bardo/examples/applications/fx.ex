defmodule Bardo.Examples.Applications.Fx do
  @moduledoc """
  Main setup module for the Forex (FX) trading experiment.
  
  This module provides functions to configure and run
  FX trading simulations using neuroevolution to optimize trading strategies.
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.ExperimentManager.ExperimentManagerClient
  alias Bardo.Examples.Applications.Fx.FxMorphology
  
  @doc """
  Configure a Forex trading experiment.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of trading agents (default: 50)
  - data_window: Size of the data window for training (default: 5000)
  - generations: Number of generations to evolve (default: 50)
  
  Returns the experiment configuration map.
  """
  @spec configure(atom(), pos_integer(), pos_integer(), pos_integer()) :: map()
  def configure(experiment_id, population_size \\ 50, data_window \\ 5000, generations \\ 50) do
    %{
      id: experiment_id,
      backup_frequency: 5,
      iterations: generations,
      
      # Scape configuration
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :fx_scape,
          type: :private,
          sector_module: Bardo.Examples.Applications.Fx.Fx,
          module_parameters: %{
            window_size: data_window
          }
        }
      ],
      
      # Define the population
      populations: [
        %{
          id: :fx_population,
          size: population_size,
          morphology: FxMorphology,
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
          scape_list: [:fx_scape],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1       # Run each agent once per generation
        }
      ]
    }
  end
  
  @doc """
  Run a Forex trading experiment with the given configuration.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - population_size: Number of trading agents (default: 50)
  - data_window: Size of the data window for training (default: 5000)
  - generations: Number of generations to evolve (default: 50)
  
  Returns :ok if the experiment was started successfully.
  """
  @spec run(atom(), pos_integer(), pos_integer(), pos_integer()) :: :ok | {:error, any()}
  def run(experiment_id, population_size \\ 50, data_window \\ 5000, generations \\ 50) do
    # Create the experiment configuration
    config = configure(experiment_id, population_size, data_window, generations)
    
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
  Test the best trading agent from a completed experiment on out-of-sample data.
  
  Parameters:
  - experiment_id: ID of the completed experiment
  - test_window_start: Starting index for test data (default: 5000)
  - test_window_size: Size of the test data window (default: 1000)
  
  Returns a map with test results.
  """
  @spec test_best_agent(atom(), pos_integer(), pos_integer()) :: map() | {:error, any()}
  def test_best_agent(experiment_id, test_window_start \\ 5000, test_window_size \\ 1000) do
    # Load the experiment data from the database
    case Models.read(experiment_id, :experiment) do
      {:ok, experiment} ->
        # Extract information about the best agent
        population_id = Models.get(experiment, [:populations, 0, :id])
        
        # Get the best genotype from the population
        case fetch_best_genotype(population_id) do
          {:ok, genotype} ->
            # Configure test simulation
            test_config = %{
              id: :"#{experiment_id}_test",
              
              # Scape configuration (using different data window)
              scapes: [
                %{
                  module: Bardo.ScapeManager.Scape,
                  name: :fx_test_scape,
                  type: :private,
                  sector_module: Bardo.Examples.Applications.Fx.Fx,
                  module_parameters: %{
                    window_size: test_window_size,
                    window_start: test_window_start
                  }
                }
              ],
              
              # Load the best agent
              agents: [
                %{
                  id: :best_trader,
                  genotype: genotype,
                  morphology: FxMorphology,
                  scape_name: :fx_test_scape
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
  
  # Fetch the best genotype from a population
  defp fetch_best_genotype(population_id) do
    case Models.read(population_id, :population) do
      {:ok, population} ->
        # Get the genotype with the highest fitness
        best_genotype = Models.get(population, :population)
                        |> Enum.max_by(fn genotype -> 
                          case Models.get(genotype, :fitness) do
                            [profit | _] -> profit
                            _ -> -1000.0  # Default for invalid fitness
                          end
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
        # Extract trading results
        agent_id = Models.get(test, [:agents, 0, :id])
        
        case Models.read(agent_id, :agent) do
          {:ok, agent} ->
            # Get metrics
            %{
              profit_loss: Models.get(agent, [:metrics, :profit_loss]),
              win_rate: Models.get(agent, [:metrics, :win_rate]),
              max_drawdown: Models.get(agent, [:metrics, :max_drawdown]),
              trade_count: Models.get(agent, [:metrics, :trade_count])
            }
            
          {:error, reason} ->
            {:error, reason}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end