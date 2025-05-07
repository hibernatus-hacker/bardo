defmodule Bardo.Examples.Applications.Flatland do
  @moduledoc """
  Main setup module for the Flatland experiment.
  
  This module provides functions to configure and run
  Flatland simulations with evolving predator and prey agents.
  """
  
  alias Bardo.PolisMgr
  alias Bardo.Models
  alias Bardo.ExperimentManager.ExperimentManagerClient
  alias Bardo.Examples.Applications.Flatland.{Predator, Prey}
  
  @doc """
  Configure a basic Flatland experiment with predator and prey.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - predator_population_size: Number of predator agents
  - prey_population_size: Number of prey agents
  - plant_quantity: Number of plants in the environment
  - simulation_steps: Number of simulation steps per evaluation
  - generations: Number of generations to evolve (defaults to 50)
  
  Returns the experiment configuration map.
  """
  @spec configure(atom(), pos_integer(), pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: map()
  def configure(experiment_id, predator_population_size, prey_population_size, plant_quantity, simulation_steps, generations \\ 50) do
    %{
      id: experiment_id,
      backup_frequency: 5,
      iterations: generations,
      simulation_steps: simulation_steps,
      
      # Scape configuration
      scapes: [
        %{
          module: Bardo.ScapeManager.Scape,
          name: :flatland,
          type: :private,
          sector_module: Bardo.Examples.Applications.Flatland.Flatland,
          module_parameters: %{
            plant_quantity: plant_quantity
          }
        }
      ],
      
      # Define the predator population
      populations: [
        %{
          id: :predator_population,
          size: predator_population_size,
          morphology: Predator,
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
          scape_list: [:flatland],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1       # Run each agent once per generation
        },
        
        # Define the prey population
        %{
          id: :prey_population,
          size: prey_population_size,
          morphology: Prey,
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
          scape_list: [:flatland],
          population_to_evaluate: 1.0,         # Evaluate 100% of population
          evaluations_per_generation: 1       # Run each agent once per generation
        }
      ]
    }
  end
  
  @doc """
  Run a Flatland experiment with the given configuration.
  
  Parameters:
  - experiment_id: Unique identifier for the experiment
  - predator_population_size: Number of predator agents (default: 20)
  - prey_population_size: Number of prey agents (default: 20)
  - plant_quantity: Number of plants in the environment (default: 40)
  - simulation_steps: Number of simulation steps per evaluation (default: 1000)
  - generations: Number of generations to evolve (default: 50)
  
  Returns :ok if the experiment was started successfully.
  """
  @spec run(atom(), pos_integer(), pos_integer(), pos_integer(), pos_integer(), pos_integer()) :: :ok | {:error, any()}
  def run(experiment_id, predator_population_size \\ 20, prey_population_size \\ 20, plant_quantity \\ 40, simulation_steps \\ 1000, generations \\ 50) do
    # Create the experiment configuration
    config = configure(experiment_id, predator_population_size, prey_population_size, plant_quantity, simulation_steps, generations)
    
    # Print experiment setup information
    IO.puts("\n=== Flatland Predator-Prey Simulation ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Predator population: #{predator_population_size}")
    IO.puts("Prey population: #{prey_population_size}")
    IO.puts("Plant quantity: #{plant_quantity}")
    IO.puts("Simulation steps: #{simulation_steps}")
    IO.puts("Generations: #{generations}")
    IO.puts("Starting experiment...\n")
    
    # Set up the experiment
    case PolisMgr.setup(config) do
      {:ok, _} ->
        # Start the experiment
        ExperimentManagerClient.start(experiment_id)
        
        # This is synchronous, so we can assume the experiment is running
        IO.puts("\nFlatland experiment is running. Progress will be shown in the logs.")
        IO.puts("After completion, you can visualize the best agents with:")
        IO.puts("  Bardo.Examples.Applications.Flatland.visualize(#{inspect(experiment_id)})\n")
        :ok
        
      {:error, reason} ->
        IO.puts("\nError starting Flatland experiment: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Load and visualize the best agents from a completed Flatland experiment.
  
  Parameters:
  - experiment_id: ID of the completed experiment
  
  Returns :ok if visualization was started successfully.
  """
  @spec visualize(atom()) :: :ok | {:error, any()}
  def visualize(experiment_id) do
    IO.puts("\n=== Visualizing Flatland Best Agents ===")
    IO.puts("Experiment ID: #{experiment_id}")
    IO.puts("Loading experiment data...\n")
    
    # Load the experiment data from the database
    case Models.read(experiment_id, :experiment) do
      {:ok, experiment} ->
        # Extract information about the best agents
        predator_pop_id = Models.get(experiment, [:populations, 0, :id])
        prey_pop_id = Models.get(experiment, [:populations, 1, :id])
        
        IO.puts("Retrieving best predator and prey genotypes...")
        
        # Get the best genotypes from each population
        {:ok, predator_genotype} = fetch_best_genotype(predator_pop_id)
        {:ok, prey_genotype} = fetch_best_genotype(prey_pop_id)
        
        IO.puts("Successfully retrieved best genotypes")
        IO.puts("Setting up visualization environment...")
        
        # Configure visualization
        vis_config = %{
          id: :"#{experiment_id}_visualization",
          
          # Scape configuration (same as training but with visualization enabled)
          scapes: [
            %{
              module: Bardo.ScapeManager.Scape,
              name: :flatland_vis,
              type: :private,
              sector_module: Bardo.Examples.Applications.Flatland.Flatland,
              module_parameters: %{
                plant_quantity: 40,
                visualization: true
              }
            }
          ],
          
          # Load the best predator and prey agents
          agents: [
            %{
              id: :best_predator,
              genotype: predator_genotype,
              morphology: Predator,
              scape_name: :flatland_vis
            },
            %{
              id: :best_prey,
              genotype: prey_genotype,
              morphology: Prey,
              scape_name: :flatland_vis
            }
          ]
        }
        
        # Start the visualization
        {:ok, _} = PolisMgr.setup(vis_config)
        
        IO.puts("\n🌍 Flatland visualization started!")
        IO.puts("Watching predator and prey agents interact in the environment.")
        IO.puts("The visualizer will run until you stop the program.")
        :ok
        
      {:error, reason} ->
        IO.puts("\nError reading experiment data: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  # Fetch the best genotype from a population
  defp fetch_best_genotype(population_id) do
    case Models.read(population_id, :population) do
      {:ok, population} ->
        # Get the genotype with the highest fitness
        best_genotype = Models.get(population, :population)
                        |> Enum.max_by(fn genotype -> Models.get(genotype, :fitness) end)
        
        {:ok, best_genotype}
        
      {:error, reason} ->
        {:error, reason}
    end
  end
end