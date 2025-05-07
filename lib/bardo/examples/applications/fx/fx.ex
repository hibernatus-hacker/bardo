defmodule Bardo.Examples.Applications.Fx.Fx do
  @moduledoc """
  Forex (FX) trading simulation environment.
  
  This module implements a forex trading simulator that allows
  agents to trade currency pairs based on historical price data.
  It behaves as a private scape in the Bardo system.
  """
  
  alias Bardo.ScapeManager.Sector
  alias Bardo.AgentManager.PrivateScape
  
  @behaviour PrivateScape
  
  # Define constants
  @default_balance 10000.0
  @default_leverage 100.0
  @max_drawdown_percent 20.0
  @data_path "priv/fx_tables/EURUSD15.txt"
  
  # Define structs for FX simulation
  
  # FX state struct
  defstruct [
    :data,            # List of price data points
    :data_length,     # Length of the data
    :index,           # Current position in the data
    :accounts,        # Map of agent accounts
    :scape_pid,       # PID of the scape
    :window_start,    # Start of the current data window
    :window_end       # End of the current data window
  ]
  
  # Account struct
  defstruct [
    :agent_id,        # ID of the agent
    :balance,         # Account balance
    :equity,          # Current equity (balance + open profit/loss)
    :leverage,        # Account leverage
    :position,        # Current position (-1=short, 0=none, 1=long)
    :order,           # Current order details (if position != 0)
    :max_equity,      # Maximum equity achieved
    :min_equity,      # Minimum equity achieved
    :completed_trades # List of completed trades
  ]
  
  # Order struct
  defstruct [
    :open_price,      # Price when the order was opened
    :open_time,       # Time when the order was opened
    :size,            # Size of the order
    :direction,       # Direction of the order (-1=short, 1=long)
    :open_pl          # Current profit/loss
  ]
  
  # Technical data struct for price information
  defstruct [
    :time,            # Timestamp
    :open,            # Opening price
    :high,            # Highest price
    :low,             # Lowest price
    :close,           # Closing price
    :volume           # Trading volume
  ]
  
  @doc """
  Initialize the private scape for FX trading.
  
  Parameters:
  - scape_pid: PID of the scape
  - window_size: Size of the data window for simulation
  """
  @impl PrivateScape
  def init(scape_pid, window_size) do
    # Load price data from file
    {:ok, data} = load_fx_data()
    data_length = length(data)
    
    # Initialize state
    state = %__MODULE__{
      data: data,
      data_length: data_length,
      index: 0,
      accounts: %{},
      scape_pid: scape_pid,
      window_start: 0,
      window_end: min(window_size, data_length - 1)
    }
    
    {:ok, state}
  end
  
  @doc """
  Handle a new agent entering the private scape.
  
  Creates a new trading account for the agent.
  """
  @impl PrivateScape
  def enter(agent_id, _params, state) do
    # Create a new account for the agent
    account = %{
      agent_id: agent_id,
      balance: @default_balance,
      equity: @default_balance,
      leverage: @default_leverage,
      position: 0,
      order: nil,
      max_equity: @default_balance,
      min_equity: @default_balance,
      completed_trades: []
    }
    
    # Add the account to the state
    new_accounts = Map.put(state.accounts, agent_id, account)
    new_state = %{state | accounts: new_accounts}
    
    {:ok, new_state}
  end
  
  @doc """
  Handle an agent leaving the private scape.
  
  Closes any open positions and removes the agent's account.
  """
  @impl PrivateScape
  def leave(agent_id, _params, state) do
    # Check if the agent has an account
    case Map.get(state.accounts, agent_id) do
      nil ->
        # Agent doesn't have an account
        {:ok, state}
        
      account ->
        # Close any open positions
        current_price = get_current_price(state)
        closed_account = close_position(account, current_price)
        
        # Remove the account from the state
        new_accounts = Map.delete(state.accounts, agent_id)
        new_state = %{state | accounts: new_accounts}
        
        {:ok, new_state}
    end
  end
  
  @doc """
  Handle a sensor request from an agent.
  
  Returns the requested price data based on the sensor type.
  """
  @impl PrivateScape
  def sense(agent_id, params, state) do
    %{sensor_type: sensor_type, params: sensor_params} = params
    
    case sensor_type do
      :pci ->
        # Price Chart Image sensor
        # Return a window of price data for creating a 2D grid
        prices = get_price_data_window(state, sensor_params.timeframe)
        {:ok, prices, state}
        
      :pli ->
        # Price List Information sensor
        # Return a list of recent prices
        prices = get_price_list(state, sensor_params.lookback)
        {:ok, prices, state}
        
      :internals ->
        # Internals sensor
        # Return account information
        account = Map.get(state.accounts, agent_id)
        internals = get_account_internals(account, state)
        {:ok, internals, state}
        
      _ ->
        # Unknown sensor type
        {:error, "Unknown sensor type", state}
    end
  end
  
  @doc """
  Handle an actuator request from an agent.
  
  Executes trading actions based on the agent's decision.
  """
  @impl PrivateScape
  def actuate(agent_id, params, state) do
    %{actuator_type: actuator_type, value: value} = params
    
    case actuator_type do
      :trade ->
        # Get the agent's account
        account = Map.get(state.accounts, agent_id)
        
        # Execute the trade
        {updated_account, response} = execute_trade(account, value, state)
        
        # Update the account in the state
        new_accounts = Map.put(state.accounts, agent_id, updated_account)
        new_state = %{state | accounts: new_accounts}
        
        # Check if we've reached the end of the data
        if state.index >= state.window_end do
          # Calculate final fitness
          fitness = calculate_fitness(updated_account)
          
          # Return completion response
          {:ok, %{status: :complete, fitness: fitness}, new_state}
        else
          # Return standard response
          {:ok, response, new_state}
        end
        
      _ ->
        # Unknown actuator type
        {:error, "Unknown actuator type", state}
    end
  end
  
  @doc """
  Advance the simulation by one step.
  
  Updates all accounts and moves to the next price point.
  """
  @impl PrivateScape
  def step(_params, state) do
    # Don't advance if we're at the end of the data window
    if state.index >= state.window_end do
      {:ok, state}
    else
      # Advance to the next price point
      new_index = state.index + 1
      
      # Update all accounts with the new price
      current_price = get_price_at(state, new_index)
      new_accounts = update_all_accounts(state.accounts, current_price)
      
      # Update the state
      new_state = %{state | index: new_index, accounts: new_accounts}
      
      {:ok, new_state}
    end
  end
  
  # Private functions
  
  # Load forex data from file
  defp load_fx_data do
    file_path = Path.join(:code.priv_dir(:bardo), @data_path)
    
    case File.read(file_path) do
      {:ok, content} ->
        # Parse the CSV data
        data = content
               |> String.split("\n", trim: true)
               |> Enum.map(&parse_fx_line/1)
        
        {:ok, data}
        
      {:error, reason} ->
        {:error, "Failed to load FX data: #{reason}"}
    end
  end
  
  # Parse a line of forex data
  defp parse_fx_line(line) do
    [date, time, open, high, low, close, volume] = String.split(line, ",", trim: true)
    
    %{
      time: "#{date} #{time}",
      open: String.to_float(open),
      high: String.to_float(high),
      low: String.to_float(low),
      close: String.to_float(close),
      volume: String.to_integer(volume)
    }
  end
  
  # Get the current price data
  defp get_current_price(state) do
    get_price_at(state, state.index).close
  end
  
  # Get price data at a specific index
  defp get_price_at(state, index) do
    Enum.at(state.data, index)
  end
  
  # Get a window of price data
  defp get_price_data_window(state, timeframe) do
    # Ensure we don't go below index 0
    start_idx = max(state.index - timeframe + 1, 0)
    
    # Extract the price data for the requested window
    Enum.slice(state.data, start_idx, timeframe)
    |> Enum.map(fn point -> point.close end)
  end
  
  # Get a list of recent prices
  defp get_price_list(state, lookback) do
    # Ensure we don't go below index 0
    start_idx = max(state.index - lookback + 1, 0)
    
    # Extract the closing prices for the requested period
    Enum.slice(state.data, start_idx, lookback)
    |> Enum.map(fn point -> point.close end)
  end
  
  # Get internals data from an account
  defp get_account_internals(account, state) do
    # Calculate open profit/loss if there's an open position
    open_pl = if account.position != 0 and account.order != nil do
      current_price = get_current_price(state)
      calculate_profit_loss(account.order, current_price)
    else
      0.0
    end
    
    # Return account information
    %{
      balance: account.balance,
      equity: account.balance + open_pl,
      position: account.position,
      open_pl: open_pl,
      leverage: account.leverage
    }
  end
  
  # Execute a trading decision
  defp execute_trade(account, decision, state) do
    current_price = get_current_price(state)
    current_time = get_price_at(state, state.index).time
    
    # Check if the decision changes the current position
    if decision != account.position do
      # Close any existing position
      closed_account = close_position(account, current_price)
      
      # Open a new position if the decision is not zero
      if decision != 0 do
        {updated_account, trade_result} = open_position(closed_account, decision, current_price, current_time)
        {updated_account, trade_result}
      else
        # No new position
        {closed_account, %{status: :position_closed}}
      end
    else
      # Update the account with current price for mark-to-market
      updated_account = update_account(account, current_price)
      {updated_account, %{status: :no_change}}
    end
  end
  
  # Close an existing position
  defp close_position(account, current_price) do
    if account.position != 0 and account.order != nil do
      # Calculate profit/loss
      profit_loss = calculate_profit_loss(account.order, current_price)
      
      # Update account balance
      new_balance = account.balance + profit_loss
      
      # Add to completed trades
      completed_trade = %{
        direction: account.order.direction,
        open_price: account.order.open_price,
        close_price: current_price,
        profit_loss: profit_loss,
        size: account.order.size
      }
      
      new_completed_trades = account.completed_trades ++ [completed_trade]
      
      # Reset position
      %{account | 
        balance: new_balance, 
        equity: new_balance,
        position: 0, 
        order: nil,
        max_equity: max(account.max_equity, new_balance),
        min_equity: min(account.min_equity, new_balance),
        completed_trades: new_completed_trades
      }
    else
      # No position to close
      account
    end
  end
  
  # Open a new position
  defp open_position(account, direction, current_price, current_time) do
    # Calculate position size based on account leverage
    size = account.balance * account.leverage / current_price
    
    # Create a new order
    order = %{
      open_price: current_price,
      open_time: current_time,
      direction: direction,
      size: size,
      open_pl: 0.0
    }
    
    # Update account
    updated_account = %{account | 
      position: direction, 
      order: order,
      max_equity: max(account.max_equity, account.equity),
      min_equity: min(account.min_equity, account.equity)
    }
    
    # Result
    result = %{
      status: :position_opened,
      direction: direction,
      price: current_price
    }
    
    {updated_account, result}
  end
  
  # Update an account with the current price
  defp update_account(account, current_price) do
    if account.position != 0 and account.order != nil do
      # Calculate unrealized profit/loss
      open_pl = calculate_profit_loss(account.order, current_price)
      
      # Update equity
      equity = account.balance + open_pl
      
      # Update order
      updated_order = %{account.order | open_pl: open_pl}
      
      # Check for margin call (if drawdown exceeds maximum)
      if equity < account.balance * (1 - @max_drawdown_percent / 100) do
        # Close position due to margin call
        close_position(account, current_price)
      else
        # Update account
        %{account | 
          equity: equity,
          order: updated_order,
          max_equity: max(account.max_equity, equity),
          min_equity: min(account.min_equity, equity)
        }
      end
    else
      # No open position
      account
    end
  end
  
  # Calculate profit/loss for an open position
  defp calculate_profit_loss(order, current_price) do
    price_diff = current_price - order.open_price
    order.direction * price_diff * order.size
  end
  
  # Update all accounts with the current price
  defp update_all_accounts(accounts, price_data) do
    Enum.reduce(accounts, %{}, fn {agent_id, account}, acc ->
      updated_account = update_account(account, price_data.close)
      Map.put(acc, agent_id, updated_account)
    end)
  end
  
  # Calculate fitness for an account
  defp calculate_fitness(account) do
    # Calculate various performance metrics
    profit_loss = account.balance - @default_balance
    profit_factor = calculate_profit_factor(account.completed_trades)
    max_drawdown = (@default_balance - account.min_equity) / @default_balance * 100
    win_rate = calculate_win_rate(account.completed_trades)
    
    # Combine metrics into a single fitness value
    # Higher is better
    [
      profit_loss,            # Raw profit/loss
      profit_factor * 1000,   # Profit factor (scaled)
      -max_drawdown * 10,     # Drawdown (negative, lower is better)
      win_rate * 1000         # Win rate (scaled)
    ]
  end
  
  # Calculate profit factor (total profits / total losses)
  defp calculate_profit_factor(completed_trades) do
    {total_profit, total_loss} = Enum.reduce(completed_trades, {0.0, 0.0}, fn trade, {profit, loss} ->
      if trade.profit_loss > 0 do
        {profit + trade.profit_loss, loss}
      else
        {profit, loss + abs(trade.profit_loss)}
      end
    end)
    
    if total_loss > 0 do
      total_profit / total_loss
    else
      if total_profit > 0, do: 100.0, else: 1.0  # Arbitrary values for edge cases
    end
  end
  
  # Calculate win rate (percentage of winning trades)
  defp calculate_win_rate(completed_trades) do
    total_trades = length(completed_trades)
    
    if total_trades > 0 do
      winning_trades = Enum.count(completed_trades, fn trade -> trade.profit_loss > 0 end)
      winning_trades / total_trades
    else
      0.0
    end
  end
end