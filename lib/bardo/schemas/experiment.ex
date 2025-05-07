defmodule Bardo.Schemas.Experiment do
  @moduledoc """
  Schema for Experiments in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}
  schema "experiments" do
    field :name, :string
    field :description, :string
    field :config, :map
    field :status, :string, default: "pending"
    
    has_many :populations, Bardo.Schemas.Population
    has_many :results, Bardo.Schemas.Result
    
    timestamps()
  end

  @required_fields ~w(id name)a
  @optional_fields ~w(description config status)a

  def changeset(experiment, attrs) do
    experiment
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  def by_status(query \\ __MODULE__, status) do
    from q in query, where: q.status == ^status
  end
  
  def active(query \\ __MODULE__) do
    from q in query, 
      where: q.status in ["pending", "running", "paused"]
  end
end