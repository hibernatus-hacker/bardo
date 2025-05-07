defmodule Bardo.Schemas.Genotype do
  @moduledoc """
  Schema for Genotypes in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}
  schema "genotypes" do
    field :data, :map
    field :fitness, :float
    field :fitness_details, :map
    field :metadata, :map
    
    belongs_to :population, Bardo.Schemas.Population, type: :string
    
    timestamps()
  end

  @required_fields ~w(id population_id data)a
  @optional_fields ~w(fitness fitness_details metadata)a

  def changeset(genotype, attrs) do
    genotype
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:population_id)
  end

  def for_population(query \\ __MODULE__, population_id) do
    from q in query, where: q.population_id == ^population_id
  end
  
  def best_fitness(query \\ __MODULE__, population_id) do
    from q in query,
      where: q.population_id == ^population_id,
      order_by: [desc: q.fitness],
      limit: 1
  end
end