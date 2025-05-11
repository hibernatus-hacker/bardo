defmodule Bardo.Core do
  @moduledoc """
  Core API for Bardo neuroevolution library.
  
  This module serves as the main entry point for users who are importing Bardo
  as a dependency. It provides a clean, well-documented API that focuses on the
  essential neuroevolution functionality while hiding implementation details.
  
  ## Key Features
  
  * **Neural Network Creation** - Define neural network architectures with sensors and actuators
  * **Evolutionary Training** - Train neural networks through evolutionary algorithms
  * **Agent Management** - Create and manage neuroevolutionary agents
  * **Experiment Control** - Run controlled experiments with multiple populations
  
  ## Usage Example
  
  ```elixir
  # Define a simple neural network morphology
  morphology = Bardo.Core.create_morphology(%{
    name: "XOR Network",
    dimensions: 2,
    inputs: 2,
    outputs: 1,
    hidden_layers: [3]
  })
  
  # Create an experiment
  {:ok, experiment_id} = Bardo.Core.create_experiment("XOR Experiment")
  
  # Configure the experiment with our morphology
  :ok = Bardo.Core.configure_experiment(experiment_id, %{
    morphology: morphology,
    population_size: 50,
    generations: 100
  })
  
  # Define a fitness function for XOR
  fitness_fn = fn agent ->
    accuracy = Bardo.Core.evaluate_agent(agent, [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ])
    1.0 - accuracy  # Convert accuracy to error (lower is better)
  end
  
  # Set the fitness function and run the experiment
  :ok = Bardo.Core.set_fitness_function(experiment_id, fitness_fn)
  :ok = Bardo.Core.run_experiment(experiment_id)
  
  # Get the best solution when the experiment completes
  {:ok, solution} = Bardo.Core.get_best_solution(experiment_id)
  ```
  """
  
  alias Bardo.Morphology
  alias Bardo.ExperimentManager.ExperimentManager
  alias Bardo.AgentManager.Cortex
  alias Bardo.AgentManager.AgentManagerClient
  alias Bardo.PopulationManager.PopulationManagerClient
  alias Bardo.ScapeManager.ScapeManagerClient

  #
  # Morphology API - Neural Network Architecture
  #

  @doc """
  Creates a new neural network morphology with the given options.
  
  This function defines the structure of the neural network, including:
  * Number of inputs and outputs
  * Hidden layer configuration
  * Sensor and actuator specifications
  * Substrate and connection patterns
  
  ## Parameters
    * `opts` - A map of options for the morphology (see options below)
    
  ## Options
    * `:name` - The name of the morphology (default: "Generic Morphology")
    * `:description` - A description of the morphology
    * `:dimensions` - Number of dimensions in the substrate (default: 2)
    * `:inputs` - Number of input neurons (default: 1)
    * `:outputs` - Number of output neurons (default: 1)
    * `:hidden_layers` - List of hidden layer sizes (default: [3])
    * `:activation_functions` - List of activation functions (default: [:sigmoid])
    * `:substrate_type` - Type of substrate, one of: [:cartesian, :hypercube, :hypersphere, :custom] (default: :cartesian)
    * `:connection_pattern` - Type of connection pattern, one of: [:feedforward, :recurrent, :dense, :custom] (default: :feedforward)
    * `:plasticity` - Type of plasticity, one of: [:none, :hebbian, :stdp, :abcn, :iterative] (default: :none)
    * `:sensors` - List of custom sensor specifications
    * `:actuators` - List of custom actuator specifications
    * `:parameters` - Additional parameters for the morphology
    
  ## Returns
    * A morphology map with the specified configuration
    
  ## Examples
  
      # Create a simple XOR network morphology
      morphology = Bardo.Core.create_morphology(%{
        name: "XOR Network",
        dimensions: 2,
        inputs: 2,
        outputs: 1,
        hidden_layers: [3]
      })
  """
  @spec create_morphology(map()) :: Morphology.t()
  def create_morphology(opts \\ %{}) do
    Morphology.new(opts)
  end
  
  @doc """
  Adds a sensor to a morphology.
  
  ## Parameters
    * `morphology` - The morphology to add the sensor to
    * `sensor_opts` - Options for the sensor
    
  ## Sensor Options
    * `:name` - The name of the sensor (required, as atom)
    * `:type` - The type of sensor (default: :standard)
    * `:vl` - Vector length, number of outputs from this sensor (required)
    * `:parameters` - Additional parameters for the sensor
    
  ## Returns
    * An updated morphology with the new sensor
    
  ## Examples
  
      # Add a vision sensor to a morphology
      morphology = Bardo.Core.create_morphology()
      updated_morphology = Bardo.Core.add_sensor(morphology, %{
        name: :vision,
        vl: 100,
        parameters: %{fov: 120}
      })
  """
  @spec add_sensor(Morphology.t(), map()) :: Morphology.t()
  def add_sensor(morphology, sensor_opts) do
    # Create a sensor from the options
    sensor = Bardo.Models.sensor(sensor_opts)
    Morphology.add_sensor(morphology, sensor)
  end
  
  @doc """
  Adds an actuator to a morphology.
  
  ## Parameters
    * `morphology` - The morphology to add the actuator to
    * `actuator_opts` - Options for the actuator
    
  ## Actuator Options
    * `:name` - The name of the actuator (required, as atom)
    * `:type` - The type of actuator (default: :standard)
    * `:vl` - Vector length, number of inputs to this actuator (required)
    * `:parameters` - Additional parameters for the actuator
    
  ## Returns
    * An updated morphology with the new actuator
    
  ## Examples
  
      # Add a motor actuator to a morphology
      morphology = Bardo.Core.create_morphology()
      updated_morphology = Bardo.Core.add_actuator(morphology, %{
        name: :motor,
        vl: 2,
        parameters: %{max_speed: 10.0}
      })
  """
  @spec add_actuator(Morphology.t(), map()) :: Morphology.t()
  def add_actuator(morphology, actuator_opts) do
    # Create an actuator from the options
    actuator = Bardo.Models.actuator(actuator_opts)
    Morphology.add_actuator(morphology, actuator)
  end

  @doc """
  Saves a morphology to persistent storage for later use.
  
  ## Parameters
    * `morphology` - The morphology to save
    
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
  
      morphology = Bardo.Core.create_morphology(%{name: "XOR"})
      Bardo.Core.save_morphology(morphology)
  """
  @spec save_morphology(Morphology.t()) :: :ok | {:error, term()}
  def save_morphology(morphology) do
    Morphology.save(morphology)
  end
  
  @doc """
  Loads a morphology from persistent storage.
  
  ## Parameters
    * `id` - The ID of the morphology to load
    
  ## Returns
    * `{:ok, morphology}` on success
    * `{:error, reason}` on failure
    
  ## Examples
  
      Bardo.Core.load_morphology("morph_123456789")
  """
  @spec load_morphology(binary()) :: {:ok, Morphology.t()} | {:error, term()}
  def load_morphology(id) do
    Morphology.load(id)
  end
  
  @doc """
  Lists all saved morphologies.
  
  ## Returns
    * `{:ok, [morphology]}` on success
    * `{:error, reason}` on failure
    
  ## Examples
  
      {:ok, morphologies} = Bardo.Core.list_morphologies()
  """
  @spec list_morphologies() :: {:ok, [Morphology.t()]} | {:error, term()}
  def list_morphologies do
    Morphology.list()
  end

  #
  # Experiment API - Running Evolutionary Processes
  #
  
  @doc """
  Creates a new experiment with the given name.
  
  Experiments are the top-level container for evolutionary runs. They manage:
  * Population configuration
  * Fitness evaluation
  * Running multiple evolutionary trials
  * Collecting and analyzing results
  
  ## Parameters
    * `name` - Name of the experiment
    
  ## Returns
    * `{:ok, experiment_id}` - Experiment ID of the created experiment
    * `{:error, reason}` - If there was an error creating the experiment
    
  ## Examples
  
      {:ok, experiment_id} = Bardo.Core.create_experiment("XOR Experiment")
  """
  @spec create_experiment(String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_experiment(name) do
    ExperimentManager.new_experiment(name)
  end
  
  @doc """
  Configures an existing experiment with the given parameters.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to configure
    * `config` - Configuration parameters for the experiment
    
  ## Configuration Options
    * `:runs` - Number of separate evolutionary runs to perform (default: 1)
    * `:generations` - Maximum number of generations per run (default: 100)
    * `:population_size` - Number of individuals in the population (default: 50)
    * `:morphology` - The morphology to use (either a morphology map or an ID)
    * `:selection_method` - Method for selecting parents, one of: [:tournament, :roulette, :rank] (default: :tournament)
    * `:crossover_rate` - Probability of crossover (default: 0.7)
    * `:mutation_rate` - Probability of mutation (default: 0.3)
    * `:elitism` - Fraction of top individuals to preserve unchanged (default: 0.1)
    * `:backup_flag` - Whether to back up best solutions (default: true)
    * `:visualize` - Whether to generate visualizations (default: false)
    * `:distributed` - Whether to use distributed evolution (default: false)
    
  ## Returns
    * `:ok` - If the experiment was configured successfully
    * `{:error, reason}` - If there was an error configuring the experiment
    
  ## Examples
  
      :ok = Bardo.Core.configure_experiment(experiment_id, %{
        runs: 5,
        generations: 50,
        population_size: 100,
        morphology: morphology,
        selection_method: :tournament
      })
  """
  @spec configure_experiment(String.t(), map()) :: :ok | {:error, term()}
  def configure_experiment(experiment_id, config) do
    ExperimentManager.configure(experiment_id, config)
  end
  
  @doc """
  Sets the fitness function for evaluating solutions in an experiment.
  
  The fitness function receives an agent (neural network) and must return a numerical
  fitness score. Higher values indicate better fitness.
  
  ## Parameters
    * `experiment_id` - ID of the experiment
    * `fitness_function` - Function to evaluate fitness of solutions
    
  ## Returns
    * `:ok` - If the fitness function was set successfully
    * `{:error, reason}` - If there was an error setting the fitness function
    
  ## Examples
  
      # Define a fitness function for XOR
      fitness_fn = fn agent ->
        inputs = [[0,0], [0,1], [1,0], [1,1]]
        expected = [[0], [1], [1], [0]]
        
        # Calculate error across all cases
        errors = Enum.zip(inputs, expected)
        |> Enum.map(fn {input, output} ->
          actual = Bardo.Core.activate_agent(agent, input)
          Enum.zip(actual, output)
          |> Enum.map(fn {a, e} -> :math.pow(a - e, 2) end)
          |> Enum.sum()
        end)
        
        # Return fitness (1 / (1 + error)) so higher is better
        1.0 / (1.0 + Enum.sum(errors))
      end
      
      :ok = Bardo.Core.set_fitness_function(experiment_id, fitness_fn)
  """
  @spec set_fitness_function(String.t(), function()) :: :ok | {:error, term()}
  def set_fitness_function(experiment_id, fitness_function) do
    ExperimentManager.start_evaluation(experiment_id, fitness_function)
  end
  
  @doc """
  Starts an experiment with the given ID.
  
  This begins the evolutionary process according to the experiment configuration.
  The function returns immediately, but the experiment continues to run in the
  background until completion.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to start
    
  ## Returns
    * `:ok` - If the experiment was started successfully
    * `{:error, reason}` - If there was an error starting the experiment
    
  ## Examples
  
      :ok = Bardo.Core.run_experiment(experiment_id)
  """
  @spec run_experiment(String.t()) :: :ok | {:error, term()}
  def run_experiment(experiment_id) do
    ExperimentManager.start(experiment_id)
  end
  
  @doc """
  Gets the status of an experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to get status for
    
  ## Returns
    * `{:not_started, info}` - If the experiment has not started yet
    * `{:in_progress, info}` - If the experiment is in progress, with status details
    * `{:completed, info}` - If the experiment is completed, with results
    * `{:stopped, info}` - If the experiment was stopped before completion
    * `{:error, reason}` - If there was an error getting the status
    
  ## Examples
  
      # Check experiment status
      Bardo.Core.experiment_status(experiment_id)
  """
  @spec experiment_status(String.t()) :: 
    {:not_started, map()} | 
    {:in_progress, map()} | 
    {:completed, map()} | 
    {:stopped, map()} | 
    {:error, term()}
  def experiment_status(experiment_id) do
    ExperimentManager.status(experiment_id)
  end
  
  @doc """
  Gets the best solution from a completed experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to get the best solution from
    
  ## Returns
    * `{:ok, solution}` - Best solution found in the experiment
    * `{:error, reason}` - If there was an error getting the best solution
    
  ## Examples
  
      {:ok, solution} = Bardo.Core.get_best_solution(experiment_id)
      # Use the solution for inference
      output = Bardo.Core.activate_agent(solution, [0.5, 0.5])
  """
  @spec get_best_solution(String.t()) :: {:ok, map()} | {:error, term()}
  def get_best_solution(experiment_id) do
    ExperimentManager.get_best_solution(experiment_id)
  end
  
  @doc """
  Stops an ongoing experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to stop
    
  ## Returns
    * `:ok` - If the experiment was stopped successfully
    * `{:error, reason}` - If there was an error stopping the experiment
    
  ## Examples
  
      :ok = Bardo.Core.stop_experiment(experiment_id)
  """
  @spec stop_experiment(String.t()) :: :ok | {:error, term()}
  def stop_experiment(experiment_id) do
    ExperimentManager.stop(experiment_id)
  end
  
  @doc """
  Lists all experiments.
  
  ## Returns
    * `{:ok, [experiment]}` - List of all experiments with their basic information
    * `{:error, reason}` - If there was an error getting the experiments
    
  ## Examples
  
      # Get all experiments
      Bardo.Core.list_experiments()
  """
  @spec list_experiments() :: {:ok, [map()]} | {:error, term()}
  def list_experiments do
    ExperimentManager.list_all()
  end
  
  @doc """
  Exports experiment results to a file.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to export
    * `file_path` - Path to save the results to
    * `format` - Format to export in (:csv, :json, or :binary)
    
  ## Returns
    * `:ok` - If the results were exported successfully
    * `{:error, reason}` - If there was an error exporting the results
    
  ## Examples
  
      :ok = Bardo.Core.export_results(experiment_id, "results.json", :json)
  """
  @spec export_results(String.t(), String.t(), atom()) :: :ok | {:error, term()}
  def export_results(experiment_id, file_path, format \\ :json) do
    ExperimentManager.export_results(experiment_id, file_path, format)
  end
  
  #
  # Agent API - Working with Neural Networks
  #
  
  @doc """
  Activates a neural network agent with the given inputs.
  
  This function passes input values through the neural network and returns
  the resulting output values.
  
  ## Parameters
    * `agent` - The agent (neural network) to activate
    * `inputs` - List of input values for the network
    
  ## Returns
    * List of output values from the network
    
  ## Examples
  
      outputs = Bardo.Core.activate_agent(agent, [0.0, 1.0])
      # For an XOR network with one output, this might return [1.0]
  """
  @spec activate_agent(map(), list()) :: list()
  def activate_agent(agent, inputs) do
    Cortex.activate(agent, inputs)
  end
  
  @doc """
  Evaluates an agent's performance on a set of test cases.
  
  This function runs the agent on multiple input/output pairs and returns
  an accuracy score between 0.0 and 1.0.
  
  ## Parameters
    * `agent` - The agent (neural network) to evaluate
    * `test_cases` - List of {input, expected_output} tuples
    
  ## Returns
    * Accuracy score between 0.0 and 1.0
    
  ## Examples
  
      # Evaluate XOR test cases
      test_cases = [
        {[0.0, 0.0], [0.0]},
        {[0.0, 1.0], [1.0]},
        {[1.0, 0.0], [1.0]},
        {[1.0, 1.0], [0.0]}
      ]
      
      accuracy = Bardo.Core.evaluate_agent(agent, test_cases)
      # A perfect XOR network would return 1.0
  """
  @spec evaluate_agent(map(), list()) :: float()
  def evaluate_agent(agent, test_cases) do
    # Run agent on all test cases
    errors = Enum.map(test_cases, fn {inputs, expected} ->
      outputs = Cortex.activate(agent, inputs)
      Enum.zip(outputs, expected)
      |> Enum.map(fn {o, e} -> abs(o - e) end)
      |> Enum.sum()
    end)
    
    # Calculate average error and convert to accuracy
    avg_error = Enum.sum(errors) / length(errors)
    max_error = length(test_cases) # Assume worst case is 1.0 error per output
    
    # Return accuracy (1.0 - normalized error)
    1.0 - (avg_error / max_error)
  end
  
  @doc """
  Saves an agent to a file for later use.
  
  ## Parameters
    * `agent` - The agent (neural network) to save
    * `file_path` - Path to save the agent to
    
  ## Returns
    * `:ok` - If the agent was saved successfully
    * `{:error, reason}` - If there was an error saving the agent
    
  ## Examples
  
      :ok = Bardo.Core.save_agent(agent, "xor_agent.bin")
  """
  @spec save_agent(map(), String.t()) :: :ok | {:error, term()}
  def save_agent(agent, file_path) do
    AgentManagerClient.export_agent(agent, file_path)
  end
  
  @doc """
  Loads an agent from a file.
  
  ## Parameters
    * `file_path` - Path to load the agent from
    
  ## Returns
    * `{:ok, agent}` - If the agent was loaded successfully
    * `{:error, reason}` - If there was an error loading the agent
    
  ## Examples
  
      {:ok, agent} = Bardo.Core.load_agent("xor_agent.bin")
  """
  @spec load_agent(String.t()) :: {:ok, map()} | {:error, term()}
  def load_agent(file_path) do
    AgentManagerClient.import_agent(file_path)
  end
  
  #
  # Population API - Working with groups of agents
  #
  
  @doc """
  Creates a new population of neural network agents.
  
  ## Parameters
    * `population_id` - Unique identifier for the population
    * `config` - Configuration for the population
    
  ## Returns
    * `{:ok, pid}` - If the population was created successfully
    * `{:error, reason}` - If there was an error creating the population
    
  ## Examples
  
      {:ok, pid} = Bardo.Core.create_population("xor_population", %{
        morphology: morphology,
        population_size: 50,
        fitness_function: fn agent -> ... end
      })
  """
  @spec create_population(String.t(), map()) :: {:ok, pid()} | {:error, term()}
  def create_population(population_id, config) do
    PopulationManagerClient.start_population(population_id, config)
  end
  
  @doc """
  Evolves a population for the specified number of generations.
  
  ## Parameters
    * `population_id` - ID of the population to evolve
    * `generations` - Number of generations to evolve
    
  ## Returns
    * `:ok` - If the population was evolved successfully
    * `{:error, reason}` - If there was an error evolving the population
    
  ## Examples
  
      :ok = Bardo.Core.evolve_population("xor_population", 50)
  """
  @spec evolve_population(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def evolve_population(population_id, generations) do
    PopulationManagerClient.evolve(population_id, generations)
  end
  
  @doc """
  Gets the best agent from a population.
  
  ## Parameters
    * `population_id` - ID of the population
    
  ## Returns
    * `{:ok, agent}` - The best agent in the population
    * `{:error, reason}` - If there was an error getting the agent
    
  ## Examples
  
      {:ok, best_agent} = Bardo.Core.get_best_agent("xor_population")
  """
  @spec get_best_agent(String.t()) :: {:ok, map()} | {:error, term()}
  def get_best_agent(population_id) do
    PopulationManagerClient.get_best(population_id)
  end
  
  #
  # Scape API - Virtual Environments for Agents
  #
  
  @doc """
  Creates a new scape (virtual environment) for agents to interact with.
  
  ## Parameters
    * `scape_id` - Unique identifier for the scape
    * `config` - Configuration for the scape
    
  ## Returns
    * `{:ok, pid}` - If the scape was created successfully
    * `{:error, reason}` - If there was an error creating the scape
    
  ## Examples
  
      {:ok, pid} = Bardo.Core.create_scape("flatland", %{
        width: 100,
        height: 100,
        agents: 10
      })
  """
  @spec create_scape(String.t(), map()) :: {:ok, pid()} | {:error, term()}
  def create_scape(scape_id, config) do
    ScapeManagerClient.create_scape(scape_id, config)
  end
  
  @doc """
  Adds an agent to a scape.
  
  ## Parameters
    * `scape_id` - ID of the scape
    * `agent_id` - ID of the agent to add
    * `agent` - The agent to add
    * `position` - Position to place the agent at
    
  ## Returns
    * `:ok` - If the agent was added successfully
    * `{:error, reason}` - If there was an error adding the agent
    
  ## Examples
  
      :ok = Bardo.Core.add_agent_to_scape("flatland", "agent1", agent, [50, 50])
  """
  @spec add_agent_to_scape(String.t(), String.t(), map(), list()) :: :ok | {:error, term()}
  def add_agent_to_scape(scape_id, agent_id, agent, position) do
    ScapeManagerClient.add_agent(scape_id, agent_id, agent, position)
  end
  
  @doc """
  Steps a scape forward in time, updating all agents.
  
  ## Parameters
    * `scape_id` - ID of the scape
    * `steps` - Number of time steps to advance
    
  ## Returns
    * `:ok` - If the scape was stepped successfully
    * `{:error, reason}` - If there was an error stepping the scape
    
  ## Examples
  
      :ok = Bardo.Core.step_scape("flatland", 10)
  """
  @spec step_scape(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def step_scape(scape_id, steps \\ 1) do
    ScapeManagerClient.step(scape_id, steps)
  end
  
  #
  # Helper functions - Simplified APIs for common tasks
  #
  
  @doc """
  Runs a complete experiment with minimal setup.
  
  This is a convenience function that creates an experiment, sets it up,
  and runs it with common default parameters.
  
  ## Parameters
    * `name` - Name of the experiment
    * `morphology` - The morphology to use
    * `fitness_function` - Function to evaluate fitness
    * `opts` - Additional options to override defaults
    
  ## Returns
    * `{:ok, experiment_id}` - ID of the created experiment
    * `{:error, reason}` - If there was an error
    
  ## Examples
  
      # Create and run an XOR experiment
      {:ok, experiment_id} = Bardo.Core.quick_experiment(
        "XOR Experiment",
        morphology,
        fn agent -> 
          # Fitness function implementation
        end,
        %{population_size: 100, generations: 50}
      )
  """
  @spec quick_experiment(String.t(), Morphology.t(), function(), map()) :: 
    {:ok, String.t()} | {:error, term()}
  def quick_experiment(name, morphology, fitness_function, opts \\ %{}) do
    # Default options
    defaults = %{
      runs: 1,
      population_size: 50,
      generations: 100,
      selection_method: :tournament,
      crossover_rate: 0.7,
      mutation_rate: 0.3,
      elitism: 0.1
    }
    
    # Merge provided options
    config = Map.merge(defaults, opts)
    |> Map.put(:morphology, morphology)
    
    # Create and set up experiment
    with {:ok, experiment_id} <- create_experiment(name),
         :ok <- configure_experiment(experiment_id, config),
         :ok <- set_fitness_function(experiment_id, fitness_function),
         :ok <- run_experiment(experiment_id) do
      {:ok, experiment_id}
    end
  end
  
  @doc """
  Solves the XOR problem as a simple demonstration.
  
  This is a convenience function that creates and runs an experiment
  to solve the XOR problem, a classic benchmark in neural networks.
  
  ## Parameters
    * `opts` - Options to override defaults
    
  ## Returns
    * `{:ok, agent}` - The best solution found
    * `{:error, reason}` - If there was an error
    
  ## Examples
  
      {:ok, xor_agent} = Bardo.Core.solve_xor()
      outputs = Bardo.Core.activate_agent(xor_agent, [1.0, 0.0])
      # Should return approximately [1.0]
  """
  @spec solve_xor(map()) :: {:ok, map()} | {:error, term()}
  def solve_xor(opts \\ %{}) do
    # Create XOR morphology
    morphology = create_morphology(%{
      name: "XOR Network",
      dimensions: 2,
      inputs: 2,
      outputs: 1,
      hidden_layers: [3]
    })
    
    # XOR test cases
    test_cases = [
      {[0.0, 0.0], [0.0]},
      {[0.0, 1.0], [1.0]},
      {[1.0, 0.0], [1.0]},
      {[1.0, 1.0], [0.0]}
    ]
    
    # Define fitness function
    fitness_fn = fn agent ->
      # Calculate error across all cases
      errors = Enum.map(test_cases, fn {inputs, expected} ->
        outputs = activate_agent(agent, inputs)
        Enum.zip(outputs, expected)
        |> Enum.map(fn {o, e} -> :math.pow(o - e, 2) end)
        |> Enum.sum()
      end)
      
      # Return fitness (1 / (1 + error)) so higher is better
      1.0 / (1.0 + Enum.sum(errors))
    end
    
    # Default options
    defaults = %{
      population_size: 40,
      generations: 30,
      runs: 1
    }
    
    # Merge with provided options
    config = Map.merge(defaults, opts)
    
    # Create and run experiment
    {:ok, experiment_id} = quick_experiment("XOR Experiment", morphology, fitness_fn, config)
    
    # Check status periodically until complete
    wait_for_experiment(experiment_id)
  end
  
  # Helper function to wait for an experiment to complete
  defp wait_for_experiment(experiment_id, timeout_ms \\ 60000, check_interval_ms \\ 1000) do
    start_time = System.monotonic_time(:millisecond)

    wait_loop = fn wait_fn ->
      current_status = experiment_status(experiment_id)

      case current_status do
        {:completed, _info} ->
          # Experiment completed, get best solution
          get_best_solution(experiment_id)

        {:error, reason} ->
          {:error, reason}

        _status ->
          # Check timeout
          current_time = System.monotonic_time(:millisecond)
          if current_time - start_time > timeout_ms do
            {:error, :timeout}
          else
            # Wait and check again
            Process.sleep(check_interval_ms)
            wait_fn.(wait_fn)
          end
      end
    end

    wait_loop.(wait_loop)
  end
end