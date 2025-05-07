defmodule Bardo.AgentManager.Actuator do
  @moduledoc """
  Defines generic actuator behavior.
  
  An actuator is a process that accepts signals from neurons in the output layer,
  orders them into a vector, and then uses this vector to control some function
  that acts on the environment or the NN itself. An actuator might have incoming
  connections from multiple neurons, in which case it would wait until all neurons
  have sent their output signals, accumulate these signals into a vector, and then
  use this vector as a parameter to its actuation function.
  
  The order in which the signals are accumulated into a vector is the same order
  as the neuron ids are stored. Once all signals have been gathered, the actuator
  executes its function, waits for its fitness score from the scape, sends the
  cortex the sync signal, and then again begins to wait for neural signals.
  """

  require Logger
  alias Bardo.Utils

  @doc """
  Callback to initialize the actuator module state.
  """
  @callback init(list()) :: {:ok, any()}

  @doc """
  Callback to actuate based on received signals.
  """
  @callback actuate(atom(), {agent_id :: tuple(), output :: [float()],
    params :: any(), vl :: non_neg_integer(), scape :: pid() | atom(),
    actuator :: pid() | tuple(), mod_state :: any()}) :: any()

  @doc """
  Optional callback for cleanup when terminating.
  """
  @callback terminate(reason :: atom(), mod_state :: any()) :: :ok
  @optional_callbacks [terminate: 2]

  @doc """
  Spawns an Actuator process belonging to the exoself process that spawned it
  and calls init to initialize.
  """
  @spec start(node(), pid()) :: pid()
  def start(node, exoself_pid) do
    if node == Node.self() do
      spawn_link(fn -> __MODULE__.init(exoself_pid) end)
    else
      Node.spawn_link(node, fn -> __MODULE__.init(exoself_pid) end)
    end
  end

  @doc """
  Terminates the actuator.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end

  @doc """
  Initializes the actuator setting it to its initial state.
  """
  @spec init_phase2(pid(), pid(), tuple(), tuple(), pid(), pid(),
    {atom(), atom()}, integer(), any(), [pid()], atom()) :: :ok
  def init_phase2(pid, exoself_pid, id, agent_id, cx_pid, scape, a_name, vl, params, fanin_pids, op_mode) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, agent_id, cx_pid, scape, a_name, vl, params,
      fanin_pids, op_mode}})
    :ok
  end

  @doc """
  The fitness score from the scape after the actuator has performed an action.
  """
  @spec fitness(pid(), {[float()], integer() | atom()}) :: :ok
  def fitness(actuator_pid, {fitness, halt_flag}) do
    send(actuator_pid, {:handle, {:fitness, {fitness, halt_flag}}})
    :ok
  end

  @doc """
  Initializes the actuator process.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Process.flag(:trap_exit, true)
    Logger.debug("[actuator] init: ok")
    loop(exoself_pid)
  end

  @doc """
  Main loop to handle initialization message.
  """
  @spec loop(pid()) :: no_return()
  def loop(exoself_pid) do
    receive do
      {:handle, {:init_phase2, ^exoself_pid, id, agent_id, cx_pid, scape, a_name, vl, params,
      fanin_pids, op_mode}} ->
        new_state = handle(:init_phase2, {id, agent_id, scape, a_name, vl, params})
        loop(new_state, exoself_pid, cx_pid, {fanin_pids, fanin_pids}, [], op_mode)
    end
  end

  @doc """
  Loop that handles actuator operations after initialization.
  """
  def loop(state, exoself_pid, cx_pid, {[from_pid | fanin_pids], m_fanin_pids}, acc, op_mode) do
    receive do
      {:forward, ^from_pid, input} ->
        Logger.debug("[actuator] msg: forward received from #{inspect(from_pid)}")
        loop(state, exoself_pid, cx_pid, {fanin_pids, m_fanin_pids}, Enum.concat(input, acc), op_mode)
      
      {:EXIT, _pid, :normal} ->
        :ignore
      
      {:EXIT, pid, reason} ->
        Logger.debug("[actuator] msg: exit received from #{inspect(pid)}, reason: #{inspect(reason)}")
        terminate(reason, state)
      
      {^exoself_pid, :stop} ->
        terminate(:normal, state)
    end
  end

  def loop(state, exoself_pid, cx_pid, {[], m_fanin_pids}, acc, op_mode) do
    a_name = state.name
    actuator_id = state.id
    mod_state = state.mod_state
    params = state.params
    vl = state.vl
    scape = state.scape
    agent_id = state.agent_id
    
    new_mod_state = handle(:actuate, {agent_id, cx_pid, acc, a_name, params, vl, scape, actuator_id, mod_state})
    
    receive do
      {:handle, {:fitness, {fitness, halt_flag}}} ->
        handle(:fitness, {fitness, halt_flag, cx_pid, op_mode})
        loop(%{state | mod_state: new_mod_state}, exoself_pid,
          cx_pid, {m_fanin_pids, m_fanin_pids}, [], op_mode)
    after 30000 ->
      Logger.warning("[actuator] msg: error - fitness not received")
    end
  end

  @doc """
  Terminates the actuator process with the given reason.
  """
  @spec terminate(atom(), map()) :: no_return()
  def terminate(reason, state) do
    {mod, _name} = state.name
    
    if function_exported?(mod, :terminate, 2) do
      module = Utils.get_module(mod)
      module.terminate(reason, state.mod_state)
    end
    
    Logger.debug("[actuator] terminate: #{inspect(reason)}")
    exit(reason)
  end

  # Internal functions

  defp handle(:init_phase2, {id, agent_id, scape, {mod, name}, vl, params}) do
    module = Utils.get_module(mod)
    {:ok, mod_state} = module.init([])
    Logger.debug("[actuator] init2: ok")
    
    %{
      id: id,
      agent_id: agent_id,
      scape: scape,
      name: {mod, name},
      mod_state: mod_state,
      vl: vl,
      params: params
    }
  end

  defp handle(:actuate, {agent_id, cx_pid, acc, {mod, name}, params, vl, scape, a_id, mod_state}) do
    Logger.debug("[actuator] actuate: actuating to #{inspect(cx_pid)}")
    module = Utils.get_module(mod)
    module.actuate(name, {agent_id, Enum.reverse(acc), params, vl, scape, a_id, mod_state})
  end

  defp handle(:fitness, {fitness, halt_flag, cx_pid, _op_mode}) do
    Logger.debug("[actuator] fitness: syncing with #{inspect(cx_pid)}")
    Bardo.AgentManager.Cortex.sync(cx_pid, self(), fitness, halt_flag)
  end
end