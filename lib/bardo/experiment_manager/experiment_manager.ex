defmodule Bardo.ExperimentManager.ExperimentManager do
  @moduledoc """
  The ExperimentManager is responsible for orchestrating neuroevolution experiments.
  
  It handles the complete lifecycle of experiments:
  
  1. Creation and configuration of experiments with parameters
  2. Starting and coordinating evolutionary runs across populations
  3. Tracking experiment progress and collecting results
  4. Providing status updates and access to results
  5. Managing experiment persistence and reporting
  
  Specifically, it has three main functionalities:
  
  1. Run the population_manager N number of times, waiting for the
     population_manager's trace after every run.
  2. Create the experiment entry in the database, and keep
     updating its trace_acc as it itself accumulates the traces from
     spawned population_managers. This enables persistence across restarts.
  3. When the experiment_manager has finished performing N number of
     evolutionary runs, it calculates statistics and produces reports
     of the results for analysis.
  """
  
  use GenServer
  require Logger
  
  alias Bardo.Logger, as: LogR
  # Models is used indirectly through Persistence
  alias Bardo.Persistence
  alias Bardo.PopulationManager.PopulationManagerSupervisor
  alias Bardo.PopulationManager.PopulationManagerClient
  
  # Default experiment configuration
  @default_config %{
    name: "Default Experiment",
    runs: 1,
    generations: 100,
    population_size: 50,
    morphology: :default,
    selection_method: :tournament,
    crossover_rate: 0.7,
    mutation_rate: 0.3,
    elitism: 0.1,
    backup_flag: true,
    visualize: false,
    distributed: false
  }
  
  # Client API

  @doc """
  Start the ExperimentManager as a linked process.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc """
  Start a new experiment run with default parameters.
  This creates a default experiment and starts it immediately.

  ## Returns
    * `:ok` - If the run was started successfully
    * `{:error, reason}` - If there was an error starting the run
  """
  @spec run() :: :ok | {:error, term()}
  def run() do
    # Create a new experiment with a timestamp-based name
    name = "Default Experiment #{:erlang.system_time(:millisecond)}"

    case new_experiment(name) do
      {:ok, experiment_id} ->
        # Configure with default settings
        configure(experiment_id, @default_config)

        # Set a basic fitness function (always returns 1.0 for testing)
        start_evaluation(experiment_id, fn _ -> 1.0 end)

        # Start the experiment
        start(experiment_id)

      error ->
        error
    end
  end
  
  @doc """
  Create a new experiment with the given name.
  
  ## Parameters
    * `name` - Name of the experiment
    
  ## Returns
    * `{:ok, experiment_id}` - Experiment ID of the created experiment
    * `{:error, reason}` - If there was an error creating the experiment
    
  ## Examples
      iex> ExperimentManager.new_experiment("XOR Experiment")
      {:ok, "experiment_1621234567890"}
  """
  @spec new_experiment(String.t()) :: {:ok, String.t()} | {:error, term()}
  def new_experiment(name) do
    GenServer.call(__MODULE__, {:new_experiment, name})
  end
  
  @doc """
  Configure an existing experiment with the given parameters.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to configure
    * `config` - Configuration parameters for the experiment
    
  ## Returns
    * `:ok` - If the experiment was configured successfully
    * `{:error, reason}` - If there was an error configuring the experiment
    
  ## Examples
      iex> config = %{
      ...>   runs: 5,
      ...>   generations: 50,
      ...>   population_size: 100,
      ...>   morphology: :xor,
      ...>   selection_method: :tournament,
      ...>   backup_flag: true
      ...> }
      iex> ExperimentManager.configure("experiment_1621234567890", config)
      :ok
  """
  @spec configure(String.t(), map()) :: :ok | {:error, term()}
  def configure(experiment_id, config) do
    GenServer.call(__MODULE__, {:configure, experiment_id, config})
  end
  
  @doc """
  Set the fitness function for evaluating solutions in an experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment
    * `fitness_function` - Function to evaluate fitness of solutions
    
  ## Returns
    * `:ok` - If the fitness function was set successfully
    * `{:error, reason}` - If there was an error setting the fitness function
    
  ## Examples
      iex> fitness_fn = fn solution -> solution.output == [0, 1, 1, 0] end
      iex> ExperimentManager.start_evaluation("experiment_1621234567890", fitness_fn)
      :ok
  """
  @spec start_evaluation(String.t(), function() | atom()) :: :ok | {:error, term()}
  def start_evaluation(experiment_id, fitness_function) do
    GenServer.call(__MODULE__, {:set_fitness, experiment_id, fitness_function})
  end
  
  @doc """
  Start an experiment with the given ID.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to start
    
  ## Returns
    * `:ok` - If the experiment was started successfully
    * `{:error, reason}` - If there was an error starting the experiment
    
  ## Examples
      iex> ExperimentManager.start("experiment_1621234567890")
      :ok
  """
  @spec start(String.t()) :: :ok | {:error, term()}
  def start(experiment_id) do
    GenServer.call(__MODULE__, {:start, experiment_id})
  end
  
  @doc """
  Get the status of an experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to get status for
    
  ## Returns
    * `{:in_progress, status}` - If the experiment is in progress, with status details
    * `{:completed, results}` - If the experiment is completed, with results
    * `{:error, reason}` - If there was an error getting the status
    
  ## Examples
      iex> ExperimentManager.status("experiment_1621234567890")
      {:in_progress, %{
        run: 2,
        total_runs: 5,
        generation: 45,
        generations: 50,
        best_fitness: 0.95,
        avg_fitness: 0.72
      }}
  """
  @spec status(String.t()) :: 
    {:not_started, map()} | {:in_progress, map()} | {:completed, map()} | {:error, term()}
  def status(experiment_id) do
    GenServer.call(__MODULE__, {:status, experiment_id})
  end
  
  @doc """
  Get the best solution from an experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to get the best solution from
    
  ## Returns
    * `{:ok, solution}` - Best solution found in the experiment
    * `{:error, reason}` - If there was an error getting the best solution
    
  ## Examples
      iex> ExperimentManager.get_best_solution("experiment_1621234567890")
      {:ok, %{
        fitness: 0.98,
        genotype: %{...},
        phenotype: %{...}
      }}
  """
  @spec get_best_solution(String.t()) :: {:ok, map()} | {:error, term()}
  def get_best_solution(experiment_id) do
    GenServer.call(__MODULE__, {:get_best, experiment_id})
  end
  
  @doc """
  Stop an experiment.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to stop
    
  ## Returns
    * `:ok` - If the experiment was stopped successfully
    * `{:error, reason}` - If there was an error stopping the experiment
    
  ## Examples
      iex> ExperimentManager.stop("experiment_1621234567890")
      :ok
  """
  @spec stop(String.t()) :: :ok | {:error, term()}
  def stop(experiment_id) do
    GenServer.call(__MODULE__, {:stop, experiment_id})
  end
  
  @doc """
  Get all active experiments.
  
  ## Returns
    * `{:ok, [experiment_id]}` - List of active experiment IDs
    * `{:error, reason}` - If there was an error getting the active experiments
    
  ## Examples
      iex> ExperimentManager.list_active()
      {:ok, ["experiment_1621234567890", "experiment_1621234567891"]}
  """
  @spec list_active() :: {:ok, [String.t()]} | {:error, term()}
  def list_active() do
    GenServer.call(__MODULE__, :list_active)
  end
  
  @doc """
  Get a list of all experiments.
  
  ## Returns
    * `{:ok, [experiment]}` - List of all experiments with their basic information
    * `{:error, reason}` - If there was an error getting the experiments
    
  ## Examples
      iex> ExperimentManager.list_all()
      {:ok, [
        %{id: "experiment_1621234567890", name: "XOR Experiment", status: :completed},
        %{id: "experiment_1621234567891", name: "FX Experiment", status: :in_progress}
      ]}
  """
  @spec list_all() :: {:ok, [map()]} | {:error, term()}
  def list_all() do
    GenServer.call(__MODULE__, :list_all)
  end
  
  @doc """
  Export experiment results to a file.
  
  ## Parameters
    * `experiment_id` - ID of the experiment to export
    * `file_path` - Path to save the results to
    * `format` - Format to export in (:csv, :json, or :binary)
    
  ## Returns
    * `:ok` - If the results were exported successfully
    * `{:error, reason}` - If there was an error exporting the results
    
  ## Examples
      iex> ExperimentManager.export_results("experiment_1621234567890", "results.json", :json)
      :ok
  """
  @spec export_results(String.t(), String.t(), atom()) :: :ok | {:error, term()}
  def export_results(experiment_id, file_path, format \\ :json) do
    GenServer.call(__MODULE__, {:export, experiment_id, file_path, format})
  end
  
  # For internal use - called by population managers when a run completes
  @doc false
  def complete(population_id, trace) do
    GenServer.cast(__MODULE__, {:complete, population_id, trace})
  end
  
  # GenServer callbacks
  
  @impl true
  def init(_args) do
    LogR.debug({:experiment_mgr, :init, :ok})
    
    Process.flag(:trap_exit, true)
    
    # Load active experiments from storage
    experiments = case Persistence.list(:experiment) do
      {:ok, exps} when is_list(exps) ->
        # Filter to only include active experiments
        Enum.filter(exps, fn {_, exp} ->
          status = Map.get(exp, :status)
          status == "pending" || status == "running" ||
          status == :not_started || status == :in_progress
        end)
        |> Map.new()
      {:ok, []} ->
        # Handle empty list specifically
        %{}
      exps when is_list(exps) ->
        # Handle case where some DB adapters return list directly
        Enum.filter(exps, fn {_, exp} ->
          status = Map.get(exp, :status)
          status == "pending" || status == "running" ||
          status == :not_started || status == :in_progress
        end)
        |> Map.new()
      _ -> %{}
    end
    
    state = %{
      experiments: experiments,
      active_runs: %{},
      pending_runs: %{},
      completed_runs: %{}
    }
    
    # Start any experiments that were in progress
    Enum.each(experiments, fn {id, exp} ->
      if Map.get(exp, :status) == :in_progress do
        # Resume experiment
        Process.send(self(), {:resume_experiment, id}, [])
      end
    end)
    
    {:ok, state}
  end
  
  @impl true
  def handle_call({:new_experiment, name}, _from, state) do
    experiment_id = "experiment_#{:erlang.system_time(:millisecond)}"
    
    # Create a new experiment with default config
    experiment = %{
      id: experiment_id,
      name: name,
      config: @default_config,
      status: :not_started,
      created_at: System.os_time(:second),
      updated_at: System.os_time(:second),
      runs: [],
      results: %{},
      fitness_function: nil
    }
    
    # Store the experiment
    case Persistence.save(experiment, :experiment) do
      :ok ->
        # Update state
        updated_state = put_in(state.experiments[experiment_id], experiment)
        {:reply, {:ok, experiment_id}, updated_state}
        
      error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:configure, experiment_id, config}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Try to load from storage
        case Persistence.load(:experiment, experiment_id) do
          {:ok, experiment} ->
            # Merge new config with existing config
            merged_config = Map.merge(experiment.config || @default_config, config)
            updated_experiment = %{experiment | config: merged_config, updated_at: System.os_time(:second)}
            
            # Save changes
            case Persistence.save(updated_experiment, :experiment) do
              :ok ->
                # Update state
                updated_state = put_in(state.experiments[experiment_id], updated_experiment)
                {:reply, :ok, updated_state}
                
              error ->
                {:reply, error, state}
            end
            
          _ ->
            {:reply, {:error, "Experiment not found"}, state}
        end
        
      experiment ->
        # Merge new config with existing config
        merged_config = Map.merge(experiment.config || @default_config, config)
        updated_experiment = %{experiment | config: merged_config, updated_at: System.os_time(:second)}
        
        # Save changes
        case Persistence.save(updated_experiment, :experiment) do
          :ok ->
            # Update state
            updated_state = put_in(state.experiments[experiment_id], updated_experiment)
            {:reply, :ok, updated_state}
            
          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl true
  def handle_call({:set_fitness, experiment_id, fitness_function}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        {:reply, {:error, "Experiment not found"}, state}
        
      experiment ->
        # Store the fitness function
        updated_experiment = %{experiment | fitness_function: fitness_function, updated_at: System.os_time(:second)}
        
        # Don't save the function directly to storage - it's not serializable
        # Instead, we'll save a flag indicating a fitness function is set
        saveable_experiment = %{updated_experiment | fitness_function: :function_set}
        
        case Persistence.save(saveable_experiment, :experiment) do
          :ok ->
            # Update state with the actual function
            updated_state = put_in(state.experiments[experiment_id], updated_experiment)
            {:reply, :ok, updated_state}
            
          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl true
  def handle_call({:start, experiment_id}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        {:reply, {:error, "Experiment not found"}, state}

      experiment ->
        if experiment.fitness_function == nil do
          {:reply, {:error, "No fitness function set"}, state}
        else
          # Mark experiment as in progress
          # Ensure the started_at field exists in the experiment
          current_time = System.os_time(:second)

          updated_experiment = experiment
          |> Map.put(:status, :in_progress)
          |> Map.put(:started_at, current_time)
          |> Map.put(:updated_at, current_time)

          # Save to storage (without the function)
          saveable_experiment = %{updated_experiment | fitness_function: :function_set}
          case Persistence.save(saveable_experiment, :experiment) do
            :ok ->
              # Update state
              updated_state = put_in(state.experiments[experiment_id], updated_experiment)

              # Start the first run
              Process.send(self(), {:start_run, experiment_id, 1}, [])

              {:reply, :ok, updated_state}

            error ->
              {:reply, error, state}
          end
        end
    end
  end
  
  @impl true
  def handle_call({:status, experiment_id}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Try to load from storage
        case Persistence.load(:experiment, experiment_id) do
          {:ok, experiment} ->
            status_response = get_experiment_status(experiment)
            {:reply, status_response, state}
            
          error ->
            {:reply, error, state}
        end
        
      experiment ->
        status_response = get_experiment_status(experiment)
        {:reply, status_response, state}
    end
  end
  
  @impl true
  def handle_call({:get_best, experiment_id}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Try to load from storage
        case Persistence.load(:experiment, experiment_id) do
          {:ok, experiment} ->
            best_solution = get_best_experiment_solution(experiment)
            {:reply, {:ok, best_solution}, state}
            
          error ->
            {:reply, error, state}
        end
        
      experiment ->
        best_solution = get_best_experiment_solution(experiment)
        {:reply, {:ok, best_solution}, state}
    end
  end
  
  @impl true
  def handle_call({:stop, experiment_id}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        {:reply, {:error, "Experiment not found"}, state}

      experiment ->
        # Stop any active runs
        Enum.each(state.active_runs, fn {population_id, run} ->
          if run.experiment_id == experiment_id do
            PopulationManagerClient.stop(population_id)
          end
        end)

        # Mark experiment as completed or stopped
        status = if experiment.status == :completed, do: :completed, else: :stopped
        current_time = System.os_time(:second)

        # Ensure updated fields are added properly
        updated_experiment = experiment
        |> Map.put(:status, status)
        |> Map.put(:stopped_at, current_time)
        |> Map.put(:updated_at, current_time)

        # Save to storage
        saveable_experiment = if Map.has_key?(updated_experiment, :fitness_function) do
          %{updated_experiment | fitness_function: :function_set}
        else
          updated_experiment
        end

        case Persistence.save(saveable_experiment, :experiment) do
          :ok ->
            # Update state - remove from active if it was stopped
            updated_state = if status == :stopped do
              # Remove any pending runs
              new_pending = Map.reject(state.pending_runs, fn {_, run} ->
                run.experiment_id == experiment_id
              end)

              %{state |
                experiments: Map.put(state.experiments, experiment_id, updated_experiment),
                pending_runs: new_pending
              }
            else
              %{state | experiments: Map.put(state.experiments, experiment_id, updated_experiment)}
            end

            {:reply, :ok, updated_state}

          error ->
            {:reply, error, state}
        end
    end
  end
  
  @impl true
  def handle_call(:list_active, _from, state) do
    active_experiments = Enum.filter(state.experiments, fn {_, exp} -> 
      exp.status in [:not_started, :in_progress] 
    end)
    |> Enum.map(fn {id, _} -> id end)
    
    {:reply, {:ok, active_experiments}, state}
  end
  
  @impl true
  def handle_call(:list_all, _from, state) do
    # First load all experiments
    all_experiments = case Persistence.list(:experiment) do
      {:ok, list} when is_list(list) -> list
      {:ok, []} -> []
      _ -> []
    end

    # Transform for the response - ensure we handle both map and tuple format
    experiments = Enum.map(all_experiments, fn
      {id, exp} when is_map(exp) ->
        %{
          id: id,
          name: Map.get(exp, :name, "Unnamed"),
          status: Map.get(exp, :status, :unknown),
          created_at: Map.get(exp, :created_at, nil),
          updated_at: Map.get(exp, :updated_at, nil)
        }
      exp when is_map(exp) ->
        # Handle when experiments are returned directly as a map
        %{
          id: Map.get(exp, :id, "unknown_id"),
          name: Map.get(exp, :name, "Unnamed"),
          status: Map.get(exp, :status, :unknown),
          created_at: Map.get(exp, :created_at, nil),
          updated_at: Map.get(exp, :updated_at, nil)
        }
      _ ->
        # Default case for unexpected data format
        %{
          id: "unknown_id",
          name: "Unknown Experiment",
          status: :unknown,
          created_at: nil,
          updated_at: nil
        }
    end)

    {:reply, {:ok, experiments}, state}
  end
  
  @impl true
  def handle_call({:export, experiment_id, file_path, format}, _from, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Try to load from storage
        case Persistence.load(:experiment, experiment_id) do
          {:ok, experiment} ->
            export_result = export_experiment_results(experiment, file_path, format)
            {:reply, export_result, state}
            
          error ->
            {:reply, error, state}
        end
        
      experiment ->
        export_result = export_experiment_results(experiment, file_path, format)
        {:reply, export_result, state}
    end
  end
  
  @impl true
  def handle_cast({:complete, population_id, trace}, state) do
    LogR.debug({:experiment_mgr, :complete, :ok, nil, [population_id]})
    
    # Find the experiment for this population
    case Map.get(state.active_runs, population_id) do
      nil ->
        # Unknown population, ignore
        {:noreply, state}
        
      run_info ->
        experiment_id = run_info.experiment_id
        run_number = run_info.run_number
        
        case Map.get(state.experiments, experiment_id) do
          nil ->
            # Experiment not found, ignore
            {:noreply, state}
            
          experiment ->
            # Update run info with trace
            updated_run = Map.put(run_info, :trace, trace)
            
            # Update experiment with run results
            updated_runs = [updated_run | experiment.runs]
            updated_experiment = %{experiment |
              runs: updated_runs,
              updated_at: System.os_time(:second)
            }
            
            # Check if all runs are completed
            total_runs = experiment.config.runs
            
            # Ensure we have a default value for completed_at
            experiment_with_completed_at = Map.put_new(updated_experiment, :completed_at, nil)

            updated_experiment = if run_number >= total_runs do
              # All runs completed, update status and compute statistics
              %{experiment_with_completed_at |
                status: :completed,
                completed_at: System.os_time(:second),
                results: compute_experiment_results(updated_runs)
              }
            else
              # Start the next run
              Process.send(self(), {:start_run, experiment_id, run_number + 1}, [])
              experiment_with_completed_at
            end
            
            # Save to storage (without the function)
            saveable_experiment = %{updated_experiment | fitness_function: :function_set}
            case Persistence.save(saveable_experiment, :experiment) do
              :ok ->
                # Update state
                active_runs = Map.delete(state.active_runs, population_id)
                completed_runs = Map.put(state.completed_runs, population_id, updated_run)
                updated_state = %{state | 
                  experiments: Map.put(state.experiments, experiment_id, updated_experiment),
                  active_runs: active_runs,
                  completed_runs: completed_runs
                }
                
                {:noreply, updated_state}
                
              error ->
                LogR.error({:experiment_mgr, :save, :error, "Failed to save experiment", [error]})
                {:noreply, state}
            end
        end
    end
  end
  
  @impl true
  def handle_info({:start_run, experiment_id, run_number}, state) do
    LogR.debug({:experiment_mgr, :start_run, :ok, nil, [experiment_id, run_number]})
    
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Experiment not found, ignore
        {:noreply, state}
        
      experiment ->
        # Create a new population for this run
        population_id = "population_#{experiment_id}_#{run_number}"
        
        # Create population config
        population_config = %{
          experiment_id: experiment_id,
          run_number: run_number,
          generations: experiment.config.generations,
          population_size: experiment.config.population_size,
          morphology: experiment.config.morphology,
          selection_method: experiment.config.selection_method,
          crossover_rate: experiment.config.crossover_rate,
          mutation_rate: experiment.config.mutation_rate,
          elitism: experiment.config.elitism,
          fitness_function: experiment.fitness_function
        }
        
        # Start the population, use the configured module (allows testing with mocks)
        population_manager = __MODULE__.population_manager_module()
        case population_manager.start_population(population_id, population_config) do
          {:ok, _pid} ->
            # Record the active run
            run_info = %{
              experiment_id: experiment_id,
              run_number: run_number,
              population_id: population_id,
              started_at: System.os_time(:second),
              status: :running
            }
            
            updated_state = %{state | active_runs: Map.put(state.active_runs, population_id, run_info)}
            {:noreply, updated_state}
            
          error ->
            LogR.error({:experiment_mgr, :start_run, :error, "Failed to start population", [error]})
            
            # Queue the run to retry later
            pending_run = %{
              experiment_id: experiment_id,
              run_number: run_number,
              retry_at: System.os_time(:second) + 60
            }
            
            updated_state = %{state | pending_runs: Map.put(state.pending_runs, "#{experiment_id}_#{run_number}", pending_run)}
            
            # Schedule retry
            Process.send_after(self(), {:retry_run, "#{experiment_id}_#{run_number}"}, 60_000)
            
            {:noreply, updated_state}
        end
    end
  end
  
  @impl true
  def handle_info({:retry_run, pending_id}, state) do
    case Map.get(state.pending_runs, pending_id) do
      nil ->
        # Run no longer pending, ignore
        {:noreply, state}
        
      pending_run ->
        # Remove from pending
        updated_state = %{state | pending_runs: Map.delete(state.pending_runs, pending_id)}
        
        # Start the run
        Process.send(self(), {:start_run, pending_run.experiment_id, pending_run.run_number}, [])
        
        {:noreply, updated_state}
    end
  end
  
  @impl true
  def handle_info({:resume_experiment, experiment_id}, state) do
    case Map.get(state.experiments, experiment_id) do
      nil ->
        # Experiment not found, ignore
        {:noreply, state}
        
      experiment ->
        # Find the last completed run
        completed_runs = experiment.runs
        next_run_number = length(completed_runs) + 1
        
        # Start the next run
        if experiment.status == :in_progress do
          Process.send(self(), {:start_run, experiment_id, next_run_number}, [])
        end
        
        {:noreply, state}
    end
  end
  
  @impl true
  def handle_info(info, state) do
    case info do
      {:EXIT, _pid, :normal} ->
        {:noreply, state}
      {:EXIT, pid, :shutdown} ->
        LogR.debug({:experiment_mgr, :msg, :ok, "shutdown message", [pid]})
        {:stop, :shutdown, state}
      {:EXIT, pid, reason} ->
        LogR.debug({:experiment_mgr, :msg, :ok, "exit message", [pid, reason]})
        {:stop, reason, state}
      unexpected_msg ->
        LogR.warning({:experiment_mgr, :msg, :error, "unexpected info message", [unexpected_msg]})
        {:noreply, state}
    end
  end

  @impl true
  def terminate(reason, _state) do
    LogR.info({:experiment_mgr, :status, :ok, "experiment_mgr terminated", [reason]})
    :ok
  end
  
  # Helper functions
  
  # Get the status and details of an experiment
  defp get_experiment_status(experiment) do
    case experiment.status do
      :not_started ->
        {:not_started, %{
          name: experiment.name,
          created_at: experiment.created_at
        }}
        
      :in_progress ->
        # Calculate progress
        total_runs = experiment.config.runs
        completed_runs = length(experiment.runs)
        current_run = total_runs - completed_runs
        
        # Find current generation from active run if available
        # This would be more complex in a real implementation
        current_generation = 1
        
        {:in_progress, %{
          name: experiment.name,
          run: current_run,
          total_runs: total_runs,
          generation: current_generation,
          generations: experiment.config.generations,
          started_at: experiment.started_at
        }}
        
      :completed ->
        {:completed, %{
          name: experiment.name,
          runs: length(experiment.runs),
          results: experiment.results,
          completed_at: experiment.completed_at
        }}
        
      :stopped ->
        {:stopped, %{
          name: experiment.name,
          runs: length(experiment.runs),
          stopped_at: experiment.stopped_at
        }}
        
      _ ->
        {:error, "Unknown experiment status"}
    end
  end
  
  # Get the best solution from an experiment
  defp get_best_experiment_solution(experiment) do
    if experiment.status == :completed do
      # Return the best solution from results
      Map.get(experiment.results, :best_solution, %{})
    else
      # Find best solution across runs
      best_run = Enum.max_by(experiment.runs, fn run ->
        get_run_fitness(run)
      end, fn -> nil end)
      
      if best_run do
        # Extract best solution from run
        get_run_solution(best_run)
      else
        %{}
      end
    end
  end
  
  # Get the fitness of a run
  defp get_run_fitness(run) do
    trace = Map.get(run, :trace, %{})
    Map.get(trace, :best_fitness, 0.0)
  end
  
  # Get the best solution from a run
  defp get_run_solution(run) do
    trace = Map.get(run, :trace, %{})
    Map.get(trace, :best_solution, %{})
  end
  
  # Compute experiment results from runs
  defp compute_experiment_results(runs) do
    # Calculate statistics across runs
    fitnesses = Enum.map(runs, &get_run_fitness/1)
    
    avg_fitness = if length(fitnesses) > 0 do
      Enum.sum(fitnesses) / length(fitnesses)
    else
      0.0
    end
    
    best_run = Enum.max_by(runs, &get_run_fitness/1, fn -> nil end)
    best_solution = if best_run, do: get_run_solution(best_run), else: %{}
    
    # Return results
    %{
      best_fitness: Enum.max(fitnesses, fn -> 0.0 end),
      avg_fitness: avg_fitness,
      median_fitness: median(fitnesses),
      std_dev: standard_deviation(fitnesses),
      best_solution: best_solution
    }
  end
  
  # Calculate the median of a list
  defp median([]), do: 0.0
  defp median(list) do
    sorted = Enum.sort(list)
    len = length(sorted)
    
    if rem(len, 2) == 0 do
      (Enum.at(sorted, div(len, 2) - 1) + Enum.at(sorted, div(len, 2))) / 2
    else
      Enum.at(sorted, div(len, 2))
    end
  end
  
  # Calculate the standard deviation of a list
  defp standard_deviation([]), do: 0.0
  defp standard_deviation(list) do
    mean = Enum.sum(list) / length(list)
    
    variance = Enum.map(list, fn x -> :math.pow(x - mean, 2) end)
    |> Enum.sum()
    |> Kernel./(length(list))
    
    :math.sqrt(variance)
  end
  
  # Helper functions for module configuration and mocks

  @doc """
  Get the configured population manager module.
  This is used primarily for testing to allow mocks.
  """
  def population_manager_module do
    Application.get_env(:bardo, :population_manager_module, PopulationManagerSupervisor)
  end

  @doc """
  Set the population manager module.
  This is used primarily for testing to allow mocks.
  """
  def set_population_manager_module(module) do
    Application.put_env(:bardo, :population_manager_module, module)
  end

  # Export experiment results to a file
  defp export_experiment_results(experiment, file_path, format) do
    # Get results based on experiment status
    results = case experiment.status do
      :completed -> experiment.results
      _ -> %{runs: experiment.runs, status: experiment.status}
    end
    
    # Add some metadata
    export_data = %{
      experiment: %{
        id: experiment.id,
        name: experiment.name,
        status: experiment.status,
        config: experiment.config,
        created_at: experiment.created_at,
        updated_at: experiment.updated_at
      },
      results: results
    }
    
    # Export based on format
    case format do
      :json ->
        # Export to JSON
        case File.write(file_path, Jason.encode!(export_data, pretty: true)) do
          :ok -> :ok
          error -> error
        end
        
      :csv ->
        # Export to CSV - simplified example
        headers = ["Run", "Best Fitness", "Average Fitness", "Generations"]
        
        run_data = Enum.map(experiment.runs, fn run ->
          trace = Map.get(run, :trace, %{})
          [
            run.run_number,
            Map.get(trace, :best_fitness, 0.0),
            Map.get(trace, :avg_fitness, 0.0),
            Map.get(trace, :generations, 0)
          ]
        end)
        
        csv_data = [headers | run_data]
        |> Enum.map(fn row -> Enum.join(row, ",") end)
        |> Enum.join("\n")
        
        case File.write(file_path, csv_data) do
          :ok -> :ok
          error -> error
        end
        
      :binary ->
        # Export using Persistence module
        Persistence.export(export_data, file_path, compress: true)
        
      _ ->
        {:error, "Unsupported export format"}
    end
  end
end