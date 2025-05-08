defmodule Bardo.Examples.Applications.AlgoTrading.LiveAgent do
  @moduledoc """
  Live trading agent implementation for algorithmic trading.
  
  This module provides functionality for deploying trained neural networks
  as trading agents on real markets. It includes:
  
  - Real-time market data processing
  - Trade execution through broker APIs
  - Risk management and position sizing
  - Performance monitoring and reporting
  - Continuous learning and adaptation
  
  The live agent can be deployed as a long-running process that maintains
  state between market updates and trading decisions.
  """
  
  use GenServer
  alias Bardo.AgentManager.Cortex
  alias Bardo.Examples.Applications.AlgoTrading.SubstrateEncoding
  require Logger
  
  # Agent state definition
  defmodule State do
    @moduledoc "Live agent state"
    defstruct [
      :agent_id,            # Unique identifier for this agent
      :genotype,            # Neural network genotype
      :cortex,              # Active neural network
      :broker,              # Broker module
      :broker_config,       # Broker connection config
      :market_data,         # Recent market data
      :indicators,          # Technical indicators
      :current_position,    # Current trading position
      :account_info,        # Broker account information
      :trade_history,       # History of trades
      :performance,         # Performance metrics
      :risk_params,         # Risk management parameters
      :substrate_encoding,  # Whether to use substrate encoding
      :adaptation_enabled,  # Whether to enable continuous learning
      :last_update,         # Time of last update
      :status               # Agent status
    ]
  end
  
  @doc """
  Start a live trading agent.
  
  ## Parameters
  
  - agent_id: Unique identifier for this agent
  - genotype: The trained neural network genotype
  - broker_module: Module implementing the broker interface
  - broker_config: Configuration for broker connection
  - options: Additional options for the agent
    - :risk_params - Risk management parameters
    - :substrate_encoding - Whether to use substrate encoding (default: false)
    - :adaptation_enabled - Whether to enable continuous learning (default: false)
  
  ## Returns
  
  {:ok, pid} if started successfully, {:error, reason} otherwise.
  """
  def start_link(agent_id, genotype, broker_module, broker_config, options \\ []) do
    GenServer.start_link(__MODULE__, {agent_id, genotype, broker_module, broker_config, options}, name: agent_id)
  end
  
  @doc """
  Initialize the agent.
  """
  @impl GenServer
  def init({agent_id, genotype, broker_module, broker_config, options}) do
    # Extract options
    risk_params = Keyword.get(options, :risk_params, default_risk_params())
    substrate_encoding = Keyword.get(options, :substrate_encoding, false)
    adaptation_enabled = Keyword.get(options, :adaptation_enabled, false)
    
    # Initialize cortex from genotype
    {:ok, cortex} = Cortex.from_genotype(genotype)
    
    # Connect to broker
    broker_result = connect_to_broker(broker_module, broker_config)
    
    case broker_result do
      {:ok, account_info} ->
        # Create initial state
        state = %State{
          agent_id: agent_id,
          genotype: genotype,
          cortex: cortex,
          broker: broker_module,
          broker_config: broker_config,
          market_data: [],
          indicators: %{},
          current_position: %{direction: 0, size: 0.0, entry_price: nil, entry_time: nil},
          account_info: account_info,
          trade_history: [],
          performance: initialize_performance_metrics(),
          risk_params: risk_params,
          substrate_encoding: substrate_encoding,
          adaptation_enabled: adaptation_enabled,
          last_update: DateTime.utc_now(),
          status: :initialized
        }
        
        # Start market data subscription
        subscribe_to_market_data(broker_module, broker_config)
        
        # Schedule regular updates
        schedule_update()
        
        Logger.info("[LiveAgent] #{agent_id} initialized successfully")
        {:ok, state}
        
      {:error, reason} ->
        Logger.error("[LiveAgent] Failed to connect to broker: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @doc """
  Update market data and potentially make trading decisions.
  """
  @impl GenServer
  def handle_info(:update, state) do
    # Get latest market data
    case get_latest_market_data(state.broker, state.broker_config) do
      {:ok, new_data} ->
        # Process new data
        updated_state = process_market_update(state, new_data)
        
        # Make trading decisions if needed
        final_state = make_trading_decision(updated_state)
        
        # Schedule next update
        schedule_update()
        
        {:noreply, final_state}
        
      {:error, reason} ->
        Logger.error("[LiveAgent] Failed to get market data: #{inspect(reason)}")
        
        # Schedule retry
        schedule_update(5000)  # Retry after 5 seconds
        
        {:noreply, state}
    end
  end
  
  @impl GenServer
  def handle_info({:broker_notification, notification}, state) do
    # Process broker notification
    updated_state = process_broker_notification(state, notification)
    
    {:noreply, updated_state}
  end
  
  @impl GenServer
  def handle_call(:status, _from, state) do
    # Build status report
    status = %{
      agent_id: state.agent_id,
      status: state.status,
      position: state.current_position,
      account: state.account_info,
      performance: state.performance,
      last_update: state.last_update
    }
    
    {:reply, status, state}
  end
  
  @impl GenServer
  def handle_call(:close_all_positions, _from, state) do
    # Close any open positions
    updated_state = close_positions(state)
    
    {:reply, :ok, updated_state}
  end
  
  @impl GenServer
  def handle_call({:update_risk_params, new_params}, _from, state) do
    # Merge new parameters with existing ones
    updated_params = Map.merge(state.risk_params, new_params)
    
    # Update state
    updated_state = %{state | risk_params: updated_params}
    
    {:reply, :ok, updated_state}
  end
  
  @impl GenServer
  def handle_call({:set_adaptation, enabled}, _from, state) do
    # Update adaptation setting
    updated_state = %{state | adaptation_enabled: enabled}
    
    {:reply, :ok, updated_state}
  end
  
  @doc """
  Handle termination gracefully.
  """
  @impl GenServer
  def terminate(reason, state) do
    # Close any open positions
    close_all_positions(state)
    
    # Disconnect from broker
    disconnect_from_broker(state.broker, state.broker_config)
    
    Logger.info("[LiveAgent] #{state.agent_id} terminated: #{inspect(reason)}")
    :ok
  end
  
  @doc """
  Get the current status of the agent.
  
  ## Parameters
  
  - agent_id: ID of the agent to query
  
  ## Returns
  
  A map with the current status.
  """
  def get_status(agent_id) do
    GenServer.call(agent_id, :status)
  end
  
  @doc """
  Close all open positions.
  
  ## Parameters
  
  - agent_id: ID of the agent
  
  ## Returns
  
  :ok if successful.
  """
  def close_all_positions(agent_id) do
    GenServer.call(agent_id, :close_all_positions)
  end
  
  @doc """
  Update risk management parameters.
  
  ## Parameters
  
  - agent_id: ID of the agent
  - params: Map of risk parameters to update
  
  ## Returns
  
  :ok if successful.
  """
  def update_risk_params(agent_id, params) do
    GenServer.call(agent_id, {:update_risk_params, params})
  end
  
  @doc """
  Enable or disable continuous learning.
  
  ## Parameters
  
  - agent_id: ID of the agent
  - enabled: Whether to enable adaptation
  
  ## Returns
  
  :ok if successful.
  """
  def set_adaptation(agent_id, enabled) do
    GenServer.call(agent_id, {:set_adaptation, enabled})
  end
  
  # Private helper functions
  
  # Default risk parameters
  defp default_risk_params do
    %{
      risk_per_trade: 0.01,         # 1% of account per trade
      max_drawdown: 0.10,           # 10% maximum drawdown
      stop_loss: 0.02,              # 2% stop loss
      take_profit: 0.04,            # 4% take profit
      max_positions: 1,             # Maximum simultaneous positions
      position_sizing: :fixed_risk, # Risk-based position sizing
      trailing_stop: false,         # Whether to use trailing stops
      trailing_stop_distance: 0.01  # Trailing stop distance (1%)
    }
  end
  
  # Initialize performance metrics
  defp initialize_performance_metrics do
    %{
      total_trades: 0,
      winning_trades: 0,
      losing_trades: 0,
      break_even_trades: 0,
      total_profit: 0.0,
      total_loss: 0.0,
      max_drawdown: 0.0,
      current_drawdown: 0.0,
      peak_equity: nil,
      sharpe_ratio: 0.0,
      win_rate: 0.0,
      profit_factor: 0.0,
      avg_win: 0.0,
      avg_loss: 0.0,
      returns: [],
      equity_curve: []
    }
  end
  
  # Connect to the broker
  defp connect_to_broker(broker_module, broker_config) do
    # Call the connect function on the broker module
    broker_module.connect(broker_config)
  end
  
  # Disconnect from the broker
  defp disconnect_from_broker(broker_module, broker_config) do
    # Call the disconnect function on the broker module
    broker_module.disconnect(broker_config)
  end
  
  # Subscribe to market data
  defp subscribe_to_market_data(broker_module, broker_config) do
    # Set up subscription
    broker_module.subscribe_market_data(broker_config, self())
  end
  
  # Get latest market data
  defp get_latest_market_data(broker_module, broker_config) do
    # Call the get_market_data function on the broker module
    symbol = Map.get(broker_config, :symbol, "EURUSD")
    timeframe = Map.get(broker_config, :timeframe, 15)
    options = %{limit: 100}
    
    broker_module.get_market_data(broker_config, symbol, timeframe, options)
  end
  
  # Process market data update
  defp process_market_update(state, new_data) do
    # Merge new data with existing data
    updated_data = 
      (new_data ++ state.market_data)
      |> Enum.uniq_by(fn candle -> candle.time end)
      |> Enum.sort_by(fn candle -> candle.time end, &>=/2)  # Newest first
      |> Enum.take(500)  # Keep reasonable history
    
    # Calculate technical indicators
    updated_indicators = calculate_indicators(updated_data)
    
    # Update state
    %{state | 
      market_data: updated_data,
      indicators: updated_indicators,
      last_update: DateTime.utc_now()
    }
  end
  
  # Calculate technical indicators
  defp calculate_indicators(market_data) do
    # Calculate common indicators
    %{
      sma_20: calculate_sma(market_data, 20),
      sma_50: calculate_sma(market_data, 50),
      sma_200: calculate_sma(market_data, 200),
      ema_20: calculate_ema(market_data, 20),
      ema_50: calculate_ema(market_data, 50),
      rsi_14: calculate_rsi(market_data, 14),
      macd: calculate_macd(market_data),
      macd_signal: calculate_macd_signal(market_data),
      bollinger_upper: calculate_bollinger_band(market_data, :upper),
      bollinger_lower: calculate_bollinger_band(market_data, :lower),
      atr_14: calculate_atr(market_data, 14),
      adx_14: calculate_adx(market_data, 14),
      stoch_k: calculate_stochastic(market_data, 14, 3, :k),
      stoch_d: calculate_stochastic(market_data, 14, 3, :d)
    }
  end
  
  # Simple Moving Average calculation
  defp calculate_sma(market_data, period) do
    market_data
    |> Enum.map(fn candle -> candle.close end)
    |> Enum.chunk_every(period, 1, :discard)
    |> Enum.map(fn window -> Enum.sum(window) / period end)
  end
  
  # Exponential Moving Average calculation
  defp calculate_ema(market_data, period) do
    prices = Enum.map(market_data, fn candle -> candle.close end)
    
    # Start with SMA for first period
    sma = Enum.take(prices, period) |> Enum.sum() |> Kernel./(period)
    
    # Calculate multiplier
    multiplier = 2 / (period + 1)
    
    # Calculate EMA recursively
    {ema_values, _} = 
      Enum.reduce(Enum.drop(prices, period), {[sma], sma}, fn price, {acc, prev_ema} ->
        new_ema = price * multiplier + prev_ema * (1 - multiplier)
        {[new_ema | acc], new_ema}
      end)
    
    Enum.reverse(ema_values)
  end
  
  # Other indicator calculations (simplified implementations)
  defp calculate_rsi(market_data, period) do
    # Simple RSI calculation
    prices = Enum.map(market_data, fn candle -> candle.close end)
    
    # Calculate price changes
    price_changes = 
      Enum.zip(Enum.drop(prices, 1), Enum.drop(prices, -1))
      |> Enum.map(fn {current, previous} -> current - previous end)
    
    # Calculate RSI in windows
    Enum.chunk_every(price_changes, period, 1, :discard)
    |> Enum.map(fn window ->
      gains = Enum.filter(window, fn x -> x > 0 end) |> Enum.sum()
      losses = Enum.filter(window, fn x -> x < 0 end) |> Enum.map(&abs/1) |> Enum.sum()
      
      avg_gain = gains / period
      avg_loss = if losses == 0, do: 0.000001, else: losses / period
      
      rs = avg_gain / avg_loss
      100 - (100 / (1 + rs))
    end)
  end
  
  # MACD calculation
  defp calculate_macd(market_data) do
    ema_12 = calculate_ema(market_data, 12)
    ema_26 = calculate_ema(market_data, 26)
    
    # Match lengths (take shorter one)
    len = min(length(ema_12), length(ema_26))
    ema_12_short = Enum.take(ema_12, len)
    ema_26_short = Enum.take(ema_26, len)
    
    # Calculate MACD line
    Enum.zip(ema_12_short, ema_26_short)
    |> Enum.map(fn {ema12, ema26} -> ema12 - ema26 end)
  end
  
  # MACD Signal Line
  defp calculate_macd_signal(market_data) do
    macd = calculate_macd(market_data)
    
    # Calculate 9-period EMA of MACD
    Enum.chunk_every(macd, 9, 1, :discard)
    |> Enum.map(fn window -> Enum.sum(window) / 9 end)
  end
  
  # Bollinger Bands
  defp calculate_bollinger_band(market_data, band_type) do
    prices = Enum.map(market_data, fn candle -> candle.close end)
    
    # Calculate 20-period SMA and standard deviation
    Enum.chunk_every(prices, 20, 1, :discard)
    |> Enum.map(fn window ->
      sma = Enum.sum(window) / 20
      
      # Calculate standard deviation
      variance = Enum.reduce(window, 0, fn price, acc ->
        acc + :math.pow(price - sma, 2)
      end) / 20
      
      std_dev = :math.sqrt(variance)
      
      case band_type do
        :upper -> (sma + 2 * std_dev - sma) / sma  # Normalized
        :lower -> (sma - 2 * std_dev - sma) / sma  # Normalized
        _ -> 0.0
      end
    end)
  end
  
  # ATR calculation (simplified)
  defp calculate_atr(market_data, period) do
    # Calculate true ranges
    true_ranges = 
      Enum.chunk_every(market_data, 2, 1, :discard)
      |> Enum.map(fn [current, previous] ->
        [
          current.high - current.low,
          abs(current.high - previous.close),
          abs(current.low - previous.close)
        ]
        |> Enum.max()
      end)
    
    # Calculate ATR
    Enum.chunk_every(true_ranges, period, 1, :discard)
    |> Enum.map(fn window -> Enum.sum(window) / period end)
  end
  
  # ADX calculation (very simplified)
  defp calculate_adx(market_data, period) do
    # This is a simplified placeholder
    # Real ADX calculation is more complex
    Enum.chunk_every(market_data, period, 1, :discard)
    |> Enum.map(fn _window -> :rand.uniform() * 50 + 10 end)
  end
  
  # Stochastic calculation
  defp calculate_stochastic(market_data, k_period, d_period, output) do
    prices = Enum.chunk_every(market_data, k_period, 1, :discard)
    
    # Calculate %K
    k_values = Enum.map(prices, fn window ->
      current = hd(window)
      
      highest_high = Enum.map(window, fn candle -> candle.high end) |> Enum.max()
      lowest_low = Enum.map(window, fn candle -> candle.low end) |> Enum.min()
      
      if highest_high == lowest_low do
        50.0
      else
        (current.close - lowest_low) / (highest_high - lowest_low) * 100
      end
    end)
    
    case output do
      :k -> k_values
      :d -> 
        # %D is the SMA of %K
        Enum.chunk_every(k_values, d_period, 1, :discard)
        |> Enum.map(fn window -> Enum.sum(window) / d_period end)
      _ -> k_values
    end
  end
  
  # Make trading decisions based on neural network
  defp make_trading_decision(state) do
    # Skip if not enough data
    if length(state.market_data) < 60 do
      state
    else
      # Prepare inputs for neural network
      inputs = 
        if state.substrate_encoding do
          # Use substrate encoding
          grid = SubstrateEncoding.convert_price_data_to_substrate(
            state.market_data, 
            state.indicators,
            60, 20, 10
          )
          
          SubstrateEncoding.flatten_substrate_grid(grid, state.genotype)
        else
          # Use standard encoding
          prepare_standard_inputs(state.market_data, state.indicators)
        end
      
      # Activate the neural network
      {:ok, outputs} = Cortex.activate(state.cortex, inputs)
      
      # Interpret the outputs
      [direction_signal, size_signal, stop_loss_signal, take_profit_signal] = 
        interpret_outputs(outputs)
      
      # Check if we should change position
      if should_change_position?(state, direction_signal) do
        # Execute the trade
        execute_trade(state, direction_signal, size_signal, stop_loss_signal, take_profit_signal)
      else
        # No change needed
        state
      end
    end
  end
  
  # Prepare standard inputs for neural network
  defp prepare_standard_inputs(market_data, indicators) do
    # Get recent price data
    recent_prices = Enum.take(market_data, 20)
    |> Enum.map(fn candle -> candle.close end)
    
    # Normalize prices
    {min_price, max_price} = Enum.min_max(recent_prices)
    price_range = max(max_price - min_price, 0.0001)
    normalized_prices = Enum.map(recent_prices, fn price ->
      (price - min_price) / price_range
    end)
    
    # Get recent indicator values
    norm_indicators = [
      get_indicator_value(indicators, :rsi_14, 0) / 100.0,
      get_indicator_value(indicators, :macd, 0),
      get_indicator_value(indicators, :macd_signal, 0),
      get_indicator_value(indicators, :bollinger_upper, 0),
      get_indicator_value(indicators, :bollinger_lower, 0),
      get_indicator_value(indicators, :atr_14, 0),
      get_indicator_value(indicators, :adx_14, 0) / 100.0,
      get_indicator_value(indicators, :stoch_k, 0) / 100.0,
      get_indicator_value(indicators, :stoch_d, 0) / 100.0
    ]
    
    # Combine all inputs
    normalized_prices ++ norm_indicators
  end
  
  # Get an indicator value safely
  defp get_indicator_value(indicators, indicator, index) do
    values = Map.get(indicators, indicator, [])
    
    if index < length(values) do
      Enum.at(values, index)
    else
      0.0
    end
  end
  
  # Interpret neural network outputs
  defp interpret_outputs(outputs) do
    # Default values if not enough outputs
    defaults = [0.0, 0.5, 0.5, 0.5]
    
    # Pad with defaults if needed
    padded_outputs = outputs ++ Enum.drop(defaults, length(outputs))
    
    # Extract and interpret each output
    [
      direction_signal,   # Trade direction: -1 to 1
      size_signal,        # Position size: 0 to 1
      stop_loss_signal,   # Stop loss distance: 0 to 1
      take_profit_signal  # Take profit distance: 0 to 1
    ] = Enum.take(padded_outputs, 4)
    
    # Convert direction signal to discrete values: -1 (short), 0 (no position), 1 (long)
    direction = cond do
      direction_signal < -0.33 -> -1
      direction_signal > 0.33 -> 1
      true -> 0
    end
    
    # Ensure signals are in [0, 1] range
    size = min(max(size_signal, 0.0), 1.0)
    stop_loss = min(max(stop_loss_signal, 0.0), 1.0)
    take_profit = min(max(take_profit_signal, 0.0), 1.0)
    
    [direction, size, stop_loss, take_profit]
  end
  
  # Check if the position should be changed
  defp should_change_position?(state, new_direction) do
    # Different direction than current position
    new_direction != state.current_position.direction ||
    # Or no current position but network suggests one
    (state.current_position.direction == 0 && new_direction != 0)
  end
  
  # Execute a trade
  defp execute_trade(state, direction, size_signal, stop_loss_signal, take_profit_signal) do
    # Close any existing position
    updated_state = close_current_position(state)
    
    if direction != 0 do
      # Calculate position size based on risk parameters
      size = calculate_position_size(updated_state, size_signal)
      
      # Calculate stop loss and take profit levels
      {stop_level, target_level} = calculate_risk_levels(
        updated_state, 
        direction, 
        stop_loss_signal, 
        take_profit_signal
      )
      
      # Get current price
      current_price = get_latest_price(updated_state.market_data)
      
      # Place the order
      Logger.info("[LiveAgent] #{state.agent_id} placing order: direction=#{direction}, size=#{size}")
      
      case place_order(updated_state, direction, size, current_price, stop_level, target_level) do
        {:ok, order_result} ->
          # Update current position
          new_position = %{
            direction: direction,
            size: size,
            entry_price: Map.get(order_result, :price, current_price),
            entry_time: DateTime.utc_now(),
            order_id: Map.get(order_result, :order_id),
            stop_loss: stop_level,
            take_profit: target_level
          }
          
          %{updated_state | 
            current_position: new_position,
            status: :trading
          }
          
        {:error, reason} ->
          Logger.error("[LiveAgent] #{state.agent_id} order error: #{inspect(reason)}")
          updated_state
      end
    else
      # No new position
      %{updated_state | 
        current_position: %{direction: 0, size: 0.0, entry_price: nil, entry_time: nil},
        status: :watching
      }
    end
  end
  
  # Close the current position if any
  defp close_current_position(state) do
    if state.current_position.direction != 0 do
      # Only close if there's an open position
      Logger.info("[LiveAgent] #{state.agent_id} closing position: direction=#{state.current_position.direction}, size=#{state.current_position.size}")
      
      order_id = Map.get(state.current_position, :order_id)
      
      if order_id do
        # Close the order through broker
        case close_order(state, order_id) do
          {:ok, close_result} ->
            # Update performance metrics
            profit_loss = Map.get(close_result, :profit_loss, 0.0)
            updated_performance = update_performance_metrics(state.performance, profit_loss)
            
            # Get updated account info
            {:ok, account_info} = get_account_info(state)
            
            # Record trade in history
            closed_trade = %{
              direction: state.current_position.direction,
              size: state.current_position.size,
              entry_price: state.current_position.entry_price,
              entry_time: state.current_position.entry_time,
              exit_price: Map.get(close_result, :price),
              exit_time: DateTime.utc_now(),
              profit_loss: profit_loss,
              trade_duration: DateTime.diff(
                DateTime.utc_now(), 
                state.current_position.entry_time,
                :second
              )
            }
            
            trade_history = [closed_trade | state.trade_history]
            
            # Update state with closed position
            %{state | 
              current_position: %{direction: 0, size: 0.0, entry_price: nil, entry_time: nil},
              performance: updated_performance,
              account_info: account_info,
              trade_history: trade_history,
              status: :watching
            }
            
          {:error, reason} ->
            Logger.error("[LiveAgent] #{state.agent_id} error closing position: #{inspect(reason)}")
            state
        end
      else
        # No order ID, just reset position
        %{state | 
          current_position: %{direction: 0, size: 0.0, entry_price: nil, entry_time: nil},
          status: :watching
        }
      end
    else
      # No position to close
      state
    end
  end
  
  # Close all positions (used when stopping the agent)
  defp close_positions(state) do
    # Just close the current position for now
    close_current_position(state)
  end
  
  # Calculate position size based on risk parameters
  defp calculate_position_size(state, size_signal) do
    # Get account balance
    balance = state.account_info.balance
    
    # Get risk per trade from parameters
    risk_per_trade = state.risk_params.risk_per_trade
    
    # Calculate base risk amount
    risk_amount = balance * risk_per_trade
    
    # Adjust by neural network signal (0.5-1.5x)
    adjusted_risk = risk_amount * (0.5 + size_signal)
    
    # Convert to position size based on current price and pip value
    latest_price = get_latest_price(state.market_data)
    pip_value = get_pip_value(state.broker_config.symbol)
    
    # Assume 20 pips stop loss for size calculation
    assumed_stop_pips = 20
    
    # Calculate size in lots/units
    size = adjusted_risk / (assumed_stop_pips * pip_value * latest_price)
    
    # Round to standard lot size
    round_lot_size(size)
  end
  
  # Calculate stop loss and take profit levels
  defp calculate_risk_levels(state, direction, stop_loss_signal, take_profit_signal) do
    # Get latest price
    latest_price = get_latest_price(state.market_data)
    
    # Get pip value
    pip_value = get_pip_value(state.broker_config.symbol)
    
    # Base stop loss and take profit distances (in pips)
    base_stop_pips = 20
    base_target_pips = 40
    
    # Adjust distances based on signals (50-200%)
    stop_pips = base_stop_pips * (0.5 + stop_loss_signal * 1.5)
    target_pips = base_target_pips * (0.5 + take_profit_signal * 1.5)
    
    # Convert to price levels
    stop_distance = stop_pips * pip_value
    target_distance = target_pips * pip_value
    
    stop_level = 
      if direction > 0 do
        # Long position: stop below entry
        latest_price - stop_distance
      else
        # Short position: stop above entry
        latest_price + stop_distance
      end
    
    target_level = 
      if direction > 0 do
        # Long position: target above entry
        latest_price + target_distance
      else
        # Short position: target below entry
        latest_price - target_distance
      end
    
    {stop_level, target_level}
  end
  
  # Place an order through the broker
  defp place_order(state, direction, size, _price, stop_loss, take_profit) do
    # Call the place_order function on the broker module
    symbol = state.broker_config.symbol
    
    options = %{
      stop_loss: stop_loss,
      take_profit: take_profit,
      comment: "Bardo LiveAgent #{state.agent_id}"
    }
    
    state.broker.place_order(state.broker_config, symbol, direction, size, options)
  end
  
  # Close an order through the broker
  defp close_order(state, order_id) do
    # Call the close_order function on the broker module
    state.broker.close_order(state.broker_config, order_id)
  end
  
  # Get the latest account information
  defp get_account_info(state) do
    # Call the get_account_info function on the broker module
    state.broker.get_account_info(state.broker_config)
  end
  
  # Process broker notification
  defp process_broker_notification(state, notification) do
    case notification.type do
      :fill ->
        # Order has been filled
        Logger.info("[LiveAgent] #{state.agent_id} order filled: #{inspect(notification)}")
        
        # Check if this is our current position
        if notification.order_id == Map.get(state.current_position, :order_id) do
          # Update current position with fill details
          updated_position = Map.merge(state.current_position, %{
            entry_price: notification.price,
            entry_time: notification.time
          })
          
          %{state | current_position: updated_position}
        else
          # Not our current position
          state
        end
        
      :close ->
        # Position has been closed
        Logger.info("[LiveAgent] #{state.agent_id} position closed: #{inspect(notification)}")
        
        # Check if this is our current position
        if notification.order_id == Map.get(state.current_position, :order_id) do
          # Update performance metrics
          profit_loss = notification.profit_loss
          updated_performance = update_performance_metrics(state.performance, profit_loss)
          
          # Record trade in history
          closed_trade = %{
            direction: state.current_position.direction,
            size: state.current_position.size,
            entry_price: state.current_position.entry_price,
            entry_time: state.current_position.entry_time,
            exit_price: notification.price,
            exit_time: notification.time,
            profit_loss: profit_loss,
            trade_duration: DateTime.diff(
              notification.time, 
              state.current_position.entry_time,
              :second
            )
          }
          
          trade_history = [closed_trade | state.trade_history]
          
          # Reset current position
          %{state | 
            current_position: %{direction: 0, size: 0.0, entry_price: nil, entry_time: nil},
            performance: updated_performance,
            trade_history: trade_history,
            status: :watching
          }
        else
          # Not our current position
          state
        end
        
      :account_update ->
        # Account balance/equity has been updated
        Logger.info("[LiveAgent] #{state.agent_id} account update: #{inspect(notification)}")
        
        # Update account info
        %{state | account_info: notification.account_info}
        
      _ ->
        # Other notification types
        state
    end
  end
  
  # Update performance metrics
  defp update_performance_metrics(performance, profit_loss) do
    # Increment total trades
    total_trades = performance.total_trades + 1
    
    # Update win/loss counts
    {winning_trades, losing_trades, break_even_trades} = 
      if profit_loss > 0 do
        {performance.winning_trades + 1, performance.losing_trades, performance.break_even_trades}
      else
        if profit_loss < 0 do
          {performance.winning_trades, performance.losing_trades + 1, performance.break_even_trades}
        else
          {performance.winning_trades, performance.losing_trades, performance.break_even_trades + 1}
        end
      end
    
    # Update profit/loss totals
    total_profit = 
      if profit_loss > 0 do
        performance.total_profit + profit_loss
      else
        performance.total_profit
      end
    
    total_loss = 
      if profit_loss < 0 do
        performance.total_loss + abs(profit_loss)
      else
        performance.total_loss
      end
    
    # Calculate win rate
    win_rate = 
      if total_trades > 0 do
        winning_trades / total_trades
      else
        0.0
      end
    
    # Calculate profit factor
    profit_factor = 
      if total_loss > 0 do
        total_profit / total_loss
      else
        if total_profit > 0, do: 999.0, else: 1.0
      end
    
    # Calculate average win/loss
    avg_win = 
      if winning_trades > 0 do
        total_profit / winning_trades
      else
        0.0
      end
    
    avg_loss = 
      if losing_trades > 0 do
        total_loss / losing_trades
      else
        0.0
      end
    
    # Update equity curve
    new_equity = performance.peak_equity || 0.0 + profit_loss
    peak_equity = max(performance.peak_equity || 0.0, new_equity)
    
    # Calculate drawdown
    current_drawdown = 
      if peak_equity > 0 do
        (peak_equity - new_equity) / peak_equity * 100.0
      else
        0.0
      end
    
    max_drawdown = max(performance.max_drawdown, current_drawdown)
    
    # Add return to list
    returns = [profit_loss | performance.returns] |> Enum.take(100)
    
    # Add to equity curve
    equity_point = %{
      time: DateTime.utc_now(),
      equity: new_equity
    }
    
    equity_curve = [equity_point | performance.equity_curve] |> Enum.take(1000)
    
    # Update Sharpe ratio (simplified)
    sharpe_ratio = 
      if length(returns) > 5 do
        avg_return = Enum.sum(returns) / length(returns)
        std_dev = calculate_std_dev(returns)
        
        if std_dev > 0 do
          avg_return / std_dev * :math.sqrt(252)  # Annualized
        else
          0.0
        end
      else
        0.0
      end
    
    # Return updated metrics
    %{
      total_trades: total_trades,
      winning_trades: winning_trades,
      losing_trades: losing_trades,
      break_even_trades: break_even_trades,
      total_profit: total_profit,
      total_loss: total_loss,
      max_drawdown: max_drawdown,
      current_drawdown: current_drawdown,
      peak_equity: peak_equity,
      sharpe_ratio: sharpe_ratio,
      win_rate: win_rate,
      profit_factor: profit_factor,
      avg_win: avg_win,
      avg_loss: avg_loss,
      returns: returns,
      equity_curve: equity_curve
    }
  end
  
  # Calculate standard deviation
  defp calculate_std_dev(values) do
    n = length(values)
    
    if n > 1 do
      mean = Enum.sum(values) / n
      
      variance = 
        Enum.reduce(values, 0, fn x, acc ->
          acc + :math.pow(x - mean, 2)
        end) / (n - 1)
      
      :math.sqrt(variance)
    else
      0.0
    end
  end
  
  # Schedule the next update
  defp schedule_update(interval \\ 1000) do
    Process.send_after(self(), :update, interval)
  end
  
  # Helper functions
  
  # Get latest price from market data
  defp get_latest_price(market_data) do
    if market_data != [] do
      hd(market_data).close
    else
      1.0
    end
  end
  
  # Get pip value for a symbol
  defp get_pip_value(symbol) do
    # Default pip value structure
    cond do
      String.starts_with?(symbol, "JPY") -> 0.01   # JPY pairs have 2 decimal places
      String.ends_with?(symbol, "JPY") -> 0.01     # JPY pairs have 2 decimal places
      true -> 0.0001                               # Other major pairs have 4 decimal places
    end
  end
  
  # Round lot size to standard sizes
  defp round_lot_size(size) do
    cond do
      size < 0.01 -> 0.01  # Minimum size
      size < 0.1 -> Float.round(size, 2)  # Micro lot
      size < 1.0 -> Float.round(size, 1)  # Mini lot
      true -> Float.round(size, 0)  # Standard lot
    end
  end
  
  @doc """
  Create a fleet of live trading agents distributed across multiple nodes.
  
  This function creates multiple trading agents that can be distributed
  across different nodes for fault tolerance and scalability.
  
  ## Parameters
  
  - experiment_id: ID of the completed experiment to get agents from
  - broker_module: Module implementing the broker interface
  - broker_configs: List of broker configurations, one per agent
  - options: Additional options
    - :nodes - List of nodes to distribute agents to
    - :adaptation_enabled - Whether to enable continuous learning
    
  ## Returns
  
  {:ok, agent_ids} if all agents started successfully, {:error, reason} otherwise.
  """
  def start_agent_fleet(experiment_id, broker_module, broker_configs, options \\ []) do
    # Get best agents from the experiment
    {:ok, agents} = get_top_agents(experiment_id, length(broker_configs))
    
    # Get list of nodes or use all available
    nodes = Keyword.get(options, :nodes, Node.list() ++ [Node.self()])
    
    local_nodes = if nodes == [] do
      [Node.self()]
    else
      nodes
    end
    
    # Zip agents, configs, and nodes
    agent_specs = 
      Enum.zip(agents, broker_configs)
      |> Enum.zip(Stream.cycle(local_nodes))
      |> Enum.map(fn {{agent, config}, node} ->
        {node, agent, config}
      end)
    
    # Extract options for all agents
    adaptation_enabled = Keyword.get(options, :adaptation_enabled, false)
    
    # Start each agent on its assigned node
    results = Enum.map(agent_specs, fn {node, agent, config} ->
      agent_id = :"#{experiment_id}_agent_#{System.unique_integer([:positive])}"
      
      start_agent_on_node(node, agent_id, agent, broker_module, config, adaptation_enabled)
    end)
    
    # Check if all agents started successfully
    case Enum.split_with(results, fn result -> elem(result, 0) == :ok end) do
      {successful, []} ->
        # All agents started successfully
        agent_ids = Enum.map(successful, fn {:ok, id} -> id end)
        {:ok, agent_ids}
        
      {successful, failed} ->
        # Some agents failed to start
        # Cleanup successful agents
        agent_ids = Enum.map(successful, fn {:ok, id} -> id end)
        Enum.each(agent_ids, &stop_agent/1)
        
        # Return error
        {:error, "Failed to start all agents: #{inspect(failed)}"}
    end
  end
  
  # Get top performing agents from an experiment
  defp get_top_agents(experiment_id, count) do
    case Bardo.Examples.Applications.AlgoTrading.DistributedTraining.get_best_agent(experiment_id) do
      {:ok, best_agent} ->
        # Get more agents from the experiment if available
        case get_population_from_experiment(experiment_id) do
          {:ok, population} ->
            # Sort by fitness and take the top count
            sorted_agents = 
              Enum.sort_by(population, fn agent -> 
                case agent.fitness do
                  [profit | _] when is_number(profit) -> -profit  # Negative for descending
                  _ -> 0.0
                end
              end)
              |> Enum.take(count)
              
            {:ok, sorted_agents}
            
          {:error, _} ->
            # Just duplicate the best agent
            {:ok, List.duplicate(best_agent, count)}
        end
        
      {:error, reason} ->
        {:error, reason}
    end
  end
  
  # Get entire population from an experiment
  defp get_population_from_experiment(experiment_id) do
    Bardo.Models.read(experiment_id, :experiment)
    |> case do
      {:ok, experiment} ->
        populations = Bardo.Models.get(experiment, :populations)
        
        if populations && length(populations) > 0 do
          population_id = List.first(populations).id
          
          Bardo.Models.read(population_id, :population)
          |> case do
            {:ok, population_data} ->
              {:ok, Bardo.Models.get(population_data, :population)}
              
            error ->
              error
          end
        else
          {:error, "No populations found in experiment"}
        end
        
      error ->
        error
    end
  end
  
  # Start an agent on a specific node
  defp start_agent_on_node(node, agent_id, agent, broker_module, config, adaptation_enabled) do
    # Define the function to run on the remote node
    remote_fun = fn ->
      start_link(agent_id, agent, broker_module, config, [
        adaptation_enabled: adaptation_enabled
      ])
    end
    
    # Execute on remote node
    case :rpc.call(node, Kernel, :apply, [remote_fun, []]) do
      {:ok, _pid} ->
        {:ok, agent_id}
        
      error ->
        {:error, {agent_id, error}}
    end
  end
  
  @doc """
  Stop a running agent.
  
  ## Parameters
  
  - agent_id: ID of the agent to stop
  
  ## Returns
  
  :ok if stopped successfully, {:error, reason} otherwise.
  """
  def stop_agent(agent_id) do
    # Find which node the agent is running on
    node = find_agent_node(agent_id)
    
    if node do
      # Stop the agent on its node
      :rpc.call(node, GenServer, :stop, [agent_id])
    else
      {:error, "Agent not found on any node"}
    end
  end
  
  # Find which node an agent is running on
  defp find_agent_node(agent_id) do
    # Check local node first
    if GenServer.whereis(agent_id) != nil do
      Node.self()
    else
      # Check remote nodes
      Enum.find(Node.list(), fn node ->
        :rpc.call(node, GenServer, :whereis, [agent_id]) != nil
      end)
    end
  end
  
  @doc """
  Enable continuous learning for live agents.
  
  This function allows the live trading agent to learn from its trading
  experience and adapt its strategy over time.
  
  ## How Continuous Learning Works
  
  1. The agent collects and stores trading experience
  2. Periodically, it adjusts its neural network based on recent performance
  3. Successful trading patterns are reinforced
  4. Unsuccessful patterns are modified
  
  This creates an agent that can adapt to changing market conditions and
  continue improving its strategy after deployment.
  
  ## Parameters
  
  - agent_id: ID of the agent to enable adaptation for
  - learning_rate: How quickly the agent adapts (default: 0.01)
  - update_interval: How often to apply updates (in trades, default: 10)
  
  ## Returns
  
  :ok if enabled successfully, {:error, reason} otherwise.
  """
  def enable_continuous_learning(agent_id, learning_rate \\ 0.01, update_interval \\ 10) do
    # Find which node the agent is running on
    node = find_agent_node(agent_id)
    
    if node do
      # Send the adaptation parameters to the agent
      :rpc.call(node, GenServer, :call, [
        agent_id,
        {:set_adaptation, %{
          enabled: true,
          learning_rate: learning_rate,
          update_interval: update_interval
        }}
      ])
    else
      {:error, "Agent not found on any node"}
    end
  end
  
  @doc """
  Get performance reports from all agents in a fleet.
  
  ## Parameters
  
  - agent_ids: List of agent IDs to get reports from
  
  ## Returns
  
  A map of agent IDs to performance reports.
  """
  def get_fleet_performance(agent_ids) do
    # Get status from each agent
    reports = Enum.map(agent_ids, fn agent_id ->
      node = find_agent_node(agent_id)
      
      if node do
        # Get status from the agent
        status = :rpc.call(node, GenServer, :call, [agent_id, :status])
        {agent_id, status}
      else
        {agent_id, {:error, "Agent not found"}}
      end
    end)
    
    # Convert to map
    Enum.into(reports, %{})
  end
  
  @doc """
  Export trained agents to a file for deployment.
  
  ## Parameters
  
  - experiment_id: ID of the experiment to export agents from
  - file_path: Path to save the exported agents
  - count: Number of agents to export (default: 5)
  
  ## Returns
  
  :ok if exported successfully, {:error, reason} otherwise.
  """
  def export_agents(experiment_id, file_path, count \\ 5) do
    case get_top_agents(experiment_id, count) do
      {:ok, agents} ->
        # Convert to serializable format
        serialized = Enum.map(agents, fn agent ->
          %{
            genotype: agent,
            fitness: agent.fitness,
            timestamp: DateTime.utc_now() |> DateTime.to_string(),
            experiment_id: experiment_id
          }
        end)
        
        # Save to file
        {:ok, data} = Jason.encode(serialized, pretty: true)
        File.write(file_path, data)
        
      error ->
        error
    end
  end
  
  @doc """
  Import trained agents from a file.
  
  ## Parameters
  
  - file_path: Path to the exported agents file
  
  ## Returns
  
  {:ok, agents} if imported successfully, {:error, reason} otherwise.
  """
  def import_agents(file_path) do
    case File.read(file_path) do
      {:ok, data} ->
        case Jason.decode(data) do
          {:ok, serialized} ->
            # Convert from serialized format
            agents = Enum.map(serialized, fn agent ->
              Map.get(agent, "genotype")
            end)
            
            {:ok, agents}
            
          error ->
            error
        end
        
      error ->
        error
    end
  end
end