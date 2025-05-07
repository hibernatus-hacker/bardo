defmodule Bardo.Schemas.Result do
  @moduledoc """
  Schema for Experiment Results in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}
  schema "results" do
    field :data, :map
    field :result_type, :string
    
    belongs_to :experiment, Bardo.Schemas.Experiment, type: :string
    
    timestamps()
  end

  @required_fields ~w(id experiment_id data)a
  @optional_fields ~w(result_type)a

  def changeset(result, attrs) do
    result
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:experiment_id)
  end

  def for_experiment(query \\ __MODULE__, experiment_id) do
    from q in query, where: q.experiment_id == ^experiment_id
  end
  
  def by_type(query \\ __MODULE__, result_type) do
    from q in query, where: q.result_type == ^result_type
  end
  
  def latest(query \\ __MODULE__, experiment_id) do
    from q in query,
      where: q.experiment_id == ^experiment_id,
      order_by: [desc: q.inserted_at],
      limit: 1
  end
end