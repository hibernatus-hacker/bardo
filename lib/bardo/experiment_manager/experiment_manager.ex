defmodule Bardo.ExperimentManager.ExperimentManager do
  @moduledoc """
  The experiment_manager process sequentially spawns population_managers and
  applies them to some specified problem. The experiment_manager can compose
  experiments by performing multiple evolutionary runs, and then
  produce statistical data and graph-ready files of the various
  statistics calculated from the experiment.
  
  Specifically, it has three main functionalities:
  1. Run the population_manager N number of times, waiting for the
     population_manager's trace after every run.
  2. Create the experiment entry in the database, and keep
     updating its trace_acc as it itself accumulates the traces from
     spawned population_managers. The population_manager should only do this
     if the backup_flag is set to true in the experiment record with
     which the experiment was started.
  3. When the experiment_manager has finished performing N number of
     evolutionary runs, and has accumulated N number of traces, it
     prints all the traces to console, calculates averages of the
     parameters between all the traces, and then finally write that
     data to file in the format which can be immediately graphed.
     
  In addition, because the experiment_manager might be interrupted as it
  accumulates the traces, the init function checks if an experiment
  with given unique Id already exists and if it does, has it been
  completed yet. If the experiment has not been completed, it reads from
  the database all the needed the information about the experiment, and
  then runs the population_manager the remaining number of times to complete
  the whole experiment.
  """
  
  use GenServer
  require Logger
  
  alias Bardo.{Models, AppConfig, DB, LogR, Functions}
  alias Bardo.PopulationManager.PopulationManagerClient

  # Define struct for state
  defmodule State do
    @moduledoc false
    defstruct exp: nil, population_id: nil
  end

  # Define graph record equivalent
  defmodule Graph do
    @moduledoc false
    defstruct [
      morphology: nil,
      avg_neurons: [],
      neurons_std: [],
      avg_fitness: [],
      fitness_std: [],
      max_fitness: [],
      min_fitness: [],
      maxavg_fitness: [],
      maxavg_fitness_std: [],
      minavg_fitness: [],
      avg_diversity: [],
      diversity_std: [],
      evaluations: [],
      validation_fitness: [],
      validation_fitness_std: [],
      validationmax_fitness: [],
      validationmin_fitness: [],
      evaluation_index: []
    ]
  end

  # Define average record equivalent
  defmodule Avg do
    @moduledoc false
    defstruct [
      avg_neurons: [],
      neurons_std: [],
      avg_fitness: [],
      fitness_std: [],
      max_fitness: [],
      min_fitness: [],
      maxavg_fitness: nil,
      maxavg_fitness_std: [],
      minavg_fitness: nil,
      avg_diversity: [],
      diversity_std: [],
      evaluations: [],
      validation_fitness: [],
      validation_fitness_std: [],
      validationmax_fitness: [],
      validationmin_fitness: []
    ]
  end

  @doc """
  Starts the ExperimentManager GenServer with the given parameters and options.
  """
  @spec start_link() :: {:ok, pid()}
  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  The run function first checks whether the experiment_manager process is
  online. If the experiment_manager is online, the run function triggers a
  new experiment by starting the population_manager, otherwise, it returns an
  error.
  """
  @spec run() :: :ok
  def run do
    case Process.whereis(__MODULE__) do
      nil ->
        LogR.error({:experiment_mgr, :run, :error, "ExperimentMgr cannot run, it is not online", []})
        {:error, "ExperimentMgr not online"}
      _pid ->
        GenServer.cast(__MODULE__, {:run})
    end
  end

  @doc """
  The complete function checks the current run index vs total_runs. If the
  experiment has completed the set number of runs then the experiment
  record is marked as completed and a report is generated. If not,
  another run is triggered by spawning a new population_manager.
  """
  @spec complete(Models.population_id(), Models.trace()) :: :ok
  def complete(population_id, trace) do
    GenServer.cast(__MODULE__, {:complete, population_id, trace})
  end

  @doc false
  @impl GenServer
  def init([]) do
    Process.flag(:trap_exit, true)
    LogR.debug({:experiment_mgr, :init, :ok, nil, []})
    {:ok, %State{}}
  end

  @doc false
  @impl GenServer
  def handle_call(request, from, state) do
    LogR.warning({:experiment_mgr, :msg, :error, "unexpected call", [request, from]})
    {:reply, :ok, state}
  end

  @doc false
  @impl GenServer
  def handle_cast({:run}, state) do
    new_state = do_run_setup(state)
    PopulationManagerClient.new_run()
    {:noreply, new_state}
  end

  @doc false
  @impl GenServer
  def handle_cast({:complete, _pop_id, trace}, state) do
    {:ok, new_state} = do_complete(trace, state)
    {:noreply, new_state}
  end

  @doc false
  @impl GenServer
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

  @doc false
  @impl GenServer
  def terminate(reason, _state) do
    LogR.info({:experiment_mgr, :status, :ok, "experiment_mgr terminated", [reason]})
    :ok
  end

  # Internal implementation

  defp do_run_setup(state) do
    id = AppConfig.get_env(:identifier)
    pmp = AppConfig.get_env(:pmp)
    constraints = AppConfig.get_env(:constraints)
    runs = AppConfig.get_env(:runs)
    
    e = case DB.read(id, :experiment) do
      :not_found ->
        build_model(id, pmp, constraints, runs)
      prev ->
        case Models.get(prev, :progress_flag) do
          :completed ->
            LogR.error({:experiment_mgr, :do_run_setup, :error, "experiment complete", [id]})
            Bardo.PolisSupervisor.stop()
          :in_progress ->
            LogR.info({:experiment_mgr, :status, :ok, "previously started. continuing", [id]})
            interruptions = Models.get(prev, :interruptions)
            u_interruptions = [Calendar.strftime(DateTime.utc_now(), "%Y-%m-%dT%H:%M:%SZ") | interruptions]
            Models.set(prev, [{:interruptions, u_interruptions}])
        end
    end
    
    DB.write(e, :experiment)
    population_id = Models.get(pmp, :population_id)
    LogR.info({:experiment_mgr, :status, :ok, "run", [pmp, constraints]})
    
    %State{state | exp: e, population_id: population_id}
  end

  defp do_complete(trace, state) do
    e = state.exp
    u_trace_acc = [trace | Models.get(e, :trace_acc)]
    u_run_index = Models.get(e, :run_index) + 1
    
    if u_run_index > Models.get(e, :total_runs) do
      LogR.info({:experiment_mgr, :status, :ok, "experiment complete", [Models.get(e, :run_index)]})
      do_report(e, u_trace_acc, u_run_index)
      :timer.sleep(45000)
      Bardo.PolisSupervisor.backup_and_shutdown()
      {:ok, state}
    else
      u_e = do_restart(e, u_trace_acc, u_run_index)
      new_state = %State{state | exp: u_e}
      {:ok, new_state}
    end
  end

  defp do_report(e, u_trace_acc, u_run_index) do
    u_e = Models.set(e, [
      {:trace_acc, u_trace_acc}, 
      {:run_index, u_run_index},
      {:completed, {
        Calendar.strftime(DateTime.utc_now(), "%Y-%m-%dT%H:%M:%SZ"),
        :erlang.monotonic_time()
      }}, 
      {:progress_flag, :completed}
    ])
    
    DB.write(u_e, :experiment)
    report(Models.get(u_e, :id), "report")
    u_e
  end

  defp do_restart(e, u_trace_acc, u_run_index) do
    u_e = Models.set(e, [{:trace_acc, u_trace_acc}, {:run_index, u_run_index}])
    DB.write(u_e, :experiment)
    
    LogR.info({:experiment_mgr, :status, :ok, "experiment_complete. restarting",
      [Models.get(e, :run_index)]})
      
    PopulationManagerClient.restart_run()
    u_e
  end

  defp build_model(id, pmp, constraints, runs) do
    Models.experiment(%{
      id: id,
      backup_flag: true,
      pm_parameters: pmp,
      init_constraints: constraints,
      progress_flag: :in_progress,
      trace_acc: [],
      run_index: 1,
      total_runs: runs,
      started: {
        Calendar.strftime(DateTime.utc_now(), "%Y-%m-%dT%H:%M:%SZ"),
        :erlang.monotonic_time()
      },
      completed: {},
      interruptions: []
    })
  end

  defp report(experiment_id, file_name) do
    e = DB.read(experiment_id, :experiment)
    
    {:ok, e_file} = File.open("experiments/#{file_name}_experiment", [:write])
    IO.write(e_file, inspect(e))
    File.close(e_file)
    
    traces = Models.get(e, :trace_acc)
    
    {:ok, file} = File.open("experiments/#{file_name}_trace", [:write])
    Enum.each(traces, fn x -> IO.write(file, "#{inspect(x)}.\\n") end)
    File.close(file)
    
    graphs = prepare_graphs(traces)
    write_graphs(graphs)
  end

  # Graphing and statistics functions

  defp prepare_graphs(traces) do
    [t | _] = traces
    [stats_list | _] = Models.get(t, :stats)
    morphologies = Enum.map(stats_list, fn s -> Models.get(s, :morphology) end)
    
    Enum.map(morphologies, fn morphology -> 
      prep_traces(traces, morphology, [])
    end)
  end

  defp write_graphs([g | graphs]) do
    m = g.morphology
    u_g = %{g | evaluation_index: Enum.map(1..length(g.avg_fitness), fn ix -> 500 * ix end)}
    
    {:ok, file} = File.open("experiments/graphs_#{Atom.to_string(m)}", [:write])
    
    IO.write(file, "#Avg Fitness Vs Evaluations, Morphology: #{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.avg_fitness, u_g.fitness_std)
    
    IO.write(file, "\n\n\n#Avg Neurons Vs Evaluations, Morphology: #{inspect(m)}\n")
    Enum.zip3(u_g.evaluation_index, u_g.avg_neurons, u_g.neurons_std)
    |> Enum.each(fn {x, y, std} -> IO.write(file, "#{x} #{y} #{std}\n") end)
    
    IO.write(file, "\n\n#Avg Diversity Vs Evaluations, Morphology: #{inspect(m)}\n")
    Enum.zip3(u_g.evaluation_index, u_g.avg_diversity, u_g.diversity_std)
    |> Enum.each(fn {x, y, std} -> IO.write(file, "#{x} #{y} #{std}\n") end)
    
    IO.write(file, "\n\n#Max Fitness Vs Evaluations, Morphology: #{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.max_fitness)
    
    IO.write(file, "\n\n\n#Avg. Max Fitness Vs Evaluations, Morphology: #{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.maxavg_fitness)
    
    IO.write(file, "\n\n\n#Avg. Min Fitness Vs Evaluations, Morphology: #{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.min_fitness)
    
    IO.write(file, "\n\n\n#Specie-Population Turnover Vs Evaluations, Morphology: #{inspect(m)}\n")
    Enum.zip(u_g.evaluation_index, u_g.evaluations)
    |> Enum.each(fn {x, y} -> IO.write(file, "#{x} #{y}\n") end)
    
    IO.write(file, "\n\n#Validation Avg Fitness Vs Evaluations, Morphology:#{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.validation_fitness, u_g.validation_fitness_std)
    
    IO.write(file, "\n\n\n#Validation Max Fitness Vs Evaluations, Morphology:#{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.validationmax_fitness)
    
    IO.write(file, "\n\n\n#Validation Min Fitness Vs Evaluations, Morphology:#{inspect(m)}")
    print_multi_objective_fitness(file, u_g.evaluation_index, u_g.validationmin_fitness)
    
    File.close(file)
    write_graphs(graphs)
  end
  
  defp write_graphs([]), do: :ok

  defp prep_traces([t | traces], morphology, acc) do
    morphology_trace = List.flatten(
      for stats <- Models.get(t, :stats) do
        for s <- stats, Models.get(s, :morphology) == morphology, do: s
      end
    )
    
    prep_traces(traces, morphology, [morphology_trace | acc])
  end
  
  defp prep_traces([], morphology, acc) do
    graph = avg_morphological_traces(Enum.reverse(acc), [], [], [])
    %{graph | morphology: morphology}
  end

  defp avg_morphological_traces([s_list | s_lists], acc1, acc2, acc3) do
    case s_list do
      [s | s_tail] ->
        avg_morphological_traces(s_lists, [s_tail | acc1], [s | acc2], acc3)
      [] ->
        graph = avg_stats_lists(acc3, %Graph{})
        graph
    end
  end
  
  defp avg_morphological_traces([], acc1, acc2, acc3) do
    avg_morphological_traces(Enum.reverse(acc1), [], [], [Enum.reverse(acc2) | acc3])
  end

  defp avg_stats_lists([s_list | s_lists], graph) do
    avg = avg_stats(s_list, %Avg{})
    
    u_graph = %{graph |
      avg_neurons: [avg.avg_neurons | graph.avg_neurons],
      neurons_std: [avg.neurons_std | graph.neurons_std],
      avg_fitness: [avg.avg_fitness | graph.avg_fitness],
      fitness_std: [avg.fitness_std | graph.fitness_std],
      max_fitness: [avg.max_fitness | graph.max_fitness],
      min_fitness: [avg.min_fitness | graph.min_fitness],
      maxavg_fitness: [avg.maxavg_fitness | graph.maxavg_fitness],
      maxavg_fitness_std: [avg.maxavg_fitness_std | graph.maxavg_fitness_std],
      minavg_fitness: [avg.minavg_fitness | graph.minavg_fitness],
      evaluations: [avg.evaluations | graph.evaluations],
      validation_fitness: [avg.validation_fitness | graph.validation_fitness],
      validation_fitness_std: [avg.validation_fitness_std | graph.validation_fitness_std],
      validationmax_fitness: [avg.validationmax_fitness | graph.validationmax_fitness],
      validationmin_fitness: [avg.validationmin_fitness | graph.validationmin_fitness],
      avg_diversity: [avg.avg_diversity | graph.avg_diversity],
      diversity_std: [avg.diversity_std | graph.diversity_std]
    }
    
    avg_stats_lists(s_lists, u_graph)
  end
  
  defp avg_stats_lists([], graph) do
    %{graph |
      avg_neurons: Enum.reverse(graph.avg_neurons),
      neurons_std: Enum.reverse(graph.neurons_std),
      avg_fitness: Enum.reverse(graph.avg_fitness),
      fitness_std: Enum.reverse(graph.fitness_std),
      max_fitness: Enum.reverse(graph.max_fitness),
      min_fitness: Enum.reverse(graph.min_fitness),
      maxavg_fitness: Enum.reverse(graph.maxavg_fitness),
      maxavg_fitness_std: Enum.reverse(graph.maxavg_fitness_std),
      minavg_fitness: Enum.reverse(graph.minavg_fitness),
      validation_fitness: Enum.reverse(graph.validation_fitness),
      validation_fitness_std: Enum.reverse(graph.validation_fitness_std),
      validationmax_fitness: Enum.reverse(graph.validationmax_fitness),
      validationmin_fitness: Enum.reverse(graph.validationmin_fitness),
      evaluations: Enum.reverse(graph.evaluations),
      avg_diversity: Enum.reverse(graph.avg_diversity),
      diversity_std: Enum.reverse(graph.diversity_std)
    }
  end

  defp avg_stats([s | s_tail], avg) do
    {validation_fitness, _champion_id} = Models.get(s, :validation_fitness)
    
    u_avg = %{avg |
      avg_neurons: [Models.get(s, :avg_neurons) | avg.avg_neurons],
      avg_fitness: list_append(Models.get(s, :avg_fitness), avg.avg_fitness),
      max_fitness: list_append(Models.get(s, :max_fitness), avg.max_fitness),
      min_fitness: list_append(Models.get(s, :min_fitness), avg.min_fitness),
      evaluations: [Models.get(s, :evaluations) | avg.evaluations],
      validation_fitness: list_append(validation_fitness, avg.validation_fitness),
      avg_diversity: [Models.get(s, :avg_diversity) | avg.avg_diversity]
    }
    
    avg_stats(s_tail, u_avg)
  end
  
  defp avg_stats([], avg) do
    %{avg |
      avg_neurons: Functions.avg(avg.avg_neurons),
      neurons_std: Functions.std(avg.avg_neurons),
      avg_fitness: Enum.map(avg.avg_fitness, &Functions.avg/1),
      fitness_std: Enum.map(avg.avg_fitness, &Functions.std/1),
      max_fitness: Enum.map(avg.max_fitness, &Enum.max/1),
      min_fitness: Enum.map(avg.min_fitness, &Enum.min/1),
      maxavg_fitness: Enum.map(avg.max_fitness, &Functions.avg/1),
      maxavg_fitness_std: Enum.map(avg.max_fitness, &Functions.std/1),
      minavg_fitness: Enum.map(avg.min_fitness, &Functions.avg/1),
      evaluations: Functions.avg(avg.evaluations),
      validation_fitness: Enum.map(avg.validation_fitness, &Functions.avg/1),
      validation_fitness_std: Enum.map(avg.validation_fitness, &Functions.std/1),
      validationmax_fitness: Enum.map(avg.validation_fitness, &Enum.max/1),
      validationmin_fitness: Enum.map(avg.validation_fitness, &Enum.min/1),
      avg_diversity: Functions.avg(avg.avg_diversity),
      diversity_std: Functions.std(avg.avg_diversity)
    }
  end

  defp list_append([], []), do: []
  
  defp list_append(list_a, []) do
    Enum.map(list_a, fn val -> [val] end)
  end
  
  defp list_append([], list_b), do: list_b
  
  defp list_append(list_a, list_b) do
    list_append(list_a, list_b, [])
  end

  defp list_append([val | list_a], [acc_b | list_b], acc) do
    list_append(list_a, list_b, [[val | acc_b] | acc])
  end
  
  defp list_append(nil, [acc_b | list_b], acc) do
    list_append([], list_b, [acc_b | acc])
  end
  
  defp list_append([], [], acc) do
    Enum.reverse(acc)
  end

  defp print_multi_objective_fitness(file, [i | index], [f | fitness], [std | standard_deviation]) do
    if f == [] or std == [] do
      :ok
    else
      IO.write(file, "\n#{i} ")
      print_fitness_and_std(file, f, std)
    end
    
    print_multi_objective_fitness(file, index, fitness, standard_deviation)
  end
  
  defp print_multi_objective_fitness(_file, [], [], []), do: :ok

  defp print_fitness_and_std(file, [fe | fitness_elements], [se | std_elements]) do
    IO.write(file, "#{fe} #{se}")
    print_fitness_and_std(file, fitness_elements, std_elements)
  end
  
  defp print_fitness_and_std(_file, [], []), do: :ok

  defp print_multi_objective_fitness(file, [i | index], [f | fitness]) do
    case f do
      [] ->
        :ok
      _ ->
        IO.write(file, "\n#{i}")
        Enum.each(f, fn fe -> IO.write(file, " #{fe}") end)
    end
    
    print_multi_objective_fitness(file, index, fitness)
  end
  
  defp print_multi_objective_fitness(_file, [], []), do: :ok
end