defmodule Bardo.AgentManager.Sensor do
  @moduledoc """
  Defines generic sensor behavior.
  
  A sensor is a process that takes input from the environment, converts it into
  a signal, and then forwards this signal to the cortex neurons to which it is connected.
  """

  require Logger

  @doc """
  Callback to initialize the sensor module state.
  """
  @callback init(list()) :: {:ok, any()}

  @doc """
  Callback to sense input from the environment.
  """
  @callback sense(atom(), {agent_id :: tuple(), percept :: [float()],
    params :: any(), vl :: non_neg_integer(), sensor :: pid() | tuple(), 
    op_mode :: atom(), mod_state :: any()}) :: any()

  @doc """
  Callback to process percept data and generate output signals.
  """
  @callback percept(atom(), {percept :: [float()], agent_id :: tuple(),
    vl :: non_neg_integer(), params :: any(), mod_state :: any()}) :: {[float()], any()}

  @doc """
  Optional callback for cleanup when terminating.
  """
  @callback terminate(reason :: atom(), mod_state :: any()) :: :ok
  @optional_callbacks [terminate: 2]

  @doc """
  Spawns a Sensor process belonging to the exoself process that spawned it
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
  Terminates the sensor.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end

  @doc """
  Initializes the sensor setting it to its initial state.
  """
  @spec init_phase2(pid(), pid(), tuple(), tuple(), [pid()], pid(), pid(),
    {atom(), atom()}, integer(), any(), atom()) :: :ok
  def init_phase2(pid, exoself_pid, id, agent_id, fanout_pids, cx_pid, scape,
      s_name, vl, params, op_mode) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, agent_id, fanout_pids, cx_pid, scape,
      s_name, vl, params, op_mode}})
    :ok
  end

  @doc """
  Sends a perception from the environment to the sensor.
  
  For use in tests and simulations.
  """
  @spec percept(pid(), [float()]) :: :ok
  def percept(sensor_pid, percept) do
    send(sensor_pid, {:handle, {:percept, percept}})
    :ok
  end

  @doc """
  Syncs the sensor with the cortex.
  """
  @spec sync(pid(), pid()) :: :ok
  def sync(sensor_pid, cx_pid) do
    send(sensor_pid, {:handle, {:sync, cx_pid}})
    :ok
  end

  @doc """
  Initializes the sensor process.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Process.flag(:trap_exit, true)
    Logger.debug("[sensor] init: ok")
    loop(exoself_pid)
  end

  # Private functions
  
  defp loop(exoself_pid, state \\ nil) do
    receive do
      {:handle, {:init_phase2, exoself_pid, id, agent_id, fanout_pids, cx_pid, scape,
        {module, sensory_type}, vl, params, op_mode}} ->
        {:ok, mod_state} = apply(module, :init, [params])
        state = %{
          exoself_pid: exoself_pid,
          id: id,
          agent_id: agent_id,
          fanout_pids: fanout_pids,
          cx_pid: cx_pid,
          scape: scape,
          module: module,
          sensory_type: sensory_type,
          vl: vl,
          params: params,
          op_mode: op_mode,
          mod_state: mod_state
        }
        Logger.debug("[sensor] init_phase2: #{inspect(id)}")
        loop(exoself_pid, state)
      
      {:handle, {:sync, _cx_pid}} ->
        %{
          agent_id: agent_id,
          module: module,
          sensory_type: sensory_type,
          vl: vl,
          params: params,
          scape: scape,
          id: id,
          op_mode: op_mode,
          mod_state: mod_state
        } = state
        
        apply(module, :sense, [sensory_type, {agent_id, vl, params, scape, id, op_mode, mod_state}])
        loop(exoself_pid, state)

      {:handle, {:percept, percept}} ->
        %{
          agent_id: agent_id,
          fanout_pids: fanout_pids, 
          module: module,
          sensory_type: sensory_type,
          vl: vl,
          params: params,
          mod_state: mod_state
        } = state
        
        {output, new_mod_state} = apply(module, :percept, [sensory_type, {percept, agent_id, vl, params, mod_state}])
        
        # Send the output to each neuron in the fanout
        Enum.each(fanout_pids, fn n_pid -> 
          Bardo.AgentManager.Neuron.forward(n_pid, self(), output)
        end)
        
        loop(exoself_pid, %{state | mod_state: new_mod_state})
      
      {:handle, {:get_state, request_from}} ->
        send(request_from, {:state, state})
        loop(exoself_pid, state)
        
      {^exoself_pid, :stop} ->
        if state != nil and Map.has_key?(state, :module) and Map.has_key?(state, :mod_state) do
          module = Map.get(state, :module)
          mod_state = Map.get(state, :mod_state)
          
          if function_exported?(module, :terminate, 2) do
            apply(module, :terminate, [:normal, mod_state])
          end
        end
        exit(:normal)
        
      other ->
        Logger.debug("[sensor] unhandled message: #{inspect(other)}")
        loop(exoself_pid, state)
    end
  end
end