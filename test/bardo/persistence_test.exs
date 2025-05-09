defmodule Bardo.PersistenceTest do
  @moduledoc """
  Tests for the Persistence module.
  
  Note: To run these tests, you need to have all dependencies installed:
  
  ```
  mix deps.get
  ```
  
  The tests require a proper database setup as defined in config/test.exs.
  """
  
  use ExUnit.Case, async: false
  alias Bardo.Persistence
  alias Bardo.Morphology
  
  # Setup test environment with mock data
  setup do
    # Start the DB
    cleanup_fn = Bardo.TestHelper.DBSetup.setup_db()

    # Create temporary directory for tests
    tmp_dir = "test_tmp_#{:rand.uniform(1000)}"
    File.mkdir_p!(tmp_dir)

    # Define a test model
    test_model = %{
      id: "test_#{:rand.uniform(1000)}",
      name: "Test Model",
      data: %{
        value: 42,
        list: [1, 2, 3],
        nested: %{
          key: "value"
        }
      }
    }

    on_exit(fn ->
      # Clean up temporary directory
      File.rm_rf!(tmp_dir)
      # Clean up DB
      cleanup_fn.()
    end)

    %{tmp_dir: tmp_dir, test_model: test_model}
  end
  
  describe "save/4" do
    test "saves a model with explicit ID", %{test_model: model} do
      result = Persistence.save(model, :test, "explicit_id")
      assert result == :ok
      
      # Verify model was saved
      assert Persistence.exists?(:test, "explicit_id")
    end
    
    test "saves a model with extracted ID", %{test_model: model} do
      result = Persistence.save(model, :test)
      assert result == :ok
      
      # Verify model was saved
      assert Persistence.exists?(:test, model.id)
    end
    
    test "fails to save model with no ID" do
      model_without_id = %{name: "No ID", data: %{value: 123}}
      result = Persistence.save(model_without_id, :test)
      assert match?({:error, _}, result)
    end
  end
  
  describe "load/3" do
    test "loads a saved model", %{test_model: model} do
      # First save the model
      :ok = Persistence.save(model, :test)
      
      # Now load it
      result = Persistence.load(:test, model.id)
      assert match?({:ok, _}, result)
      
      {:ok, loaded_model} = result
      assert loaded_model.id == model.id
      assert loaded_model.name == model.name
    end
    
    test "returns error for non-existent model" do
      result = Persistence.load(:test, "nonexistent_id")
      assert match?({:error, _}, result)
    end
  end
  
  describe "exists?/2" do
    test "returns true for existing model", %{test_model: model} do
      # First save the model
      :ok = Persistence.save(model, :test)
      
      # Check it exists
      assert Persistence.exists?(:test, model.id) == true
    end
    
    test "returns false for non-existent model" do
      assert Persistence.exists?(:test, "nonexistent_id") == false
    end
  end
  
  describe "delete/2" do
    test "deletes an existing model", %{test_model: model} do
      # First save the model
      :ok = Persistence.save(model, :test)
      
      # Verify it exists
      assert Persistence.exists?(:test, model.id) == true
      
      # Delete it
      result = Persistence.delete(:test, model.id)
      assert result == :ok
      
      # Verify it no longer exists
      assert Persistence.exists?(:test, model.id) == false
    end
  end
  
  describe "list/1" do
    test "lists models of a given type", %{test_model: model} do
      type = :test_list
      
      # Save some test models
      :ok = Persistence.save(model, type)
      :ok = Persistence.save(%{model | id: "#{model.id}_2"}, type)
      
      # List models
      result = Persistence.list(type)
      assert match?({:ok, _}, result)
      
      {:ok, models} = result
      assert is_list(models)
      assert length(models) >= 2
    end
  end
  
  describe "export/3 and import/2" do
    test "exports and imports a model", %{test_model: model, tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_model.etf")
      
      # Export the model
      result = Persistence.export(model, file_path)
      assert result == :ok
      
      # Verify file exists
      assert File.exists?(file_path)
      
      # Import the model
      import_result = Persistence.import(file_path)
      assert match?({:ok, _}, import_result)
      
      {:ok, imported_model} = import_result
      assert imported_model.id == model.id
      assert imported_model.name == model.name
    end
    
    test "exports and imports a model with compression", %{test_model: model, tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_model_compressed.etf")
      
      # Export the model with compression
      result = Persistence.export(model, file_path, compress: true)
      assert result == :ok
      
      # Verify file exists
      assert File.exists?(file_path)
      
      # Import the model
      import_result = Persistence.import(file_path)
      assert match?({:ok, _}, import_result)
      
      {:ok, imported_model} = import_result
      assert imported_model.id == model.id
      assert imported_model.name == model.name
    end
    
    test "exports and imports in JSON format", %{test_model: model, tmp_dir: tmp_dir} do
      file_path = Path.join(tmp_dir, "test_model.json")
      
      # Export the model in JSON format
      result = Persistence.export(model, file_path, format: :json)
      assert result == :ok
      
      # Verify file exists
      assert File.exists?(file_path)
      
      # Import the model
      import_result = Persistence.import(file_path, format: :json)
      assert match?({:ok, _}, import_result)
    end
  end
  
  describe "backup/1" do
    test "creates a backup", %{tmp_dir: tmp_dir} do
      # Create a backup in the temporary directory
      result = Persistence.backup(tmp_dir)
      assert match?({:ok, _}, result)
      
      {:ok, backup_file} = result
      assert String.starts_with?(backup_file, tmp_dir)
      assert File.exists?(backup_file)
    end
  end
  
  describe "Integration with morphology" do
    test "saves and loads a morphology" do
      # Create a morphology
      morphology = Morphology.new(%{
        name: "Test Morphology",
        dimensions: 3,
        inputs: 5,
        outputs: 2
      })
      
      # Save it
      :ok = Persistence.save(morphology, :morphology)
      
      # Load it
      result = Persistence.load(:morphology, morphology.id)
      assert match?({:ok, _}, result)
      
      {:ok, loaded_morphology} = result
      assert loaded_morphology.id == morphology.id
      assert loaded_morphology.name == morphology.name
      assert loaded_morphology.dimensions == 3
      assert loaded_morphology.inputs == 5
      assert loaded_morphology.outputs == 2
    end
  end
end