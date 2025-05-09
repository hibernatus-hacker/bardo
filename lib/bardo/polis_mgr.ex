defmodule Bardo.PolisMgr do
  @moduledoc """
  Interface module for Polis Manager operations.

  This module acts as a facade for the Polis.Manager implementation,
  providing compatibility with the complex examples that expect a root-level
  PolisMgr module.
  """

  alias Bardo.Polis.Manager

  @doc """
  Sets up the neuroevolutionary platform with the given configuration.

  This function configures the environment, sets up populations and scapes
  according to the provided configuration.

  ## Parameters
    * `config` - Map containing configuration for experiments, populations, and scapes

  ## Returns
    * `{:ok, term}` - If the setup was successful
    * `{:error, reason}` - If there was an error during setup
  """
  @spec setup(map()) :: {:ok, term()} | {:error, term()}
  def setup(config) do
    # 1. Start Polis.Manager if not already started
    ensure_manager_started()

    # 2. Process the configuration to extract and organize components
    processed_config = process_config(config)

    # 3. Set up the experiment using Manager.setup
    try do
      Manager.setup(processed_config)
      {:ok, config.id}
    rescue
      e ->
        IO.puts("Error setting up polis: \#{inspect(e)}")
        {:error, e}
    end
  end

  @doc """
  Prepares the system with the provided tarball.
  """
  @spec prep(binary()) :: :ok | {:error, term()}
  def prep(tarball) do
    ensure_manager_started()
    Manager.prep(tarball)
  end

  @doc """
  Stops the polis manager and cleans up resources.
  """
  @spec stop() :: :ok
  def stop do
    Manager.stop()
  end

  @doc """
  Stops a specific polis instance.

  ## Parameters
    * `id` - ID of the polis instance to stop

  ## Returns
    * `:ok` - If the polis was stopped successfully
    * `{:error, reason}` - If there was an error stopping the polis
  """
  @spec stop(atom() | binary()) :: :ok | {:error, term()}
  def stop(id) do
    # Call the Manager implementation
    ensure_manager_started()
    Manager.stop_instance(id)
  end

  @doc """
  Sends a command to a live polis instance.

  ## Parameters
    * `id` - ID of the polis instance to send the command to
    * `command` - The command to send

  ## Returns
    * `{:ok, result}` - Result of the command
    * `{:error, reason}` - If there was an error executing the command
  """
  @spec send_command(atom() | binary(), atom()) :: {:ok, term()} | {:error, term()}
  def send_command(id, command) when is_atom(command) do
    # Call the Manager implementation
    ensure_manager_started()
    Manager.send_command(id, command)
  end

  @doc """
  Evolves the next generation for a specific polis instance.

  ## Parameters
    * `id` - ID of the polis instance

  ## Returns
    * `{:ok, generation_info}` - Info about the evolved generation
    * `{:error, reason}` - If there was an error evolving the generation
  """
  @spec evolve_generation(atom() | binary()) :: {:ok, map()} | {:error, term()}
  def evolve_generation(id) do
    # Call the Manager implementation
    ensure_manager_started()
    Manager.evolve_generation(id)
  end

  @doc """
  Updates the population for a specific polis instance.

  ## Parameters
    * `id` - ID of the polis instance
    * `population` - New population data

  ## Returns
    * `:ok` - If the population was updated successfully
    * `{:error, reason}` - If there was an error updating the population
  """
  @spec update_population(atom() | binary(), map()) :: :ok | {:error, term()}
  def update_population(id, population) do
    # Call the Manager implementation
    ensure_manager_started()
    Manager.update_population(id, population)
  end
  
  # Private functions
  
  # Ensure that the Polis.Manager is started
  defp ensure_manager_started do
    if Process.whereis(Bardo.Polis.Manager) == nil do
      # Start supervisor which will start manager
      {:ok, _} = Bardo.Polis.Supervisor.start_link([])
    end
    :ok
  end
  
  # Process the configuration to match what Polis.Manager expects
  defp process_config(config) do
    # Get experiment id
    id = Map.get(config, :id)
    
    # Extract populations
    populations = Map.get(config, :populations, [])
    
    # Extract scapes
    scapes = Map.get(config, :scapes, [])
    
    # Create experiment parameters
    exp_parameters = %{
      identifier: id,
      runs: Map.get(config, :iterations, 1),
      backup_frequency: Map.get(config, :backup_frequency, 10),
      build_tool: "mix",
      public_scape: [],  # Default to no public scape
      min_pimprovement: 0.01,
      search_params_mut_prob: 0.1,
      output_sat_limit: 0.9,
      ro_signal: -1.0,
      fitness_stagnation: 10,
      population_mgr_efficiency: 0.1,
      re_entry_probability: 0.01,
      shof_ratio: 0.2,
      selection_algorithm_efficiency: 0.1
    }
    
    # Create population manager parameters
    pm_parameters = %{
      data: populations
    }
    
    # Create initial constraints
    init_constraints = %{
      mutation_operators: extract_default_mutation_operators(),
      tuning_duration_f: ["default_tuning_duration", 0],
      tot_topological_mutations_fs: [["default_topological_mutations", 0]]
    }
    
    # Final configuration
    %{
      id: id,
      scapes: scapes,
      exp_parameters: exp_parameters,
      pm_parameters: pm_parameters,
      init_constraints: init_constraints
    }
  end
  
  # Default mutation operators if none provided
  defp extract_default_mutation_operators do
    [
      ["add_neuron", 0.03],
      ["add_connection", 0.05],
      ["modify_weights", 0.8], 
      ["enable_connection", 0.01],
      ["disable_connection", 0.01],
      ["remove_connection", 0.01],
      ["remove_neuron", 0.005]
    ]
  end
end