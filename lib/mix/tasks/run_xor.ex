defmodule Mix.Tasks.RunXor do
  use Mix.Task

  @shortdoc "Runs the XOR example"
  @moduledoc """
  Runs the Bardo XOR example with configurable parameters.

  ## Usage

      mix run_xor [--size SIZE] [--generations GEN] [--runs RUNS] [--quiet]

  Options:
    --size SIZE, -s:        Population size (default: 40)
    --generations GEN, -g:  Maximum generations (default: 30)
    --runs RUNS, -r:        Number of runs to perform (default: 1)
    --quiet, -q:            Don't show progress during evolution
  """

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _, _} = OptionParser.parse(args,
      strict: [
        size: :integer,
        generations: :integer,
        runs: :integer,
        quiet: :boolean
      ],
      aliases: [s: :size, g: :generations, r: :runs, q: :quiet]
    )

    population_size = Keyword.get(opts, :size, 40)  # Increased from 20
    max_generations = Keyword.get(opts, :generations, 30) # Increased from 10
    runs = Keyword.get(opts, :runs, 1)
    show_progress = not Keyword.get(opts, :quiet, false)

    IO.puts("\n=========================================")
    IO.puts("BARDO XOR EXAMPLE RUNNER")
    IO.puts("=========================================\n")

    # Ensure application is started
    Mix.Task.run("app.start")

    IO.puts("Running XOR example with:")
    IO.puts("  Population size: #{population_size}")
    IO.puts("  Max generations: #{max_generations}")
    IO.puts("  Number of runs: #{runs}")
    IO.puts("  Show progress: #{show_progress}")
    IO.puts("")

    # Run multiple attempts to find the best solution
    results = for run <- 1..runs do
      # Random seed to ensure different outcomes
      :rand.seed(:exsplus, {System.system_time(:millisecond), run, :os.system_time()})

      start_time = System.monotonic_time(:millisecond)

      result = try do
        nn = Bardo.Examples.Simple.Xor.run(
          population_size: population_size,
          max_generations: max_generations,
          show_progress: show_progress && (runs == 1)
        )

        # Calculate success metrics
        test_cases = [
          {[0.0, 0.0], [0.0]},
          {[0.0, 1.0], [1.0]},
          {[1.0, 0.0], [1.0]},
          {[1.0, 1.0], [0.0]}
        ]

        errors = Enum.map(test_cases, fn {inputs, expected} ->
          outputs = Bardo.AgentManager.Cortex.activate(nn, inputs)
          Enum.zip(outputs, expected)
          |> Enum.map(fn {o, e} -> abs(o - e) end)
          |> Enum.sum()
        end)

        avg_error = Enum.sum(errors) / length(errors)

        {nn, avg_error}
      rescue
        error ->
          if runs == 1 do
            IO.puts("\n❌ ERROR in XOR Example:")
            IO.puts("  #{inspect(error)}")
            IO.puts("\nStacktrace:")
            __STACKTRACE__ |> Enum.take(5) |> Enum.each(fn line ->
              IO.puts("  #{inspect(line)}")
            end)
          end
          {:error, error}
      end

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      case result do
        {:error, _} ->
          if runs > 1 do
            IO.puts("Run #{run}/#{runs}: Failed in #{duration}ms ❌")
          end
          %{network: nil, time: duration, error: 999.0, success: false}

        {nn, avg_error} ->
          success = avg_error < 0.3
          if runs > 1 do
            IO.puts("Run #{run}/#{runs}: Average error #{Float.round(avg_error, 3)} in #{duration}ms #{if success, do: "✅", else: "❌"}")
          end
          %{network: nn, time: duration, error: avg_error, success: success}
      end
    end

    # Select best result (that didn't fail)
    valid_results = Enum.filter(results, fn r -> r.network != nil end)

    if Enum.empty?(valid_results) do
      IO.puts("\n❌ All XOR Example runs failed")
    else
      best_result = Enum.min_by(valid_results, fn r -> r.error end)
      success_rate = Enum.count(valid_results, fn r -> r.success end) / length(valid_results) * 100

      # Print summary
      if runs > 1 do
        IO.puts("\nSummary:")
        IO.puts("  Valid runs: #{length(valid_results)}/#{runs}")
        IO.puts("  Success rate: #{Float.round(success_rate, 1)}%")
        IO.puts("  Best error: #{Float.round(best_result.error, 4)}")
        IO.puts("  Average time: #{Float.round(Enum.sum(Enum.map(valid_results, & &1.time)) / length(valid_results))}ms")
      end

      IO.puts("\n✅ XOR Example completed successfully in #{best_result.time}ms")
      IO.puts("Neural network structure:")
      IO.inspect(best_result.network, limit: 5)
    end

    # Make sure process doesn't end too quickly
    :timer.sleep(1000)
  end
end