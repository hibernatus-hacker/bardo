defmodule Mix.Tasks.RunExamplesRefactored do
  use Mix.Task

  @shortdoc "Runs Bardo examples with improved organization"
  @moduledoc """
  Runs Bardo examples and benchmarks with an improved organization structure.

  ## Usage

      mix run_examples_refactored [options]

  Options:
    --category CATEGORY  Run examples from a specific category (simple, benchmarks, applications)
    --example NAME       Run a specific example by name (xor, dpb, flatland, fx, algo_trading)
    --quick              Run with smaller parameters for quick testing
    --verbose            Show detailed output during execution
  """

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _, _} = OptionParser.parse(args, 
      strict: [
        category: :string,
        example: :string, 
        quick: :boolean,
        verbose: :boolean
      ]
    )
    
    category = Keyword.get(opts, :category)
    example = Keyword.get(opts, :example)
    quick = Keyword.get(opts, :quick, false)
    verbose = Keyword.get(opts, :verbose, false)

    IO.puts("\n=========================================")
    IO.puts("BARDO EXAMPLES RUNNER (REFACTORED)")
    IO.puts("=========================================\n")

    # Ensure application is started
    Mix.Task.run("app.start")

    # Run examples based on filters
    run_filtered_examples(category, example, quick, verbose)
  end

  defp run_filtered_examples(category, example, quick, verbose) do
    # Get available examples
    examples = get_examples(quick)
    
    # Filter by category if specified
    examples = if category do
      Enum.filter(examples, fn ex -> ex.category == String.to_atom(category) end)
    else
      examples
    end
    
    # Filter by name if specified
    examples = if example do
      Enum.filter(examples, fn ex -> 
        ex.name |> String.downcase() |> String.contains?(String.downcase(example))
      end)
    else
      examples
    end

    # Check if any examples match filters
    if Enum.empty?(examples) do
      IO.puts("⚠️ No examples match the specified filters.")
      IO.puts("Available categories: simple, benchmarks, applications")
      
      all_examples = get_examples(quick)
      available_names = all_examples |> Enum.map(&(&1.name)) |> Enum.join(", ")
      IO.puts("Available examples: #{available_names}")
      
      {:no_examples, []}
    else
      # Run the examples
      results = %{}
      executed = []

      {results, _} = Enum.reduce(examples, {results, executed}, fn example, {acc_results, acc_executed} ->
        run_example(example, acc_results, acc_executed, verbose)
      end)

      # Print summary
      print_summary(results, examples)
    end
  end

  defp get_examples(quick) do
    # Quick mode uses smaller parameters for faster execution
    params = if quick do
      %{
        population_size_small: 20,
        population_size_medium: 30,
        population_size_large: 40,
        generations_few: 5,
        generations_medium: 10,
        generations_many: 15,
        time_short: 10,
        time_medium: 50,
        iterations_few: 3,
        iterations_medium: 5
      }
    else
      %{
        population_size_small: 40,
        population_size_medium: 60,
        population_size_large: 100,
        generations_few: 30,
        generations_medium: 50,
        generations_many: 100,
        time_short: 100,
        time_medium: 500,
        iterations_few: 5,
        iterations_medium: 10
      }
    end

    # Define all examples with consistent structure
    [
      # Simple examples
      %{
        category: :simple,
        name: "XOR Example",
        module: Bardo.Examples.Simple.Xor,
        function: :run,
        args: [[
          population_size: params.population_size_small, 
          max_generations: params.generations_few, 
          show_progress: true
        ]],
        description: "Neural network learning XOR logic function"
      },
      
      # Benchmark examples
      %{
        category: :benchmarks,
        name: "Double Pole Balancing (with damping)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :run_with_damping,
        args: [:dpb_test, params.iterations_few, params.iterations_few, params.time_medium],
        description: "Balance two poles on a cart with friction"
      },
      %{
        category: :benchmarks,
        name: "Double Pole Balancing (test best solution)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :test_best_solution,
        args: [:dpb_test],
        depends_on: "Double Pole Balancing (with damping)",
        description: "Test the best solution from the DPB experiment"
      },
      %{
        category: :benchmarks,
        name: "Double Pole Balancing (without damping)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :run_without_damping,
        args: [:dpb_wo_test, params.iterations_few, params.iterations_few, params.time_medium],
        description: "Balance two poles on a cart without friction (harder)"
      },
      
      # Application examples
      %{
        category: :applications,
        name: "Flatland Predator-Prey Simulation",
        module: Bardo.Examples.Applications.Flatland,
        function: :run,
        args: [:flatland_test, params.iterations_few, params.iterations_few, 
               params.iterations_medium, params.time_short, params.iterations_few],
        description: "Evolve predator and prey agents in a 2D environment"
      },
      %{
        category: :applications,
        name: "Forex (FX) Trading",
        module: Bardo.Examples.Applications.Fx,
        function: :run,
        args: [:fx_test, params.iterations_few, params.time_short, params.iterations_few],
        description: "Evolve trading strategies for forex markets"
      },
      %{
        category: :applications,
        name: "Forex (FX) Best Agent Test",
        module: Bardo.Examples.Applications.Fx,
        function: :test_best_agent,
        args: [:fx_test],
        depends_on: "Forex (FX) Trading",
        description: "Test the best trading agent on historical data"
      }
    ]
  end

  defp run_example(example, results, executed, verbose) do
    # Check dependencies
    if Map.has_key?(example, :depends_on) && example.depends_on not in executed do
      IO.puts("⚠️ Skipping #{example.name} because dependency #{example.depends_on} was not executed")
      {Map.put(results, example.name, {:error, :dependency_not_executed}), executed}
    else
      if Map.has_key?(example, :depends_on) && results[example.depends_on] == {:error, :dependency_failed} do
        IO.puts("⚠️ Skipping #{example.name} because dependency #{example.depends_on} failed")
        {Map.put(results, example.name, {:error, :dependency_failed}), executed}
      else
        # Print header with improved formatting
        IO.puts("\n#{String.duplicate("=", 60)}")
        IO.puts("RUNNING: #{example.name}")
        IO.puts("CATEGORY: #{example.category}")
        IO.puts("DESCRIPTION: #{example.description}")
        IO.puts("#{String.duplicate("=", 60)}")

        # Print more details in verbose mode
        if verbose do
          IO.puts("Module: #{example.module}")
          IO.puts("Function: #{example.function}")
          IO.puts("Arguments: #{inspect(example.args)}")
          IO.puts("#{String.duplicate("-", 60)}")
        end

        start_time = System.monotonic_time(:millisecond)

        result = try do
          # Verify module exists
          if module_exists?(example.module, example.function, length(example.args)) do
            apply(example.module, example.function, example.args)
          else
            {:error, :module_not_found}
          end
        rescue
          error ->
            IO.puts("\n❌ ERROR in #{example.name}:")
            IO.puts("  #{inspect(error)}")
            IO.puts("\nStacktrace:")
            __STACKTRACE__ |> Enum.take(5) |> Enum.each(fn line ->
              IO.puts("  #{inspect(line)}")
            end)
            {:error, error}
        end

        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        # Print result
        case result do
          :ok ->
            IO.puts("\n✅ #{example.name} completed successfully in #{duration}ms")
          {:ok, _} ->
            IO.puts("\n✅ #{example.name} completed successfully in #{duration}ms")
          {:error, :module_not_found} ->
            IO.puts("\n⚠️ #{example.name} could not run because the module is not available")
          {:error, _} ->
            IO.puts("\n❌ #{example.name} failed after #{duration}ms")
          _ ->
            IO.puts("\n✅ #{example.name} completed with result in #{duration}ms")
            if verbose do
              IO.inspect(result, label: "Result")
            end
        end

        IO.puts("\nWaiting 2 seconds before next example...")
        :timer.sleep(2000)

        {Map.put(results, example.name, result), [example.name | executed]}
      end
    end
  end

  defp module_exists?(module, function, arity) do
    try do
      # Check if module is available
      module.__info__(:functions)
      |> Keyword.get(function) == arity
    rescue
      UndefinedFunctionError ->
        false
    end
  end

  defp print_summary(results, available_examples) do
    IO.puts("\n#{String.duplicate("=", 60)}")
    IO.puts("EXAMPLES SUMMARY")
    IO.puts("#{String.duplicate("=", 60)}")

    successful = Enum.count(results, fn {_, result} -> 
      case result do
        :ok -> true
        {:ok, _} -> true
        _ -> not match?({:error, _}, result)
      end
    end)

    total_run = map_size(results)
    IO.puts("Available examples: #{length(available_examples)}")
    IO.puts("Executed examples: #{total_run}")
    IO.puts("Successful: #{successful}")
    IO.puts("Failed: #{total_run - successful}")

    # Print detailed results by category
    if total_run > 0 do
      # Group by category
      by_category = Enum.reduce(available_examples, %{}, fn example, acc ->
        if Map.has_key?(results, example.name) do
          category = example.category
          Map.update(acc, category, [example], fn examples -> [example | examples] end)
        else
          acc
        end
      end)

      # Print results by category
      Enum.each(by_category, fn {category, examples} ->
        IO.puts("\n#{String.upcase(to_string(category))} EXAMPLES:")
        
        # Count successful in this category
        category_successful = Enum.count(examples, fn example -> 
          case results[example.name] do
            :ok -> true
            {:ok, _} -> true
            _ -> not match?({:error, _}, results[example.name])
          end
        end)
        
        IO.puts("Ran: #{length(examples)}, Successful: #{category_successful}")
        
        # Print each example result
        Enum.each(examples, fn example ->
          result = results[example.name]
          case result do
            :ok -> 
              IO.puts("  ✅ #{example.name}")
            {:ok, _} -> 
              IO.puts("  ✅ #{example.name}")
            {:error, reason} -> 
              IO.puts("  ❌ #{example.name}: #{inspect(reason)}")
            _ -> 
              if match?({:error, _}, result) do
                IO.puts("  ❌ #{example.name}")
              else
                IO.puts("  ✅ #{example.name}")
              end
          end
        end)
      end)
    else
      IO.puts("\n⚠️ No examples were executed")
    end

    if successful == total_run and total_run > 0 do
      IO.puts("\n🎉 All executed examples ran successfully!")
    end
  end
end