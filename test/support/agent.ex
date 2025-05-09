defmodule :agent do
  @moduledoc """
  A replacement for the Erlang :agent module used in tests.

  This module uses Elixir's built-in Agent module to provide compatible
  functionality for the test suite, particularly in network_test.exs.
  """

  @doc """
  Starts a new agent with the given initial state.

  Returns the process id of the agent.
  """
  @spec start_link((() -> term())) :: pid()
  def start_link(fun) when is_function(fun, 0) do
    # Create initial state by calling the provided function
    initial_state = fun.()

    # Start a new Elixir Agent to manage the state
    {:ok, pid} = Agent.start_link(fn -> initial_state end)

    # Return just the pid instead of the tuple
    pid
  end

  @doc """
  Updates the agent's state using the provided function.

  The function receives the current state and returns the new state.
  """
  @spec update(pid(), ((term()) -> term())) :: :ok
  def update(pid, fun) when is_pid(pid) and is_function(fun, 1) do
    Agent.update(pid, fun)
  end

  @doc """
  Gets a value from the agent's state using the provided function.

  The function receives the current state and returns a derived value.
  """
  @spec get(pid(), ((term()) -> term())) :: term()
  def get(pid, fun) when is_pid(pid) and is_function(fun, 1) do
    Agent.get(pid, fun)
  end
end