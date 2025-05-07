# Live Trading Agent Configuration
# Use this with: Bardo.Examples.Applications.AlgoTrading.LiveAgent functions

alias Bardo.Examples.Applications.AlgoTrading.LiveAgent
alias Bardo.Examples.Applications.AlgoTrading.Brokers.MetaTrader
alias Bardo.Examples.Applications.AlgoTrading.DistributedTraining

# Step 1: Get the best agent from a completed experiment
experiment_id = :my_forex_experiment

# Step 2: Configure the broker connection
broker_module = MetaTrader  # MetaTrader broker module

broker_config = %{
  # Connection details
  api_url: "http://localhost:5000",  # MT REST API URL
  api_key: "YOUR_API_KEY",           # API key if required
  account_id: "12345678",            # MT account number
  
  # Trading parameters
  symbol: "EURUSD",                  # Trading symbol
  timeframe: 15,                     # Timeframe in minutes
  
  # Additional broker options
  execution_mode: :market,           # Market or limit orders
  demo_mode: true                    # Use demo account
}

# Step 3: Configure risk management
risk_params = %{
  risk_per_trade: 0.01,              # Risk 1% per trade
  max_drawdown: 0.10,                # Maximum 10% drawdown
  stop_loss: 0.02,                   # 2% stop loss
  take_profit: 0.04,                 # 4% take profit
  max_positions: 1,                  # Maximum 1 simultaneous position
  position_sizing: :fixed_risk,      # Position sizing method
  trailing_stop: true,               # Use trailing stops
  trailing_stop_distance: 0.01       # 1% trailing stop distance
}

# Step 4: Configure agent options
agent_options = [
  risk_params: risk_params,
  substrate_encoding: true,          # Use substrate encoding
  adaptation_enabled: false          # Start without continuous learning
]

# Step 5: Start the live trading agent
# To execute, remove the # from the lines below and fill in your actual agent ID
# Agent ID should be unique to avoid conflicts
#agent_id = :my_live_forex_agent

# Get the best agent from the completed experiment
#{:ok, best_agent} = DistributedTraining.get_best_agent(experiment_id)

# Start the live trading agent
#{:ok, _pid} = LiveAgent.start_link(agent_id, best_agent, broker_module, broker_config, agent_options)

# Step 6: Monitor the agent's performance
# LiveAgent.get_status(agent_id)

# Step 7: Enable continuous learning after some time
# LiveAgent.enable_continuous_learning(agent_id, 0.01, 10)

# Step 8: Update risk parameters if needed
#LiveAgent.update_risk_params(agent_id, %{
#  risk_per_trade: 0.005,            # Reduce risk to 0.5%
#  max_drawdown: 0.05                # Reduce max drawdown to 5%
#})

# Step 9: Stop the agent when done
# LiveAgent.close_all_positions(agent_id)
# Process.exit(Process.whereis(agent_id), :normal)

# Alternative: Deploy a fleet of agents
#broker_configs = [
#  %{symbol: "EURUSD", timeframe: 15, account_id: "12345678", api_url: "http://localhost:5000"},
#  %{symbol: "GBPUSD", timeframe: 15, account_id: "12345678", api_url: "http://localhost:5000"},
#  %{symbol: "USDJPY", timeframe: 15, account_id: "12345678", api_url: "http://localhost:5000"}
#]

#fleet_options = [
#  nodes: [Node.self(), :'node1@hostname', :'node2@hostname'],
#  adaptation_enabled: true
#]

#{:ok, agent_ids} = LiveAgent.start_agent_fleet(experiment_id, broker_module, broker_configs, fleet_options)

# Monitor the fleet
#LiveAgent.get_fleet_performance(agent_ids)