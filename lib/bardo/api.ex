defmodule Bardo.API do
  @moduledoc """
  A simplified API layer for Bardo, providing beginner-friendly functions 
  for common tasks while abstracting away implementation complexity.
  
  This module serves as the main entry point for new users to interact with Bardo
  without needing to understand the underlying architecture.
  """

  alias Bardo.AgentManager
  alias Bardo.AgentManager.Substrate
  alias Bardo.AppConfig
  alias Bardo.ExperimentManager
  alias Bardo.Morphology
  alias Bardo.ScapeManager
  alias Bardo.Utils

  @doc """
  Initialize a new Bardo environment with sensible defaults.
  
  ## Examples
      
      iex> Bardo.API.init()
      :ok
  """
  def init do
    Bardo.start()
    :ok
  end

  @doc """
  Create and setup a simple XOR neural network.
  
  ## Options
    
    * `:id` - the ID for the agent (default: random UUID)
    * `:hidden_neurons` - number of hidden neurons (default: 2)
    * `:bias` - whether to use bias neurons (default: true)
    * `:activation` - activation function to use (default: :tanh)
  
  ## Examples
      
      iex> Bardo.API.create_xor()
      {:ok, agent_id}
  """
  def create_xor(opts \\ []) do
    id = Keyword.get(opts, :id, Utils.create_id())
    hidden_neurons = Keyword.get(opts, :hidden_neurons, 2)
    bias = Keyword.get(opts, :bias, true)
    activation = Keyword.get(opts, :activation, :tanh)
    
    # Create a simple XOR morphology
    morphology = Morphology.create(
      %{type: :sensor, name: :input, vl: 2},
      %{type: :actuator, name: :output, vl: 1},
      [hidden_neurons: hidden_neurons, activation: activation, bias: bias]
    )
    
    # Create and register agent
    {:ok, _pid} = AgentManager.create_agent(id, morphology)
    {:ok, id}
  end
  
  @doc """
  Train an agent on the XOR problem.
  
  ## Options
    
    * `:generations` - number of generations to train (default: 100)
    * `:population_size` - size of the population (default: 20)
    * `:fitness_target` - target fitness to reach (default: 3.9)
  
  ## Examples
      
      iex> {:ok, agent_id} = Bardo.API.create_xor()
      iex> Bardo.API.train_xor(agent_id)
      {:ok, %{best_fitness: 3.95, generations: 42}}
  """
  def train_xor(agent_id, opts \\ []) do
    generations = Keyword.get(opts, :generations, 100)
    population_size = Keyword.get(opts, :population_size, 20)
    fitness_target = Keyword.get(opts, :fitness_target, 3.9)
    
    # XOR inputs and expected outputs
    inputs = [[0, 0], [0, 1], [1, 0], [1, 1]]
    expected = [[0], [1], [1], [0]]
    
    # Create a private scape for training
    {:ok, _scape_pid} = ScapeManager.create_scape(:private, agent_id)
    
    # Setup training experiment
    experiment_id = "xor_training_#{Utils.create_id()}"
    experiment_config = %{
      type: :incremental,
      iterations: generations,
      population_size: population_size,
      fitness_target: fitness_target
    }
    
    # Define the fitness function for XOR
    fitness_function = fn agent ->
      results = Enum.map(inputs, fn input ->
        AgentManager.sense_think_act(agent, %{input: input})
      end)
      
      outputs = Enum.map(results, fn {:ok, output} -> output.output end)
      
      # Calculate fitness (4 - error)
      fitness = 4 - Enum.sum(Enum.map(Enum.zip(outputs, expected), fn {output, expected} ->
        Enum.sum(Enum.map(Enum.zip(output, expected), fn {o, e} ->
          abs(o - e)
        end))
      end))
      
      fitness
    end
    
    # Create and run the experiment
    {:ok, _pid} = ExperimentManager.create_experiment(
      experiment_id, 
      agent_id, 
      experiment_config
    )
    
    {:ok, _experiment} = ExperimentManager.run_experiment(
      experiment_id,
      fitness_function
    )
    
    # Get the best agent
    {:ok, champion} = ExperimentManager.get_champion(experiment_id)
    
    {:ok, %{
      best_fitness: champion.fitness,
      generations: champion.generation
    }}
  end
  
  @doc """
  Test the agent on the XOR problem.
  
  ## Examples
      
      iex> {:ok, agent_id} = Bardo.API.create_xor()
      iex> Bardo.API.train_xor(agent_id)
      iex> Bardo.API.test_xor(agent_id)
      {:ok, %{
        inputs: [[0, 0], [0, 1], [1, 0], [1, 1]],
        outputs: [[0.02], [0.98], [0.97], [0.03]],
        expected: [[0], [1], [1], [0]]
      }}
  """
  def test_xor(agent_id) do
    inputs = [[0, 0], [0, 1], [1, 0], [1, 1]]
    expected = [[0], [1], [1], [0]]
    
    results = Enum.map(inputs, fn input ->
      {:ok, result} = AgentManager.sense_think_act(agent_id, %{input: input})
      result.output
    end)
    
    {:ok, %{
      inputs: inputs,
      outputs: results,
      expected: expected
    }}
  end
  
  @doc """
  Create a flatland environment for agent navigation.
  
  ## Options
    
    * `:id` - the ID for the agent (default: random UUID)
    * `:hidden_neurons` - number of hidden neurons (default: 5)
    * `:world_size` - size of the flatland world (default: {10, 10})
  
  ## Examples
      
      iex> Bardo.API.create_flatland()
      {:ok, agent_id}
  """
  def create_flatland(opts \\ []) do
    id = Keyword.get(opts, :id, Utils.create_id())
    hidden_neurons = Keyword.get(opts, :hidden_neurons, 5)
    {width, height} = Keyword.get(opts, :world_size, {10, 10})
    
    # Import flatland modules
    alias Bardo.Examples.Applications.Flatland
    alias Bardo.Examples.Applications.Flatland.FlatlandSensor
    alias Bardo.Examples.Applications.Flatland.FlatlandActuator
    
    # Initialize flatland environment
    Flatland.init(width, height)
    
    # Create flatland morphology
    sensor_config = %{type: :sensor, name: :flatland_sensor, vl: 9, module: FlatlandSensor}
    actuator_config = %{type: :actuator, name: :flatland_actuator, vl: 2, module: FlatlandActuator}
    
    morphology = Morphology.create(
      sensor_config,
      actuator_config,
      [hidden_neurons: hidden_neurons, activation: :tanh, bias: true]
    )
    
    # Create and register agent
    {:ok, _pid} = AgentManager.create_agent(id, morphology)
    {:ok, id}
  end
  
  @doc """
  Train a flatland agent to navigate and avoid obstacles.
  
  ## Options
    
    * `:generations` - number of generations to train (default: 500)
    * `:population_size` - size of the population (default: 50)
    * `:fitness_target` - target fitness to reach (default: 800)
    * `:simulation_steps` - steps per evaluation (default: 100)
  
  ## Examples
      
      iex> {:ok, agent_id} = Bardo.API.create_flatland()
      iex> Bardo.API.train_flatland(agent_id)
      {:ok, %{best_fitness: 825, generations: 320}}
  """
  def train_flatland(agent_id, opts \\ []) do
    generations = Keyword.get(opts, :generations, 500)
    population_size = Keyword.get(opts, :population_size, 50)
    fitness_target = Keyword.get(opts, :fitness_target, 800)
    simulation_steps = Keyword.get(opts, :simulation_steps, 100)
    
    alias Bardo.Examples.Applications.Flatland
    
    # Create a private scape for training
    {:ok, _scape_pid} = ScapeManager.create_scape(:private, agent_id)
    
    # Setup training experiment
    experiment_id = "flatland_training_#{Utils.create_id()}"
    experiment_config = %{
      type: :incremental,
      iterations: generations,
      population_size: population_size,
      fitness_target: fitness_target
    }
    
    # Define the fitness function for flatland navigation
    fitness_function = fn agent ->
      # Reset agent position
      Flatland.reset_agent()
      
      # Run simulation for specified steps
      Enum.reduce(1..simulation_steps, 0, fn _, fitness ->
        # Get current sensor data 
        sensor_data = Flatland.get_sensor_data()
        
        # Agent processes sensor data and produces action
        {:ok, result} = AgentManager.sense_think_act(agent, %{flatland_sensor: sensor_data})
        
        # Apply action and get reward
        reward = Flatland.process_action(result.flatland_actuator)
        
        # Accumulate fitness
        fitness + reward
      end)
    end
    
    # Create and run the experiment
    {:ok, _pid} = ExperimentManager.create_experiment(
      experiment_id, 
      agent_id, 
      experiment_config
    )
    
    {:ok, _experiment} = ExperimentManager.run_experiment(
      experiment_id,
      fitness_function
    )
    
    # Get the best agent
    {:ok, champion} = ExperimentManager.get_champion(experiment_id)
    
    {:ok, %{
      best_fitness: champion.fitness,
      generations: champion.generation
    }}
  end
  
  @doc """
  Create and configure an agent for algorithmic trading.
  
  ## Options
    
    * `:id` - the ID for the agent (default: random UUID)
    * `:instrument` - trading instrument (default: "EUR_USD")
    * `:timeframe` - trading timeframe (default: "M15")
    * `:hidden_neurons` - number of hidden neurons (default: 10)
  
  ## Examples
      
      iex> Bardo.API.create_trading_agent(instrument: "BTC_USD")
      {:ok, agent_id}
  """
  def create_trading_agent(opts \\ []) do
    id = Keyword.get(opts, :id, Utils.create_id())
    instrument = Keyword.get(opts, :instrument, "EUR_USD")
    timeframe = Keyword.get(opts, :timeframe, "M15")
    hidden_neurons = Keyword.get(opts, :hidden_neurons, 10)
    
    alias Bardo.Examples.Applications.AlgoTrading
    alias Bardo.Examples.Applications.AlgoTrading.TradingSensor
    alias Bardo.Examples.Applications.AlgoTrading.TradingActuator
    
    # Initialize trading environment
    AlgoTrading.init(instrument, timeframe)
    
    # Input features: OHLCV, indicators, etc.
    feature_count = 20
    
    # Create trading morphology
    sensor_config = %{type: :sensor, name: :trading_sensor, vl: feature_count, module: TradingSensor}
    actuator_config = %{type: :actuator, name: :trading_actuator, vl: 3, module: TradingActuator}
    
    morphology = Morphology.create(
      sensor_config,
      actuator_config,
      [hidden_neurons: hidden_neurons, activation: :tanh, bias: true]
    )
    
    # Create and register agent
    {:ok, _pid} = AgentManager.create_agent(id, morphology)
    {:ok, id}
  end
  
  @doc """
  Load a pre-trained trading agent from a file.
  
  ## Examples
      
      iex> Bardo.API.load_trading_agent("/path/to/agent.json")
      {:ok, agent_id}
  """
  def load_trading_agent(file_path) do
    alias Bardo.Examples.Applications.AlgoTrading.AgentLoader
    
    # Load agent from file
    AgentLoader.load(file_path)
  end
  
  @doc """
  Save a trained agent to a file.
  
  ## Examples
      
      iex> Bardo.API.save_agent(agent_id, "/path/to/save/agent.json")
      :ok
  """
  def save_agent(agent_id, file_path) do
    alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
    
    # Save agent to file
    AgentSerializer.save(agent_id, file_path)
  end
  
  @doc """
  Deploy an agent for live trading.
  
  ## Options
    
    * `:broker` - the broker to use (default: :oanda)
    * `:config` - broker-specific configuration
  
  ## Examples
      
      iex> config = %{api_key: "your_api_key", account_id: "your_account_id"}
      iex> Bardo.API.deploy_trading_agent(agent_id, broker: :oanda, config: config)
      {:ok, deployment_id}
  """
  def deploy_trading_agent(agent_id, opts \\ []) do
    broker = Keyword.get(opts, :broker, :oanda)
    config = Keyword.get(opts, :config, %{})
    
    alias Bardo.Examples.Applications.AlgoTrading.DeployedAgentManager
    
    # Deploy agent for live trading
    DeployedAgentManager.deploy(agent_id, broker, config)
  end
  
  @doc """
  Stop a deployed trading agent.
  
  ## Examples
      
      iex> Bardo.API.stop_trading_agent(deployment_id)
      :ok
  """
  def stop_trading_agent(deployment_id) do
    alias Bardo.Examples.Applications.AlgoTrading.DeployedAgentManager
    
    # Stop deployed agent
    DeployedAgentManager.stop(deployment_id)
  end
  
  @doc """
  Get performance metrics for an agent.
  
  ## Examples
      
      iex> Bardo.API.get_agent_metrics(agent_id)
      {:ok, %{
        sharpe_ratio: 1.2,
        max_drawdown: 0.15,
        total_return: 0.25,
        win_rate: 0.55
      }}
  """
  def get_agent_metrics(agent_id) do
    alias Bardo.Examples.Applications.AlgoTrading.VerificationTools
    
    # Get agent performance metrics
    VerificationTools.calculate_metrics(agent_id)
  end
  
  # Distributed training will be supported in a future release
  
  @doc """
  Run a standalone training session for a trading agent.
  
  ## Options
    
    * `:instrument` - trading instrument (default: "EUR_USD")
    * `:timeframe` - trading timeframe (default: "M15")
    * `:start_date` - historical data start date (default: one year ago)
    * `:end_date` - historical data end date (default: current date)
    * `:generations` - number of generations to train (default: 100)
    * `:population_size` - size of the population (default: 50)
  
  ## Examples
      
      iex> Bardo.API.run_standalone_training(instrument: "BTC_USD")
      {:ok, %{agent_id: agent_id, fitness: 0.85}}
  """
  def run_standalone_training(opts \\ []) do
    instrument = Keyword.get(opts, :instrument, "EUR_USD")
    timeframe = Keyword.get(opts, :timeframe, "M15")
    
    one_year_ago = Date.utc_today() |> Date.add(-365)
    start_date = Keyword.get(opts, :start_date, one_year_ago)
    end_date = Keyword.get(opts, :end_date, Date.utc_today())
    
    generations = Keyword.get(opts, :generations, 100)
    population_size = Keyword.get(opts, :population_size, 50)
    
    alias Bardo.Examples.Applications.AlgoTrading.StandaloneTrainer
    
    # Run standalone training
    StandaloneTrainer.train(
      instrument,
      timeframe,
      start_date,
      end_date,
      generations,
      population_size
    )
  end
end