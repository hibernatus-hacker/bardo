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
    children = [
      # Database supervisor
      {Bardo.DB, []},
      # Polis supervisor
      {Bardo.Polis.Supervisor, []},
      # Polis manager
      {Bardo.Polis.Manager, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_all, name: Bardo.Supervisor]
    Supervisor.start_link(children, opts)
  end
end