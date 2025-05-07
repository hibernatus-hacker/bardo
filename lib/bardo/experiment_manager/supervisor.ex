defmodule Bardo.ExperimentManager.Supervisor do
  @moduledoc """
  Supervisor for the ExperimentManager subsystem.
  """

  use Supervisor
  alias Bardo.ExperimentManager.ExperimentManager

  @doc """
  Starts the supervisor.
  """
  @spec start_link(any()) :: {:ok, pid()}
  def start_link(args) do
    Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  @impl Supervisor
  def init([]) do
    sup_flags = %{
      strategy: :one_for_one,
      intensity: 4,
      period: 20
    }

    experiment_mgr = %{
      id: ExperimentManager,
      start: {ExperimentManager, :start_link, []},
      restart: :permanent,
      shutdown: 5000,
      type: :worker,
      modules: [ExperimentManager]
    }

    children = [experiment_mgr]

    {:ok, {sup_flags, children}}
  end
end