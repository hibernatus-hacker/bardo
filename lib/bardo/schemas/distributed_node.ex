defmodule Bardo.Schemas.DistributedNode do
  @moduledoc """
  Schema for Distributed Nodes in Bardo.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:node_name, :string, autogenerate: false}
  schema "distributed_nodes" do
    field :info, :map
    field :status, :string, default: "online"
    field :last_heartbeat, :utc_datetime
    
    has_many :jobs, Bardo.Schemas.DistributedJob, foreign_key: :assigned_node_name
    
    timestamps()
  end

  @required_fields ~w(node_name info)a
  @optional_fields ~w(status last_heartbeat)a

  def changeset(node, attrs) do
    node
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> put_change(:last_heartbeat, DateTime.truncate(DateTime.utc_now(), :second))
  end

  def online(query \\ __MODULE__) do
    from q in query, where: q.status == "online"
  end
  
  def stale(query \\ __MODULE__, stale_after_seconds) do
    cutoff_time = DateTime.add(DateTime.utc_now(), -stale_after_seconds, :second)
    cutoff_time = DateTime.truncate(cutoff_time, :second)
    
    from q in query,
      where: q.last_heartbeat < ^cutoff_time
  end
  
  def with_capacity(query \\ __MODULE__) do
    from q in query,
      where: q.status in ["online", "idle"],
      order_by: [asc: q.last_heartbeat]
  end
end