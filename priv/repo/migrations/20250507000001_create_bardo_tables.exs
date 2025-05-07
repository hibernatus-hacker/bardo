defmodule Bardo.Repo.Migrations.CreateBardoTables do
  use Ecto.Migration

  def change do
    # Experiments table
    create table(:experiments, primary_key: false) do
      add :id, :string, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :config, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      
      timestamps()
    end
    
    create index(:experiments, [:status])
    
    # Populations table
    create table(:populations, primary_key: false) do
      add :id, :string, primary_key: true
      add :experiment_id, references(:experiments, type: :string, on_delete: :delete_all), null: false
      add :name, :string
      add :generation, :integer, null: false, default: 0
      add :config, :map
      add :status, :string, null: false, default: "pending"
      
      timestamps()
    end
    
    create index(:populations, [:experiment_id])
    create index(:populations, [:status])
    
    # Genotypes table
    create table(:genotypes, primary_key: false) do
      add :id, :string, primary_key: true
      add :population_id, references(:populations, type: :string, on_delete: :delete_all), null: false
      add :data, :map, null: false
      add :fitness, :float
      add :fitness_details, :map
      add :metadata, :map
      
      timestamps()
    end
    
    create index(:genotypes, [:population_id])
    create index(:genotypes, [:fitness])
    
    # Results table
    create table(:results, primary_key: false) do
      add :id, :string, primary_key: true
      add :experiment_id, references(:experiments, type: :string, on_delete: :delete_all), null: false
      add :data, :map, null: false
      add :result_type, :string
      
      timestamps()
    end
    
    create index(:results, [:experiment_id])
    create index(:results, [:result_type])
    
    # Distributed nodes table
    create table(:distributed_nodes, primary_key: false) do
      add :node_name, :string, primary_key: true
      add :info, :map, null: false
      add :status, :string, null: false, default: "online"
      add :last_heartbeat, :utc_datetime, null: false
      
      timestamps()
    end
    
    create index(:distributed_nodes, [:status])
    create index(:distributed_nodes, [:last_heartbeat])
    
    # Distributed jobs table
    create table(:distributed_jobs, primary_key: false) do
      add :id, :string, primary_key: true
      add :config, :map, null: false
      add :status, :string, null: false, default: "pending"
      add :results, :map
      add :assigned_node_name, references(:distributed_nodes, column: :node_name, type: :string, on_delete: :nilify_all)
      
      timestamps()
    end
    
    create index(:distributed_jobs, [:status])
    create index(:distributed_jobs, [:assigned_node_name])
  end
end