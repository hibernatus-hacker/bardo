# Distributed Training and Trading with Bardo

## Introduction

This guide explains how to set up and use Bardo's distributed capabilities for both training neural networks and deploying trading agents across multiple nodes. Leveraging Elixir's built-in distribution, Bardo provides a robust framework for parallelizing computation and ensuring fault tolerance.

## Table of Contents

1. [Setting Up Distributed Nodes](#setting-up-distributed-nodes)
2. [Distributed Training](#distributed-training)
3. [Distributed Trading](#distributed-trading)
4. [Fault Tolerance and Recovery](#fault-tolerance-and-recovery)
5. [Monitoring and Management](#monitoring-and-management)
6. [Example Configurations](#example-configurations)

## Setting Up Distributed Nodes

Before using Bardo's distributed capabilities, you need to set up your Elixir nodes to communicate with each other.

### 1. Starting Nodes

Start each Elixir node with a name:

```bash
# Primary node
iex --name primary@hostname -S mix

# Worker nodes
iex --name worker1@hostname -S mix
iex --name worker2@hostname -S mix
iex --name worker3@hostname -S mix
```

Replace `hostname` with the actual hostname or IP address of the machine.

### 2. Connecting Nodes

From the primary node, connect to all worker nodes:

```elixir
# Connect to worker nodes
Node.connect(:'worker1@hostname')
Node.connect(:'worker2@hostname')
Node.connect(:'worker3@hostname')

# Verify connections
Node.list()  # Should show all connected nodes
```

### 3. Cookie Security

Ensure all nodes share the same cookie for authentication:

```bash
# Set the same cookie for all nodes
elixir --name node@hostname --cookie mycookie -S mix
```

Or set the cookie in your `.erlang.cookie` file.

## Distributed Training

Bardo's distributed training uses an island-based approach where subpopulations evolve independently and occasionally share individuals.

### Key Concepts

1. **Islands**: Subpopulations that evolve independently
2. **Migration**: Periodic exchange of individuals between islands
3. **Node Assignment**: Distribution of islands across physical nodes
4. **Coordination**: Central coordination of the training process

### Starting Distributed Training

```elixir
alias Bardo.Examples.Applications.AlgoTrading.DistributedTraining

# Configure experiment
experiment_config = %{
  market: :forex,
  symbol: "EURUSD",
  timeframe: 15,
  population_size: 600,  # Will be divided among islands
  generations: 200
  # ... other configuration options
}

# Distribution options
distribution_options = [
  nodes: [Node.self() | Node.list()],  # Use all available nodes
  islands: 6,                           # Number of subpopulations
  migration_interval: 10,               # Migrate every 10 generations
  migration_rate: 0.1                   # Migrate 10% of population
]

# Start distributed training
{:ok, experiment_id} = DistributedTraining.start_distributed_training(
  :my_trading_experiment,
  experiment_config,
  distribution_options
)
```

### Monitoring Training Progress

```elixir
# Get current status
status = DistributedTraining.get_training_status(experiment_id)

# Display status information
IO.puts("Experiment: #{status.experiment_id}")
IO.puts("Status: #{status.status}")
IO.puts("Generation: #{status.generation}")
IO.puts("Elapsed time: #{status.elapsed_time} seconds")

# Check status of individual islands
Enum.each(status.islands_status, fn island ->
  IO.puts("Island #{island.island}: Node #{island.node}, Generation #{island.generation}")
end)
```

### Getting Results

```elixir
# Get the best agent from all islands
{:ok, best_agent} = DistributedTraining.get_best_agent(experiment_id)

# Display fitness metrics
IO.inspect(best_agent.fitness)

# Save the agent for later use
Bardo.Models.store(:best_agents, experiment_id, best_agent)
```

### Early Stopping

```elixir
# Stop training before completion if needed
DistributedTraining.stop_distributed_training(experiment_id)
```

## Distributed Trading

After training, you can deploy trading agents across multiple nodes for fault tolerance and diversification.

### Deploying a Single Agent

```elixir
alias Bardo.Examples.Applications.AlgoTrading.LiveAgent

# Get the best agent from training
{:ok, best_agent} = DistributedTraining.get_best_agent(experiment_id)

# Deploy on a specific node
node = :'trading_node@hostname'

# Define a remote function to start the agent
remote_fun = fn ->
  LiveAgent.start_link(
    :trading_agent,
    best_agent,
    broker_module,
    broker_config,
    options
  )
end

# Execute on remote node
:rpc.call(node, Kernel, :apply, [remote_fun, []])
```

### Deploying Multiple Agents (Fleet)

```elixir
# Configure multiple broker connections
broker_configs = [
  %{symbol: "EURUSD", timeframe: 15, account_id: "12345678"},
  %{symbol: "GBPUSD", timeframe: 15, account_id: "12345678"},
  %{symbol: "USDJPY", timeframe: 15, account_id: "12345678"}
]

# Nodes for deployment
nodes = [:'trading1@hostname', :'trading2@hostname', :'trading3@hostname']

# Start a fleet of agents
{:ok, agent_ids} = LiveAgent.start_agent_fleet(
  experiment_id,
  broker_module,
  broker_configs,
  [nodes: nodes, adaptation_enabled: true]
)
```

### Managing Agent Fleet

```elixir
# Get performance metrics from all agents
fleet_performance = LiveAgent.get_fleet_performance(agent_ids)

# Display metrics for each agent
Enum.each(fleet_performance, fn {agent_id, status} ->
  IO.puts("Agent: #{agent_id}")
  IO.puts("Position: #{status.position.direction}")
  IO.puts("P/L: $#{status.performance.total_profit - status.performance.total_loss}")
  IO.puts("Win rate: #{status.performance.win_rate * 100}%")
end)

# Update risk parameters for all agents
Enum.each(agent_ids, fn agent_id -> 
  LiveAgent.update_risk_params(agent_id, %{risk_per_trade: 0.005})
end)

# Stop all agents
Enum.each(agent_ids, fn agent_id ->
  LiveAgent.close_all_positions(agent_id)
  LiveAgent.stop_agent(agent_id)
end)
```

## Fault Tolerance and Recovery

Bardo's distributed system includes mechanisms for handling node failures gracefully.

### Island Migration on Node Failure

During distributed training, if a node fails:

1. The coordinator detects the failure
2. The affected islands are migrated to available nodes
3. Training continues with minimal interruption

```elixir
# Configure auto-recovery
distribution_options = [
  # ... other options
  auto_recovery: true
]
```

### Agent Failover

For live trading, implement agent failover:

```elixir
# Monitor node status regularly
def monitor_nodes(agent_ids) do
  # Check each node
  Enum.each(agent_ids, fn agent_id ->
    node = find_agent_node(agent_id)
    
    # If node is down, restart agent on another node
    unless Node.ping(node) == :pong do
      # Get state from persistent storage
      {:ok, agent_state} = get_agent_state(agent_id)
      
      # Find a healthy node
      new_node = Enum.find(Node.list(), fn n -> Node.ping(n) == :pong end)
      
      # Restart agent on new node
      restart_agent_on_node(new_node, agent_id, agent_state)
    end
  end)
  
  # Schedule next check
  Process.send_after(self(), :check_nodes, 60_000)
end
```

## Monitoring and Management

### Web Dashboard

Create a simple web dashboard using Phoenix to monitor distributed system:

```elixir
# In your Phoenix controller
def index(conn, _params) do
  # Get all running experiments
  experiments = list_running_experiments()
  
  # Get all deployed agents
  agents = list_deployed_agents()
  
  # Get node status
  nodes = [Node.self() | Node.list()]
  node_status = Enum.map(nodes, fn node -> {node, Node.ping(node)} end)
  
  render(conn, "dashboard.html", 
    experiments: experiments, 
    agents: agents,
    node_status: node_status
  )
end
```

### Remote Management Console

Use a dedicated management node:

```elixir
# On management node
defmodule BardoManager do
  def start_experiment(name, config, nodes) do
    # Start distributed training
    DistributedTraining.start_distributed_training(name, config, [nodes: nodes])
  end
  
  def deploy_agent(experiment_id, broker_config, node) do
    # Get best agent
    {:ok, agent} = DistributedTraining.get_best_agent(experiment_id)
    
    # Deploy to specified node
    # ... deployment code
  end
  
  def status_report do
    # Generate comprehensive status report
    # ... report generation code
  end
end
```

## Example Configurations

### Multi-Node Training Cluster

```elixir
# Configuration for a 4-node training cluster
nodes = [
  :'primary@192.168.1.100',
  :'worker1@192.168.1.101',
  :'worker2@192.168.1.102',
  :'worker3@192.168.1.103'
]

# Configure with 8 islands (2 per node)
distribution_options = [
  nodes: nodes,
  islands: 8,
  migration_interval: 10,
  migration_rate: 0.1,
  
  # Island specialization
  island_configs: [
    # Island 0: Exploration focused
    %{mutation_rate: 0.2, tournament_size: 3},
    
    # Island 1: Standard parameters
    %{mutation_rate: 0.1, tournament_size: 5},
    
    # Island 2: Exploitation focused
    %{mutation_rate: 0.05, tournament_size: 7},
    
    # Island 3: Substrate encoding
    %{use_substrate: true},
    
    # Islands 4-7: Variations
    %{mutation_rate: 0.15, tournament_size: 4},
    %{mutation_rate: 0.1, tournament_size: 5},
    %{mutation_rate: 0.05, tournament_size: 6, use_substrate: true},
    %{mutation_rate: 0.1, tournament_size: 5, use_substrate: true}
  ]
]
```

### Multi-Currency Trading Fleet

```elixir
# Configuration for trading multiple currency pairs
broker_configs = [
  # Major pairs
  %{symbol: "EURUSD", timeframe: 15, account_id: "12345678"},
  %{symbol: "GBPUSD", timeframe: 15, account_id: "12345678"},
  %{symbol: "USDJPY", timeframe: 15, account_id: "12345678"},
  %{symbol: "AUDUSD", timeframe: 15, account_id: "12345678"},
  
  # Minor pairs
  %{symbol: "EURGBP", timeframe: 15, account_id: "12345678"},
  %{symbol: "EURJPY", timeframe: 15, account_id: "12345678"},
  %{symbol: "GBPJPY", timeframe: 15, account_id: "12345678"},
  
  # Same pairs with different timeframes
  %{symbol: "EURUSD", timeframe: 5, account_id: "12345678"},
  %{symbol: "EURUSD", timeframe: 60, account_id: "12345678"}
]

# Distribute across 3 trading nodes
trading_nodes = [
  :'trading1@hostname',
  :'trading2@hostname',
  :'trading3@hostname'
]

# Deploy with various configurations
{:ok, agent_ids} = LiveAgent.start_agent_fleet(
  experiment_id,
  broker_module,
  broker_configs,
  [
    nodes: trading_nodes,
    adaptation_enabled: true,
    risk_params: %{
      risk_per_trade: 0.01,
      max_drawdown: 0.10
    }
  ]
)
```

## Advanced: Continuous Training Pipeline

For advanced users, you can create a continuous training and deployment pipeline:

```elixir
# Schedule regular retraining
defmodule ContinuousTraining do
  use GenServer
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: :continuous_trainer)
  end
  
  def init(opts) do
    # Schedule first training
    schedule_training()
    {:ok, opts}
  end
  
  def handle_info(:train, state) do
    # Start new training
    experiment_id = :"retraining_#{DateTime.utc_now() |> DateTime.to_unix()}"
    
    # Start distributed training
    {:ok, _} = DistributedTraining.start_distributed_training(
      experiment_id,
      state.config,
      state.distribution_options
    )
    
    # Store experiment ID for later
    new_state = Map.put(state, :current_experiment, experiment_id)
    
    # Schedule completion check
    Process.send_after(self(), :check_completion, 60_000)
    
    {:noreply, new_state}
  end
  
  def handle_info(:check_completion, state) do
    # Check if current experiment is complete
    status = DistributedTraining.get_training_status(state.current_experiment)
    
    if status.status == :complete do
      # Deploy new agents
      deploy_new_agents(state.current_experiment)
      
      # Schedule next training
      schedule_training()
    else
      # Check again later
      Process.send_after(self(), :check_completion, 60_000)
    end
    
    {:noreply, state}
  end
  
  defp schedule_training do
    # Schedule next training in 1 week
    Process.send_after(self(), :train, 7 * 24 * 60 * 60 * 1000)
  end
  
  defp deploy_new_agents(experiment_id) do
    # Get existing agents
    existing_agents = list_deployed_agents()
    
    # Get new agent
    {:ok, new_agent} = DistributedTraining.get_best_agent(experiment_id)
    
    # Compare performance
    if better_performance?(new_agent, existing_agents) do
      # Replace existing agents with new one
      replace_agents(existing_agents, new_agent)
    end
  end
end
```

## Conclusion

Bardo's distributed capabilities provide a powerful framework for both training and deploying algorithmic trading systems at scale. By leveraging Elixir's built-in distribution and fault tolerance, you can create robust trading systems that evolve and adapt in real-world environments.

For detailed configuration examples, see the [example configurations](example_configs/distributed_training.exs) directory.