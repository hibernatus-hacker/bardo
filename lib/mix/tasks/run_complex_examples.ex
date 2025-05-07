defmodule Mix.Tasks.RunComplexExamples do
  @moduledoc """
  Mix task to run complex neuroevolution examples with improved user experience.
  
  This task provides an interactive way to run and visualize the complex
  examples included in Bardo, with progress tracking and better feedback.
  
  ## Usage
  
  ```bash
  # Run with default settings - interactive menu
  $ mix run_complex_examples
  
  # Run a specific example directly
  $ mix run_complex_examples --example flatland
  $ mix run_complex_examples --example fx
  
  # Customize parameters (all optional)
  $ mix run_complex_examples --example flatland --generations 10 --size 5
  ```
  
  ## Options
  
  * `--example` - The example to run (flatland or fx)
  * `--generations` - Number of generations to evolve (default varies by example)
  * `--size` - Population size (default varies by example)
  * `--visualize` - Whether to run visualization after completion (default: true)
  """
  
  use Mix.Task
  
  @shortdoc "Run complex Bardo neuroevolution examples with improved experience"
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, 
      switches: [
        example: :string,
        generations: :integer,
        size: :integer,
        visualize: :boolean
      ],
      aliases: [
        e: :example,
        g: :generations,
        s: :size,
        v: :visualize
      ]
    )
    
    # Start the application
    Mix.Task.run("app.start", [])
    
    # Default visualization to true unless explicitly set to false
    opts = Keyword.put_new(opts, :visualize, true)
    
    case Keyword.get(opts, :example) do
      "flatland" ->
        run_flatland_example(opts)
        
      "fx" ->
        run_fx_example(opts)
        
      nil ->
        # Show menu if no example specified
        show_interactive_menu()
        
      unknown ->
        IO.puts("Unknown example: #{unknown}")
        show_help()
    end
  end
  
  # Run the Flatland example with the given options
  defp run_flatland_example(opts) do
    predator_population = Keyword.get(opts, :size, 5)
    prey_population = Keyword.get(opts, :size, 5)
    generations = Keyword.get(opts, :generations, 10)
    plant_quantity = 20
    simulation_steps = 500
    
    # Ensure experiment_id is unique
    experiment_id = :"flatland_example_#{System.system_time(:second)}"
    
    # Run the example
    result = Bardo.Examples.Applications.Flatland.run(
      experiment_id, 
      predator_population, 
      prey_population, 
      plant_quantity, 
      simulation_steps, 
      generations
    )
    
    # Run visualization if requested and experiment succeeded
    if result == :ok and Keyword.get(opts, :visualize, true) do
      Bardo.Examples.Applications.Flatland.visualize(experiment_id)
    end
  end
  
  # Run the FX example with the given options
  defp run_fx_example(opts) do
    population_size = Keyword.get(opts, :size, 10)
    generations = Keyword.get(opts, :generations, 10)
    data_window = 500
    
    # Ensure experiment_id is unique
    experiment_id = :"fx_example_#{System.system_time(:second)}"
    
    # Run the example
    result = Bardo.Examples.Applications.Fx.run(
      experiment_id, 
      population_size, 
      data_window, 
      generations
    )
    
    # Run test if requested and experiment succeeded
    if result == :ok and Keyword.get(opts, :visualize, true) do
      Bardo.Examples.Applications.Fx.test_best_agent(experiment_id)
    end
  end
  
  # Show an interactive menu to select examples
  defp show_interactive_menu do
    IO.puts("""
    
    ===== Bardo Complex Examples Menu =====
    
    Select an example to run:
    
    1) Flatland Predator-Prey Simulation
       - A 2D world where predators and prey evolve to survive
       - Predators hunt prey, prey hunt plants
    
    2) Forex (FX) Trading Simulation
       - Evolution of trading strategies on historical price data
       - Neural networks learn to make profitable trading decisions
    
    q) Quit
    
    ===================================
    """)
    
    choice = IO.gets("Enter your choice (1, 2, or q): ") |> String.trim()
    
    case choice do
      "1" ->
        get_parameters_and_run_flatland()
        
      "2" ->
        get_parameters_and_run_fx()
        
      "q" ->
        IO.puts("Exiting...")
        
      _ ->
        IO.puts("Invalid choice: #{choice}")
        show_interactive_menu()
    end
  end
  
  # Get parameters for Flatland and run
  defp get_parameters_and_run_flatland do
    IO.puts("\n--- Flatland Configuration ---")
    
    # Get parameters with defaults
    predator_population = get_integer_input("Predator population size (default: 5): ", 5)
    prey_population = get_integer_input("Prey population size (default: 5): ", 5)
    generations = get_integer_input("Number of generations (default: 10): ", 10)
    visualize = get_boolean_input("Run visualization after completion? (Y/n): ", true)
    
    IO.puts("\nRunning Flatland example with:")
    IO.puts("  - Predator population: #{predator_population}")
    IO.puts("  - Prey population: #{prey_population}")
    IO.puts("  - Generations: #{generations}")
    IO.puts("  - Visualization: #{if visualize, do: "Yes", else: "No"}")
    
    run_flatland_example([
      size: predator_population,  # Use same size for both populations
      generations: generations,
      visualize: visualize
    ])
  end
  
  # Get parameters for FX and run
  defp get_parameters_and_run_fx do
    IO.puts("\n--- FX Trading Configuration ---")
    
    # Get parameters with defaults
    population_size = get_integer_input("Population size (default: 10): ", 10)
    generations = get_integer_input("Number of generations (default: 10): ", 10)
    test_after = get_boolean_input("Run backtesting after completion? (Y/n): ", true)
    
    IO.puts("\nRunning FX Trading example with:")
    IO.puts("  - Population size: #{population_size}")
    IO.puts("  - Generations: #{generations}")
    IO.puts("  - Backtesting: #{if test_after, do: "Yes", else: "No"}")
    
    run_fx_example([
      size: population_size,
      generations: generations,
      visualize: test_after
    ])
  end
  
  # Helper to get integer input with default
  defp get_integer_input(prompt, default) do
    input = IO.gets(prompt) |> String.trim()
    
    if input == "" do
      default
    else
      case Integer.parse(input) do
        {num, _} when num > 0 -> num
        _ -> 
          IO.puts("Invalid input, using default: #{default}")
          default
      end
    end
  end
  
  # Helper to get boolean input with default
  defp get_boolean_input(prompt, default) do
    input = IO.gets(prompt) |> String.trim() |> String.downcase()
    
    case input do
      "" -> default
      "y" -> true
      "yes" -> true
      "n" -> false
      "no" -> false
      _ -> 
        IO.puts("Invalid input, using default: #{if default, do: "Yes", else: "No"}")
        default
    end
  end
  
  # Show help message
  defp show_help do
    IO.puts("""
    
    Usage: mix run_complex_examples [options]
    
    Options:
      --example, -e      The example to run (flatland or fx)
      --generations, -g  Number of generations to evolve
      --size, -s         Population size for the example
      --visualize, -v    Whether to run visualization after completion
    
    Examples:
      mix run_complex_examples
      mix run_complex_examples --example flatland --generations 10
      mix run_complex_examples --example fx --size 20 --no-visualize
    """)
  end
end