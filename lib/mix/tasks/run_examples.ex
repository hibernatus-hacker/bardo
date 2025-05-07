defmodule Mix.Tasks.RunExamples do
  use Mix.Task

  @shortdoc "Runs Bardo examples and benchmarks"
  @moduledoc """
  Runs Bardo examples and benchmarks with small parameters for testing.

  ## Usage

      mix run_examples [--xor-only]

  Options:
    --xor-only: Run only the XOR example
  """

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _, _} = OptionParser.parse(args, strict: [xor_only: :boolean])
    xor_only = Keyword.get(opts, :xor_only, false)

    IO.puts("\n=========================================")
    IO.puts("BARDO EXAMPLES AND BENCHMARKS RUNNER")
    IO.puts("=========================================\n")

    # Ensure application is started
    Mix.Task.run("app.start")

    if xor_only do
      run_xor_example()
    else
      run_all_examples()
    end

    # Make sure process doesn't end too quickly
    :timer.sleep(1000)
  end

  defp run_xor_example do
    IO.puts("\n#{String.duplicate("=", 60)}")
    IO.puts("RUNNING: XOR Example")
    IO.puts("#{String.duplicate("=", 60)}")

    start_time = System.monotonic_time(:millisecond)

    result = try do
      Bardo.Examples.Simple.Xor.run(
        population_size: 20,
        max_generations: 10,
        show_progress: true
      )
    rescue
      error ->
        IO.puts("\n❌ ERROR in XOR Example:")
        IO.puts("  #{inspect(error)}")
        IO.puts("\nStacktrace:")
        __STACKTRACE__ |> Enum.take(5) |> Enum.each(fn line ->
          IO.puts("  #{inspect(line)}")
        end)
        {:error, error}
    end

    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    case result do
      {:error, _} ->
        IO.puts("\n❌ XOR Example failed after #{duration}ms")
      _ ->
        IO.puts("\n✅ XOR Example completed successfully in #{duration}ms")
        IO.puts("Neural network structure:")
        IO.inspect(result, limit: 5)
    end
  end

  defp run_all_examples do
    # Helper functions for the runner
    examples = [
      %{
        name: "XOR Example",
        module: Bardo.Examples.Simple.Xor,
        function: :run,
        args: [[population_size: 10, max_generations: 5, show_progress: true]]
      },
      %{
        name: "Double Pole Balancing (with damping)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :run_with_damping,
        args: [:dpb_test, 5, 3, 1000]
      },
      %{
        name: "Double Pole Balancing (test best solution)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :test_best_solution,
        args: [:dpb_test],
        depends_on: "Double Pole Balancing (with damping)"
      },
      %{
        name: "Double Pole Balancing (without damping)",
        module: Bardo.Examples.Benchmarks.Dpb,
        function: :run_without_damping,
        args: [:dpb_wo_test, 5, 3, 1000]
      },
      %{
        name: "Flatland Predator-Prey Simulation",
        module: Bardo.Examples.Applications.Flatland,
        function: :run,
        args: [:flatland_test, 5, 5, 10, 100, 3]
      },
      %{
        name: "Forex (FX) Trading",
        module: Bardo.Examples.Applications.Fx,
        function: :run,
        args: [:fx_test, 5, 500, 3]
      },
      %{
        name: "Forex (FX) Best Agent Test",
        module: Bardo.Examples.Applications.Fx,
        function: :test_best_agent,
        args: [:fx_test],
        depends_on: "Forex (FX) Trading"
      }
    ]

    # Check which examples are available
    IO.puts("Checking for available examples...")
    available_examples = Enum.filter(examples, fn example ->
      module_exists?(example.module, example.function, length(example.args))
    end)

    if Enum.empty?(available_examples) do
      IO.puts("\n⚠️ No examples are available to run.")
      # Return early by using a custom value to indicate no examples
      {:no_examples, []}
    else

    # Run examples with dependency handling
    results = %{}
    executed = []

    {results, _} = Enum.reduce(available_examples, {results, executed}, fn example, {acc_results, acc_executed} ->
      run_example(example, acc_results, acc_executed)
    end)

    # Print summary
    print_summary(results, examples, available_examples)
    end
  end

  defp run_example(example, results, executed) do
    if Map.has_key?(example, :depends_on) && example.depends_on not in executed do
      IO.puts("⚠️ Skipping #{example.name} because dependency #{example.depends_on} was not executed")
      {Map.put(results, example.name, {:error, :dependency_not_executed}), executed}
    else
      if Map.has_key?(example, :depends_on) && results[example.depends_on] == {:error, :dependency_failed} do
        IO.puts("⚠️ Skipping #{example.name} because dependency #{example.depends_on} failed")
        {Map.put(results, example.name, {:error, :dependency_failed}), executed}
      else
        IO.puts("\n#{String.duplicate("=", 60)}")
        IO.puts("RUNNING: #{example.name}")
        IO.puts("#{String.duplicate("=", 60)}")

        start_time = System.monotonic_time(:millisecond)

        result = try do
          apply(example.module, example.function, example.args)
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

        case result do
          :ok ->
            IO.puts("\n✅ #{example.name} completed successfully in #{duration}ms")
          {:ok, _} ->
            IO.puts("\n✅ #{example.name} completed successfully in #{duration}ms")
          {:error, _} ->
            IO.puts("\n❌ #{example.name} failed after #{duration}ms")
          _ ->
            IO.puts("\n✅ #{example.name} completed with result: #{inspect(result)} in #{duration}ms")
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
        IO.puts("❌ Module #{module} is not available or function #{function}/#{arity} doesn't exist")
        false
    end
  end

  defp print_summary(results, all_examples, available_examples) do
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
    IO.puts("Total examples: #{length(all_examples)}")
    IO.puts("Available examples: #{length(available_examples)}")
    IO.puts("Executed examples: #{total_run}")
    IO.puts("Successful: #{successful}")
    IO.puts("Failed: #{total_run - successful}")

    # Print detailed results
    if total_run > 0 do
      # Print successful examples
      successful_examples = Enum.filter(results, fn {_, result} -> 
        case result do
          :ok -> true
          {:ok, _} -> true
          _ -> not match?({:error, _}, result)
        end
      end)
      
      if length(successful_examples) > 0 do
        IO.puts("\nSUCCESSFUL EXAMPLES:")
        Enum.each(successful_examples, fn {name, _} ->
          IO.puts("  ✅ #{name}")
        end)
      end
      
      # Print failed examples
      failed_examples = Enum.filter(results, fn {_, result} -> match?({:error, _}, result) end)
      
      if length(failed_examples) > 0 do
        IO.puts("\nFAILED EXAMPLES:")
        Enum.each(failed_examples, fn {name, {:error, error}} ->
          IO.puts("  ❌ #{name}: #{inspect(error)}")
        end)
        IO.puts("\nSee detailed error messages above for troubleshooting.")
      end
    else
      IO.puts("\n⚠️ No examples were executed")
    end

    if successful == total_run and total_run > 0 do
      IO.puts("\n🎉 All executed examples ran successfully!")
    end
  end
end