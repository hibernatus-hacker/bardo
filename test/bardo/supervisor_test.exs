defmodule Bardo.SupervisorTest do
  @moduledoc """
  Tests for the supervision tree structure.
  
  Note: To run these tests, you need to have all dependencies installed:
  
  ```
  mix deps.get
  ```
  
  The tests require a proper application environment as defined in config/test.exs.
  """
  
  use ExUnit.Case, async: false
  
  describe "Bardo.Polis.Supervisor" do
    test "initializes with appropriate child specs" do
      # Get the supervisor's child specs
      {:ok, child_specs} = get_child_specs(Bardo.Polis.Supervisor)
      
      # We should have 4 children
      assert length(child_specs) == 4
      
      # Verify each child module
      child_modules = extract_modules(child_specs)
      assert Bardo.ScapeManager.Supervisor in child_modules
      assert Bardo.AgentManager.Supervisor in child_modules
      assert Bardo.PopulationManager.Supervisor in child_modules
      assert Bardo.ExperimentManager.Supervisor in child_modules
      
      # Verify the strategy
      assert get_strategy(Bardo.Polis.Supervisor) == :one_for_one
    end
  end
  
  describe "Bardo.AgentManager.Supervisor" do
    test "initializes with appropriate child specs" do
      # Get the supervisor's child specs
      {:ok, child_specs} = get_child_specs(Bardo.AgentManager.Supervisor)
      
      # We should have 2 children
      assert length(child_specs) == 2
      
      # Verify each child type
      child_modules = extract_modules(child_specs)
      assert DynamicSupervisor in child_modules
      assert Bardo.AgentManager in child_modules
      
      # Verify the strategy
      assert get_strategy(Bardo.AgentManager.Supervisor) == :one_for_one
    end
    
    test "starts with AgentWorkerSupervisor properly configured" do
      # Get the DynamicSupervisor child spec
      {:ok, child_specs} = get_child_specs(Bardo.AgentManager.Supervisor)
      dynamic_sup_spec = Enum.find(child_specs, fn spec ->
        case spec do
          %{start: {DynamicSupervisor, _, _}} -> true
          _ -> false
        end
      end)
      
      # Extract the arguments
      {_, _, [args]} = dynamic_sup_spec.start
      
      # Verify the name and strategy
      assert Keyword.get(args, :name) == Bardo.AgentManager.AgentWorkerSupervisor
      assert Keyword.get(args, :strategy) == :one_for_one
    end
  end
  
  describe "Bardo.PopulationManager.Supervisor" do
    test "initializes with appropriate child specs" do
      # Get the supervisor's child specs
      {:ok, child_specs} = get_child_specs(Bardo.PopulationManager.Supervisor)
      
      # We should have 2 children
      assert length(child_specs) == 2
      
      # Verify each child type
      child_modules = extract_modules(child_specs)
      assert DynamicSupervisor in child_modules
      assert Bardo.PopulationManager.PopulationManager in child_modules
      
      # Verify the strategy
      assert get_strategy(Bardo.PopulationManager.Supervisor) == :one_for_one
    end
    
    test "starts with PopulationManagerSupervisor properly configured" do
      # Get the DynamicSupervisor child spec
      {:ok, child_specs} = get_child_specs(Bardo.PopulationManager.Supervisor)
      dynamic_sup_spec = Enum.find(child_specs, fn spec ->
        case spec do
          %{start: {DynamicSupervisor, _, _}} -> true
          _ -> false
        end
      end)
      
      # Extract the arguments
      {_, _, [args]} = dynamic_sup_spec.start
      
      # Verify the name and strategy
      assert Keyword.get(args, :name) == Bardo.PopulationManager.PopulationManagerSupervisor
      assert Keyword.get(args, :strategy) == :one_for_one
    end
  end
  
  describe "Bardo.AgentManager.AgentWorkerSupervisor" do
    test "helper functions for dynamic supervision" do
      # Define the module's API
      assert function_exported?(Bardo.AgentManager.AgentWorkerSupervisor, :start_agent, 2)
      assert function_exported?(Bardo.AgentManager.AgentWorkerSupervisor, :stop_agent, 1)
      assert function_exported?(Bardo.AgentManager.AgentWorkerSupervisor, :count_agents, 0)
      assert function_exported?(Bardo.AgentManager.AgentWorkerSupervisor, :list_agents, 0)
    end
  end
  
  # Helper functions
  
  # Get the supervisor's child specs
  defp get_child_specs(supervisor) do
    try do
      # Create a fake init context
      init_arg = []
      # Call the init function directly
      {:ok, supervisor_options} = apply(supervisor, :init, [init_arg])

      # Handle all known supervisor format variations
      case supervisor_options do
        {_strategy, child_specs} when is_list(child_specs) ->
          # Old format: {:ok, {strategy, children}}
          {:ok, child_specs}
        %{children: child_specs} when is_list(child_specs) ->
          # New format: {:ok, %{strategy: strategy, children: children}}
          {:ok, child_specs}
        # Handle newest Elixir 1.17+ supervisor format which returns nested maps
        {%{}, child_specs} when is_list(child_specs) ->
          # Newest format: {:ok, {%{intensity: N, period: P, strategy: S, ...}, [children]}}
          {:ok, child_specs}
        _ ->
          {:error, "Unknown supervisor options format: #{inspect(supervisor_options)}"}
      end
    rescue
      e -> {:error, "Error getting child specs: #{inspect(e)}"}
    end
  end

  # Extract the strategy from a supervisor
  defp get_strategy(supervisor) do
    try do
      # Create a fake init context
      init_arg = []
      # Call the init function directly
      {:ok, supervisor_options} = apply(supervisor, :init, [init_arg])

      # Handle all known supervisor format variations
      case supervisor_options do
        {strategy, _} when is_atom(strategy) ->
          # Old format: {:ok, {strategy, children}}
          strategy
        %{strategy: strategy} ->
          # New format: {:ok, %{strategy: strategy, ...}}
          strategy
        # Handle newest Elixir 1.17+ supervisor format which returns nested maps
        {%{strategy: strategy}, _} ->
          # Newest format: {:ok, {%{intensity: N, period: P, strategy: S, ...}, [children]}}
          strategy
        _ ->
          {:error, "Unknown supervisor options format: #{inspect(supervisor_options)}"}
      end
    rescue
      e -> {:error, "Error getting strategy: #{inspect(e)}"}
    end
  end
  
  # Extract the modules from child specs
  defp extract_modules(child_specs) do
    Enum.map(child_specs, fn spec ->
      case spec do
        %{start: {module, _, _}} -> module
        {module, _, _} -> module
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end
end