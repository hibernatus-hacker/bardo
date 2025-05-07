defmodule Bardo.Application do
  @moduledoc """
  Bardo top level application.
  
  Bardo is a distributed topology and weight evolving artificial neural network
  originally created by Gene Sher. This is an Elixir port of the original Erlang DXNN system.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Check if we should start the application or not (for tests)
    if Application.get_env(:bardo, :start_application, true) do
      # Determine if we should use PostgreSQL or the default ETS database
      use_postgres? = Application.get_env(:bardo, :db)[:adapter] == Bardo.DBPostgres
      
      children = if use_postgres? do
        [
          # Ecto repository for PostgreSQL
          Bardo.Repo,
          # PostgreSQL database adapter
          {Bardo.DBPostgres, []},
          # Polis supervisor
          {Bardo.Polis.Supervisor, []},
          # Polis manager
          {Bardo.Polis.Manager, []}
        ]
      else
        [
          # Default ETS database supervisor
          {Bardo.DB, []},
          # Polis supervisor
          {Bardo.Polis.Supervisor, []},
          # Polis manager
          {Bardo.Polis.Manager, []}
        ]
      end

      # See https://hexdocs.pm/elixir/Supervisor.html
      # for other strategies and supported options
      opts = [strategy: :one_for_one, name: Bardo.Supervisor]
      result = Supervisor.start_link(children, opts)
      
      if use_postgres? do
        Logger.info("Bardo started with PostgreSQL database adapter")
      else
        Logger.info("Bardo started with ETS database adapter")
      end
      
      result
    else
      # For tests, we'll just return a dummy supervisor
      {:ok, pid} = Agent.start_link(fn -> %{} end, name: Bardo.DummySupervisor)
      {:ok, pid}
    end
  end
end