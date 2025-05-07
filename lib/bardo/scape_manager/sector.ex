defmodule Bardo.ScapeManager.Sector do
  @moduledoc """
  Sectors are the subcomponents/processes that make up a Scape.
  
  See the Scape module for a description of what is a Scape.
  """
  
  use GenServer
  
  alias Bardo.{Utils, LogR}
  alias Bardo.AgentManager.AgentManagerClient
  alias Bardo.Models

  defmodule State do
    @moduledoc false
    defstruct mod_name: nil, mod_state: nil
  end

  @type mod_name :: {:public, atom()}
  @type mod_state :: any()
  @type scape_id :: atom() | float() | {float(), :scape} | {atom(), :scape}

  @callback init(params :: any()) ::
    {:ok, initial_mod_state :: mod_state()}

  @callback enter(agent_id :: Models.agent_id(), params :: any(), state :: mod_state()) ::
    {result :: :success | nil, new_mod_state :: mod_state()}

  @callback sense(agent_id :: Models.agent_id(), params :: any(), sensor_pid :: pid(),
    state :: mod_state()) :: {result :: atom() | [float()], new_mod_state :: mod_state()}

  @callback actuate(agent_id :: Models.agent_id(), function :: atom(), params :: any(),
    state :: mod_state()) :: {result :: {[float()], integer() | atom()}, new_mod_state :: mod_state()}

  @callback leave(agent_id :: Models.agent_id(), params :: any(), state :: mod_state()) ::
    {:ok, new_mod_state :: mod_state()}

  @callback remove(agent_id :: Models.agent_id(), mod_state :: mod_state()) ::
    {result :: any(), new_mod_state :: mod_state()}

  @callback insert(agent_id :: Models.agent_id(), params :: any(), mod_state :: mod_state()) ::
    {:ok, new_mod_state :: mod_state()}

  @callback terminate(reason :: atom(), mod_state :: mod_state()) ::
    :ok

  @optional_callbacks [remove: 2, insert: 3, terminate: 2]

  @doc """
  Starts the Sector process.
  """
  @spec start_link(atom(), integer() | atom()) :: {:ok, pid()}
  def start_link(mod, uid) do
    GenServer.start_link(__MODULE__, [mod], name: to_atom(uid))
  end

  @doc """
  Enter sector.
  """
  @spec enter(integer() | atom(), Models.agent_id(), any()) :: :ok
  def enter(uid, agent_id, params) do
    GenServer.cast(to_atom(uid), {:enter, agent_id, params})
  end

  @doc """
  Gather sensory inputs from the environment.
  """
  @spec sense(integer() | atom(), Models.agent_id(), pid(), any()) :: :ok
  def sense(uid, agent_id, sensor_pid, params) do
    GenServer.cast(to_atom(uid), {:sense, agent_id, sensor_pid, params})
  end

  @doc """
  Perform various sector functions e.g. move, push, etc. The sector
  API is problem dependent. This function provides an interface
  to call various functions defined by the sector in question.
  """
  @spec actuate(integer() | atom(), Models.agent_id(), atom(), pid(), any()) :: :ok
  def actuate(uid, agent_id, function, actuator_pid, params) do
    GenServer.cast(to_atom(uid), {:actuate, agent_id, function, actuator_pid, params})
  end

  @doc """
  Leave sector.
  """
  @spec leave(integer() | atom(), Models.agent_id(), any()) :: :ok
  def leave(uid, agent_id, params) do
    GenServer.cast(to_atom(uid), {:leave, agent_id, params})
  end

  @doc """
  Remove Agent from sector.
  """
  @spec remove(integer() | atom(), Models.agent_id()) :: any()
  def remove(uid, agent_id) do
    GenServer.call(to_atom(uid), {:remove, agent_id})
  end

  @doc """
  Insert Agent into sector.
  """
  @spec insert(integer() | atom(), Models.agent_id(), any()) :: :ok
  def insert(uid, agent_id, params) do
    GenServer.call(to_atom(uid), {:insert, agent_id, params})
  end

  @doc """
  Sends a signal to the Sector process requesting it to stop.
  """
  @spec stop(integer() | atom()) :: :ok
  def stop(uid) do
    GenServer.cast(to_atom(uid), {:stop, :normal})
  end

  # Sector ETS helper functions

  @doc """
  Insert object.
  """
  @spec store(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10, term()) :: true
  def store(table, value) do
    true = :shards.insert(table, value)
  end

  @doc """
  Lookup object.
  """
  @spec fetch(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10, term()) :: list()
  def fetch(table, key) do
    :shards.lookup(table, key)
  end

  @doc """
  Return all objects.
  """
  @spec fetch(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10) :: list()
  def fetch(table) do
    :shards.match_object(table, {:'$0', :'$1'})
  end

  @doc """
  Delete object.
  """
  @spec delete(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10, term()) :: true
  def delete(table, key) do
    true = :shards.delete(table, key)
  end

  @doc """
  Delete entire table.
  """
  @spec delete(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10) :: true
  def delete(table) do
    true = :shards.delete(table)
  end

  @doc """
  Update counter.
  """
  @spec update_counter(:t1 | :t2 | :t3 | :t4 | :t5 | :t6 | :t7 | :t8 | :t9 | :t10, term(), tuple(), tuple()) :: integer()
  def update_counter(table, key, update_op, default) do
    :shards.update_counter(table, key, update_op, default)
  end

  # GenServer callbacks

  @impl GenServer
  def init([mod]) do
    Process.flag(:trap_exit, true)
    Utils.random_seed()
    
    m = Utils.get_module(mod)
    {:ok, mod_state} = apply(m, :init, [mod])
    
    LogR.debug({:sector, :init, :ok, nil, [m]})
    
    {:ok, %State{mod_name: m, mod_state: mod_state}}
  end

  @impl GenServer
  def handle_call({:remove, agent_id}, _from, state) do
    {result, new_state} = do_remove(agent_id, state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call({:insert, agent_id, params}, _from, state) do
    {result, new_state} = do_insert(agent_id, params, state)
    {:reply, result, new_state}
  end

  @impl GenServer
  def handle_call(request, from, state) do
    LogR.warning({:sector, :msg, :error, "unexpected handle_call", [request, from]})
    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_cast({:enter, agent_id, params}, state) do
    new_state = do_enter(agent_id, params, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:sense, agent_id, sensor_pid, params}, state) do
    new_state = do_sense(agent_id, params, sensor_pid, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:actuate, agent_id, function, actuator_pid, params}, state) do
    new_state = do_actuate(agent_id, function, actuator_pid, params, state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast({:leave, agent_id, params}, state) do
    new_state = do_leave(agent_id, params, state)
    {:noreply, new_state}
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
  def handle_info(info, state) do
    case info do
      {:EXIT, _pid, :normal} ->
        {:noreply, state}
      {:EXIT, pid, reason} ->
        LogR.debug({:sector, :msg, :ok, "exit message", [pid]})
        {:stop, reason, state}
      unexpected_msg ->
        LogR.warning({:sector, :msg, :error, "unexpected info message", [unexpected_msg]})
        {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(reason, state) do
    LogR.debug({:sector, :terminate, :ok, nil, [reason]})
    
    mod = state.mod_name
    
    if function_exported?(mod, :terminate, 2) do
      apply(mod, :terminate, [reason, state.mod_state])
    else
      :ok
    end
  end

  # Internal functions

  defp to_atom(uid) when is_integer(uid), do: String.to_atom(Integer.to_string(uid))
  defp to_atom(uid) when is_list(uid), do: String.to_atom(uid)
  defp to_atom(uid) when is_atom(uid), do: uid

  defp do_enter(agent_id, params, state) do
    mod = state.mod_name
    {_res, new_mod_s} = apply(mod, :enter, [agent_id, params, state.mod_state])
    %{state | mod_state: new_mod_s}
  end

  defp do_sense(agent_id, params, sensor_pid, state) do
    mod = state.mod_name
    {result, new_mod_s} = apply(mod, :sense, [agent_id, params, sensor_pid, state.mod_state])
    AgentManagerClient.percept(sensor_pid, result)
    %{state | mod_state: new_mod_s}
  end

  defp do_actuate(agent_id, function, actuator_pid, params, state) do
    mod = state.mod_name
    {{fitness, halt_flag}, new_mod_s} = apply(mod, :actuate, [agent_id, function, params, state.mod_state])
    AgentManagerClient.fitness(actuator_pid, fitness, halt_flag)
    %{state | mod_state: new_mod_s}
  end

  defp do_leave(agent_id, params, state) do
    mod = state.mod_name
    {:ok, new_mod_s} = apply(mod, :leave, [agent_id, params, state.mod_state])
    %{state | mod_state: new_mod_s}
  end

  defp do_remove(agent_id, state) do
    mod = state.mod_name
    
    {params, new_mod_s} = if function_exported?(mod, :remove, 2) do
      apply(mod, :remove, [agent_id, state.mod_state])
    else
      {:ok, state.mod_state}
    end
    
    {params, %{state | mod_state: new_mod_s}}
  end

  defp do_insert(agent_id, params, state) do
    mod = state.mod_name
    
    {:ok, new_mod_s} = if function_exported?(mod, :insert, 3) do
      apply(mod, :insert, [agent_id, params, state.mod_state])
    else
      {:ok, state.mod_state}
    end
    
    {:ok, %{state | mod_state: new_mod_s}}
  end
end