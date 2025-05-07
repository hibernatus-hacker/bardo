defmodule Bardo.Schemas.DistributedJob do
  @moduledoc """
  Schema for Distributed Jobs in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :string, autogenerate: false}
  schema "distributed_jobs" do
    field :config, :map
    field :status, :string, default: "pending"
    field :results, :map
    
    belongs_to :assigned_node, Bardo.Schemas.DistributedNode, 
      foreign_key: :assigned_node_name, 
      type: :string, 
      references: :node_name
    
    timestamps()
  end

  @required_fields ~w(id config)a
  @optional_fields ~w(status results assigned_node_name)a

  def changeset(job, attrs) do
    job
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:assigned_node_name)
  end

  def pending(query \\ __MODULE__) do
    from q in query, where: q.status == "pending"
  end
  
  def running(query \\ __MODULE__) do
    from q in query, where: q.status == "running"
  end
  
  def completed(query \\ __MODULE__) do
    from q in query, where: q.status == "completed"
  end
  
  def failed(query \\ __MODULE__) do
    from q in query, where: q.status == "failed"
  end
  
  def for_node(query \\ __MODULE__, node_name) do
    from q in query, where: q.assigned_node_name == ^node_name
  end
  
  def stalled(query \\ __MODULE__, stalled_after_seconds) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -stalled_after_seconds, :second)
    cutoff_time = DateTime.truncate(cutoff_time, :second)
    
    from q in query,
      where: q.status == "running" and q.updated_at < ^cutoff_time
  end
end