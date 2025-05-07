defmodule Bardo.Polis.Manager do
  @moduledoc """
  The PolisManager process represents an interfacing point with the
  neuroevolutionary platform infrastructure. The module contains the
  functions that perform general, global tasks. Because there should be
  only a single polis_manager per node, representing
  a single neuroevolutionary platform per node.

  The following list summarizes the types of functions we want to be able to execute
  through the polis_manager module:
   1. Start all the neuroevolutionary platform supporting processes
   2. Stop and shut down the neuroevolutionary platform
   
  The PolisManager is the infrastructure and the system within which the
  the NN based agents, and the scapes they interface with,
  exist. It is for this reason that it was given the name 'polis', an
  independent and self governing city state of intelligent agents.
  """
  
  use GenServer
  
  alias Bardo.{DB, LogR, AppConfig}
  alias Bardo.ScapeManager.ScapeManagerClient

  @doc """
  Starts the PolisManager process.
  The start_link first checks whether a polis_manager process has already been
  spawned, by checking if one is registered. If it's not, then the
  GenServer.start_link function starts up the neuroevolutionary
  platform. Otherwise, it returns an error.
  """
  @spec start_link() :: {:error, String.t()} | {:ok, pid()}
  def start_link do
    case Process.whereis(__MODULE__) do
      nil ->
        GenServer.start_link(__MODULE__, [], name: __MODULE__)
      pid ->
        LogR.error({:polis_mgr, :start_link, :error, "PolisMgr already online", [pid]})
        {:error, "PolisMgr already running."}
    end
  end

  # For compatibility with supervisor
  def start_link(_) do
    start_link()
  end

  @doc """
  The prep function first checks whether a polis_manager process is online.
  If there is an online polis_manager process running on the node, then the
  prep function preps the system. Otherwise, it returns an error.
  """
  @spec prep(binary() | list()) :: {:error, String.t()} | :ok
  def prep(tarball) do
    case Process.whereis(__MODULE__) do
      nil ->
        LogR.error({:polis_mgr, :prep, :error, "PolisMgr cannot prep, it is not online", []})
        {:error, "PolisMgr not online"}
      pid ->
        GenServer.call(pid, {:prep, tarball}, 15000)
    end
  end

  @doc """
  The setup function first checks whether a polis_manager process is online.
  If there is an online polis_manager process running on the node, then the
  setup function configures the system and starts the public
  scape if any. Otherwise, it returns an error.
  """
  @spec setup(binary()) :: {:error, String.t()} | :ok
  def setup(config) do
    case Process.whereis(__MODULE__) do
      nil ->
        LogR.error({:polis_mgr, :setup, :error, "PolisMgr cannot setup, it is not online", []})
        {:error, "PolisMgr not online"}
      pid ->
        GenServer.call(pid, {:setup, config}, 15000)
    end
  end

  @doc """
  Backs up the DB and shuts down the application.
  """
  @spec backup_and_shutdown() :: {:error, String.t()} | :ok
  def backup_and_shutdown do
    LogR.info({:polis_mgr, :status, :ok, "backing up DB and shutting down", []})
    GenServer.cast(__MODULE__, :backup_and_shutdown)
  end

  @doc """
  All applications are taken down smoothly, all code is unloaded, and all
  ports are closed before the system terminates by calling halt(Status).
  The stop function first checks whether a polis_manager process is online.
  If there is an online polis_manager process running on the node, then the
  stop function sends a signal to it requesting it to stop. Otherwise,
  it shutdowns immediately.
  """
  @spec stop() :: {:error, String.t()} | :ok
  def stop do
    case Process.whereis(__MODULE__) do
      nil ->
        LogR.error({:polis_mgr, :stop, :error, "polis_mgr not online", []})
        LogR.info({:polis_mgr, :status, :ok, "shutting down", []})
        Application.stop(:bardo)
      _pid ->
        LogR.info({:polis_mgr, :status, :ok, "shutting down", []})
        GenServer.cast(__MODULE__, {:stop, :external})
    end
  end

  @impl GenServer
  def init([]) do
    init_state = %{}
    LogR.info({:polis_mgr, :init, :ok, nil, []})
    {:ok, init_state}
  end

  @impl GenServer
  def handle_call({:prep, tarball}, _from, state) do
    do_prep(tarball)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call({:setup, config}, _from, state) do
    do_setup(config)
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_call(request, from, state) do
    LogR.warning({:polis_mgr, :msg, :error, "unexpected handle_call", [request, from]})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast(:backup_and_shutdown, _state) do
    DB.backup()
    :timer.sleep(45000)
    Application.stop(:bardo)
    {:noreply, %{}}
  end

  @impl GenServer
  def handle_cast({:stop, :external}, _state) do
    :timer.sleep(5000)
    Application.stop(:bardo)
    {:noreply, %{}}
  end

  @impl GenServer
  def handle_cast({:stop, :normal}, state) do
    {:stop, :normal, state}
  end

  @impl GenServer
  def handle_cast({:stop, :shutdown}, state) do
    {:stop, :shutdown, state}
  end

  @impl GenServer
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  # Internal functions

  defp do_prep(tarball) when is_binary(tarball) or is_list(tarball) do
    {:ok, %{checksum: _c, metadata: _m, contents: c}} = Bardo.Tarball.unpack(tarball, :memory)
    
    for {f, b} <- c do
      :code.load_binary(
        String.to_atom(Path.rootname(f)), 
        String.to_atom(Path.rootname(f)), 
        b
      )
    end
    
    :ok
  end

  defp do_setup(config) do
    e_config1 = config |> Jason.encode!() |> Jason.decode!(keys: :atoms)
    e_config2 = atomize(e_config1)
    set_env_vars(e_config2)
    LogR.info({:polis_mgr, :status, :ok, "set_env_vars", []})
    maybe_start_public_scape()
  end

  defp set_env_vars(config) do
    exp_config = Map.get(config, :exp_parameters)
    pmp_config = Map.get(config, :pm_parameters)
    init_cons_config = Map.get(config, :init_constraints)
    
    # polis
    Application.put_env(:bardo, :build_tool, Map.get(exp_config, :build_tool))
    Application.put_env(:bardo, :identifier, Map.get(exp_config, :identifier))
    Application.put_env(:bardo, :runs, Map.get(exp_config, :runs))
    Application.put_env(:bardo, :public_scape, Map.get(exp_config, :public_scape))
    Application.put_env(:bardo, :min_pimprovement, Map.get(exp_config, :min_pimprovement))
    Application.put_env(:bardo, :search_params_mut_prob, Map.get(exp_config, :search_params_mut_prob))
    Application.put_env(:bardo, :output_sat_limit, Map.get(exp_config, :output_sat_limit))
    Application.put_env(:bardo, :ro_signal, Map.get(exp_config, :ro_signal))
    Application.put_env(:bardo, :fitness_stagnation, Map.get(exp_config, :fitness_stagnation))
    Application.put_env(:bardo, :population_mgr_efficiency, Map.get(exp_config, :population_mgr_efficiency))
    Application.put_env(:bardo, :re_entry_probability, Map.get(exp_config, :re_entry_probability))
    Application.put_env(:bardo, :shof_ratio, Map.get(exp_config, :shof_ratio))
    Application.put_env(:bardo, :selection_algorithm_efficiency, Map.get(exp_config, :selection_algorithm_efficiency))
    
    # pmp
    Application.put_env(:bardo, :pmp, %{data: Map.get(pmp_config, :data)})
    
    # init_cons
    Application.put_env(:bardo, :constraints, init_cons_config)
  end

  defp atomize(%{mutation_operators: mut_ops} = map) do
    # init_constraints have special constraints
    Enum.reduce(map, %{}, fn {k, v1}, acc ->
      v2 = case {k, v1} do
        {:mutation_operators, mut_ops} ->
          Enum.map(mut_ops, fn op -> List.to_tuple(atomize(op)) end)
        {:tot_topological_mutations_fs, mut_fs} ->
          Enum.map(mut_fs, fn f -> List.to_tuple(atomize(f)) end)
        {:tuning_duration_f, [dur_f, param]} ->
          {atomize(dur_f), atomize(param)}
        _ ->
          atomize(v1)
      end
      
      Map.put(acc, atomize(k), v2)
    end)
  end
  
  defp atomize(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {k, v}, acc -> Map.put(acc, atomize(k), atomize(v)) end)
  end
  
  defp atomize([_head | _tail] = terms) do
    Enum.map(terms, fn t -> atomize(t) end)
  end
  
  defp atomize([]), do: []
  
  defp atomize(term) when is_binary(term) do
    String.to_atom(term)
  end
  
  defp atomize(term) when is_list(term) do
    String.to_atom(term)
  end
  
  defp atomize(term), do: term

  defp maybe_start_public_scape do
    public_scape = AppConfig.get_env(:public_scape)
    
    case public_scape do
      [] ->
        :ok
      [x, y, width, height, mod_name] ->
        ScapeManagerClient.start_scape(x, y, width, height, mod_name)
    end
  end
end