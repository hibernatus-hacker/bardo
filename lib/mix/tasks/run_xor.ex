defmodule Mix.Tasks.RunXor do
  use Mix.Task

  @shortdoc "Runs the XOR example"
  @moduledoc """
  Runs the Bardo XOR example with configurable parameters.

  ## Usage

      mix run_xor [--size SIZE] [--generations GEN] [--quiet]

  Options:
    --size SIZE:        Population size (default: 20)
    --generations GEN:  Maximum generations (default: 10)
    --quiet:            Don't show progress during evolution
  """

  @impl Mix.Task
  def run(args) do
    # Parse arguments
    {opts, _, _} = OptionParser.parse(args, 
      strict: [
        size: :integer, 
        generations: :integer,
        quiet: :boolean
      ]
    )
    
    population_size = Keyword.get(opts, :size, 20)
    max_generations = Keyword.get(opts, :generations, 10)
    show_progress = not Keyword.get(opts, :quiet, false)

    IO.puts("\n=========================================")
    IO.puts("BARDO XOR EXAMPLE RUNNER")
    IO.puts("=========================================\n")

    # Ensure application is started
    Mix.Task.run("app.start")

    IO.puts("Running XOR example with:")
    IO.puts("  Population size: #{population_size}")
    IO.puts("  Max generations: #{max_generations}")
    IO.puts("  Show progress: #{show_progress}")
    IO.puts("")

    start_time = System.monotonic_time(:millisecond)

    result = try do
      Bardo.Examples.Simple.Xor.run(
        population_size: population_size,
        max_generations: max_generations,
        show_progress: show_progress
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

    # Make sure process doesn't end too quickly
    :timer.sleep(1000)
  end
end