defmodule Bardo.Schemas.Population do
  @moduledoc """
  Schema for Populations in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}
  schema "populations" do
    field :name, :string
    field :generation, :integer, default: 0
    field :config, :map
    field :status, :string, default: "pending"
    
    belongs_to :experiment, Bardo.Schemas.Experiment, type: :string
    has_many :genotypes, Bardo.Schemas.Genotype
    
    timestamps()
  end

  @required_fields ~w(id experiment_id)a
  @optional_fields ~w(name generation config status)a

  def changeset(population, attrs) do
    population
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:experiment_id)
  end

  def for_experiment(query \\ __MODULE__, experiment_id) do
    from q in query, where: q.experiment_id == ^experiment_id
  end
  
  def by_status(query \\ __MODULE__, status) do
    from q in query, where: q.status == ^status
  end
  
  def latest_generation(query \\ __MODULE__, experiment_id) do
    from q in query,
      where: q.experiment_id == ^experiment_id,
      order_by: [desc: q.generation],
      limit: 1
  end
end