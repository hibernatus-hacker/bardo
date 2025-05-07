defmodule Mix.Tasks.RunAlgoTrading do
  @moduledoc """
  Mix task for running the algorithmic trading example.
  
  This task provides a convenient way to run the algorithmic trading example
  with various configuration options.
  
  ## Usage
  
  ```
  # Run with default settings (EURUSD/15m)
  mix run_algo_trading
  
  # Run with specific market and timeframe
  mix run_algo_trading --market forex --symbol GBPUSD --timeframe 60
  
  # Run with optimization parameters
  mix run_algo_trading --generations 200 --population 150
  
  # Run with backtesting options
  mix run_algo_trading --test-period last_month
  ```
  
  ## Options
  
  * `--market` - Market to trade (forex, crypto) (default: forex)
  * `--symbol` - Symbol to trade (default: EURUSD)
  * `--timeframe` - Trading timeframe in minutes (default: 15)
  * `--generations` - Number of generations to evolve (default: 100)
  * `--population` - Population size (default: 100)
  * `--test` - Run in test mode with smaller dataset
  * `--visualize` - Enable visualization (if available)
  * `--test-period` - Test period for backtesting (last_week, last_month, last_year)
  * `--start-date` - Start date for custom test period (ISO format)
  * `--end-date` - End date for custom test period (ISO format)
  
  ## Examples
  
  ```
  # Run forex trading on EURUSD with 15-minute timeframe
  mix run_algo_trading --market forex --symbol EURUSD --timeframe 15
  
  # Run crypto trading on Bitcoin with 1-hour timeframe
  mix run_algo_trading --market crypto --symbol BTCUSD --timeframe 60
  
  # Run with larger population and more generations
  mix run_algo_trading --population 200 --generations 500
  
  # Run with last month's data for testing
  mix run_algo_trading --test --test-period last_month
  
  # Run with custom date range
  mix run_algo_trading --start-date 2023-01-01 --end-date 2023-03-31
  ```
  """
  
  use Mix.Task
  alias Bardo.Examples.Applications.AlgoTrading
  
  @shortdoc "Run algorithmic trading example"
  
  def run(args) do
    # Ensure Bardo application is started
    Mix.Task.run("app.start")
    
    # Parse command-line options
    {opts, _, _} = OptionParser.parse(args, 
      switches: [
        market: :string,
        symbol: :string,
        timeframe: :integer,
        generations: :integer,
        population: :integer,
        test: :boolean,
        visualize: :boolean,
        test_period: :string,
        start_date: :string,
        end_date: :string
      ]
    )
    
    # Create experiment ID
    experiment_id = :"algo_trading_#{:erlang.system_time(:second)}"
    
    # Set configuration options
    market = String.to_atom(Keyword.get(opts, :market, "forex"))
    symbol = Keyword.get(opts, :symbol, "EURUSD")
    timeframe = Keyword.get(opts, :timeframe, 15)
    
    # Reduce dataset size if in test mode
    test_mode = Keyword.get(opts, :test, false)
    generations = if test_mode, do: 10, else: Keyword.get(opts, :generations, 100)
    population_size = if test_mode, do: 20, else: Keyword.get(opts, :population, 100)
    data_window = if test_mode, do: 1000, else: 5000
    
    # Visualization option
    visualize = Keyword.get(opts, :visualize, false)
    
    # Testing period options
    test_period = Keyword.get(opts, :test_period)
    start_date = Keyword.get(opts, :start_date)
    end_date = Keyword.get(opts, :end_date)
    
    # Print welcome message
    IO.puts("\n🤖 Running Algorithmic Trading Example")
    IO.puts("=====================================")
    IO.puts("Market: #{market}")
    IO.puts("Symbol: #{symbol}")
    IO.puts("Timeframe: #{timeframe} minutes")
    IO.puts("Generations: #{generations}")
    IO.puts("Population: #{population_size}")
    if test_mode do
      IO.puts("Mode: Test (reduced dataset)")
    end
    
    # Configure experiment
    config_opts = %{
      market: market,
      symbol: symbol,
      timeframe: timeframe,
      population_size: population_size,
      data_window: data_window,
      generations: generations,
      use_external_data: false
    }
    
    # Add test period options if specified
    config_opts = if test_period do
      Map.put(config_opts, :test_period, test_period)
    else
      config_opts
    end
    
    # Add date range if specified
    config_opts = if start_date && end_date do
      config_opts
      |> Map.put(:start_date, start_date)
      |> Map.put(:end_date, end_date)
    else
      config_opts
    end
    
    # Run the experiment
    AlgoTrading.run(experiment_id, config_opts)
    
    # If test mode, run a test with the best agent
    if test_period || (start_date && end_date) do
      test_opts = %{
        test_period: test_period,
        start_date: start_date,
        end_date: end_date
      }
      
      AlgoTrading.test_best_agent(experiment_id, test_opts)
    end
  end
end