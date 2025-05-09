defmodule Bardo.Examples.Applications.AlgoTrading.AgentLoader do
  @moduledoc """
  Module for loading and deploying trained agents for trading.
  
  This module provides functions for:
  - Loading agents from JSON files
  - Creating deployable agent instances
  - Managing agent pools for trading
  """
  
  require Logger
  alias Bardo.PolisMgr
  alias Bardo.Examples.Applications.AlgoTrading.AgentSerializer
  alias Bardo.Examples.Applications.AlgoTrading.Morphology
  
  @doc """
  Load an agent from a file and deploy it for trading.
  
  ## Parameters
  
  - file_path: Path to the serialized agent file
  - broker_module: Module implementing the BrokerInterface
  - broker_state: Broker state map from initialization
  - opts: Additional options
    - `:agent_id` - ID for the deployed agent (default: generated from filename)
    - `:instrument` - Instrument to trade (e.g., "EURUSD", "BTCUSD")
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:max_drawdown` - Maximum drawdown percentage before stopping (default: 10.0)
    - `:continuous_learning` - Whether to enable continuous learning (default: false)
  
  ## Returns
  
  - `{:ok, agent_id}` - ID of the deployed agent
  - `{:error, reason}` - If deployment fails
  """
  def deploy_agent_from_file(file_path, broker_module, broker_state, opts \\ %{}) do
    # Load agent from file
    case AgentSerializer.load_agent(file_path) do
      {:ok, {genotype, metadata}} ->
        # Extract options
        agent_id = Map.get(opts, :agent_id, generate_agent_id(file_path))
        instrument = Map.get(opts, :instrument, Map.get(metadata, "instrument", "EURUSD"))
        risk_per_trade = Map.get(opts, :risk_per_trade, 1.0)
        max_drawdown = Map.get(opts, :max_drawdown, 10.0)
        continuous_learning = Map.get(opts, :continuous_learning, false)
        
        # Create agent deployment config
        deploy_config = %{
          id: agent_id,
          
          # Scape configuration using broker interface
          scapes: [
            %{
              module: broker_module,
              name: :live_trading_scape,
              type: :private,
              module_parameters: %{
                broker_state: broker_state,
                instrument: instrument,
                risk_per_trade: risk_per_trade,
                max_drawdown: max_drawdown,
                continuous_learning: continuous_learning
              }
            }
          ],
          
          # Agent configuration
          agents: [
            %{
              id: agent_id,
              genotype: genotype,
              morphology: Morphology,
              scape_name: :live_trading_scape
            }
          ]
        }
        
        # Deploy the agent
        case PolisMgr.setup(deploy_config) do
          {:ok, _} ->
            Logger.info("Agent #{agent_id} deployed successfully for trading #{instrument}")
            {:ok, agent_id}
            
          {:error, reason} ->
            {:error, "Failed to deploy agent: #{inspect(reason)}"}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  @doc """
  Stop a deployed trading agent.
  
  ## Parameters
  
  - agent_id: ID of the deployed agent
  
  ## Returns
  
  - `:ok` - If the agent was successfully stopped
  - `{:error, reason}` - If stopping fails
  """
  def stop_agent(agent_id) do
    case PolisMgr.send_command(agent_id, :stop) do
      :ok ->
        Logger.info("Agent #{agent_id} stopped successfully")
        :ok
        
      {:error, reason} ->
        {:error, "Failed to stop agent: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Get status of a deployed trading agent.
  
  ## Parameters
  
  - agent_id: ID of the deployed agent
  
  ## Returns
  
  - `{:ok, status}` - Status information for the agent
  - `{:error, reason}` - If getting status fails
  """
  def get_agent_status(agent_id) do
    case PolisMgr.get_status(agent_id) do
      {:ok, status} ->
        {:ok, status}
        
      {:error, reason} ->
        {:error, "Failed to get agent status: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Create an agent pool for trading multiple instruments.
  
  ## Parameters
  
  - agents_config: List of agent configurations with the following keys:
    - `:file_path` - Path to the serialized agent file
    - `:broker_module` - Module implementing the BrokerInterface
    - `:broker_state` - Broker state map from initialization
    - `:instrument` - Instrument to trade
    - `:risk_per_trade` - Risk percentage per trade (default: 1.0)
    - `:max_drawdown` - Maximum drawdown percentage (default: 10.0)
  - pool_id: ID for the agent pool (default: generated UUID)
  
  ## Returns
  
  - `{:ok, pool_id}` - ID of the created agent pool
  - `{:error, reason}` - If creation fails
  """
  def create_agent_pool(agents_config, pool_id \\ nil) do
    # Generate pool ID if not provided
    pool_id = pool_id || "pool_#{UUID.uuid4(:hex)}"
    
    # Deploy each agent in the pool
    results = Enum.map(agents_config, fn config ->
      agent_id = "#{pool_id}_#{config.instrument}"
      
      deploy_agent_from_file(
        config.file_path,
        config.broker_module,
        config.broker_state,
        %{
          agent_id: agent_id,
          instrument: config.instrument,
          risk_per_trade: Map.get(config, :risk_per_trade, 1.0),
          max_drawdown: Map.get(config, :max_drawdown, 10.0),
          continuous_learning: Map.get(config, :continuous_learning, false)
        }
      )
    end)
    
    # Check if all deployments were successful
    if Enum.all?(results, fn {status, _} -> status == :ok end) do
      # Extract agent IDs
      agent_ids = Enum.map(results, fn {:ok, agent_id} -> agent_id end)
      
      # Store pool information (could be persisted to database)
      pool_info = %{
        id: pool_id,
        agents: agent_ids,
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }
      
      Logger.info("Agent pool #{pool_id} created with #{length(agent_ids)} agents")
      {:ok, pool_id}
    else
      # Find first error
      {_, error} = Enum.find(results, fn {status, _} -> status == :error end)
      
      # Stop any successfully deployed agents
      Enum.each(results, fn
        {:ok, agent_id} -> stop_agent(agent_id)
        _ -> nil
      end)
      
      {:error, "Failed to create agent pool: #{error}"}
    end
  end
  
  @doc """
  Stop all agents in a pool.
  
  ## Parameters
  
  - pool_id: ID of the agent pool
  - agent_ids: List of agent IDs in the pool
  
  ## Returns
  
  - `:ok` - If all agents were successfully stopped
  - `{:error, reason}` - If stopping any agent fails
  """
  def stop_agent_pool(pool_id, agent_ids) do
    # Stop each agent in the pool
    results = Enum.map(agent_ids, &stop_agent/1)
    
    # Check if all stops were successful
    if Enum.all?(results, fn result -> result == :ok end) do
      Logger.info("Agent pool #{pool_id} stopped successfully")
      :ok
    else
      # Find first error
      error = Enum.find(results, fn result -> result != :ok end)
      {:error, "Failed to stop agent pool: #{inspect(error)}"}
    end
  end
  
  # Private helper functions
  
  # Generate an agent ID from a file path
  defp generate_agent_id(file_path) do
    basename = Path.basename(file_path, ".json")
    "agent_#{basename}_#{System.system_time(:second)}"
  end
end