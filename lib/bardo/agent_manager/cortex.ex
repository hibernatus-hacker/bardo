defmodule Bardo.AgentManager.Cortex do
  @moduledoc """
  The Cortex is a neural network synchronizing element.
  
  It needs to know the PID of every sensor and actuator, so that it will know when all the
  actuators have received their control inputs, and that it's time for the sensors to again 
  gather and fanout sensory data to the neurons in the input layer.
  """
  
  require Logger
  alias Bardo.Logger, as: LogR
  alias Bardo.Utils
  
  @doc """
  Spawns a Cortex process belonging to the Exoself process that spawned it
  and calls init to initialize.
  """
  @spec start(node(), pid()) :: pid()
  def start(node, exoself_pid) do
    spawn_link(node, __MODULE__, :init, [exoself_pid])
  end
  
  @doc """
  Terminates the cortex.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end
  
  @doc """
  Initializes the cortex.
  """
  @spec init_phase2(pid(), pid(), tuple(), [pid()], [pid()], [pid()], atom()) :: :ok
  def init_phase2(pid, exoself_pid, id, s_pids, n_pids, a_pids, op_mode) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, s_pids, n_pids, a_pids, op_mode}})
    :ok
  end
  
  @doc """
  The Cortex's goal is to synchronize the NN system such that when
  the actuators have received all their control signals, the sensors are
  once again triggered to gather new sensory information. Thus the
  cortex waits for the sync messages from the actuator PIDs in its
  system, and once it has received all the sync messages, it triggers
  the sensors and then drops back to waiting for a new set of sync
  messages. The cortex stores 2 copies of the actuator PIDs: the APids,
  and the MemoryAPids (MAPids). Once all the actuators have sent it the
  sync messages, it can restore the APids list from the MAPids. Finally,
  there is also the Step variable which decrements every time a full
  cycle of Sense-Think-Act completes, once this reaches 0, the NN system
  begins its termination and backup process.
  """
  @spec sync(pid(), pid(), [float()], integer() | :goal_reached) :: :ok
  def sync(pid, a_pid, fitness, end_flag) do
    send(pid, {:handle, {:sync, a_pid, fitness, end_flag}})
    :ok
  end
  
  @doc """
  Reactivates the cortex resetting it to its initial state.
  """
  @spec reactivate(pid(), pid()) :: :ok
  def reactivate(pid, exoself_pid) do
    send(pid, {:handle, {exoself_pid, :reactivate}})
    :ok
  end
  
  @doc """
  Initialize the cortex process.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Utils.random_seed()
    LogR.debug({:cortex, :init, :ok, :undefined, []})
    loop(exoself_pid)
  end
  
  # State struct for Cortex
  defmodule State do
    @moduledoc false
    defstruct [
      :id,            # models:cortex_id()
      :spids,         # [pid()]
      :npids,         # [pid()]
      :start_time,    # integer()
      :goal_reached   # boolean()
    ]
    
    @type t :: %__MODULE__{
      id: tuple(),
      spids: [pid()],
      npids: [pid()],
      start_time: integer(),
      goal_reached: boolean()
    }
  end
  
  # Internal loop functions
  
  # Initial setup loop
  defp loop(exoself_pid) do
    receive do
      {:handle, {:init_phase2, ^exoself_pid, id, s_pids, n_pids, a_pids, op_mode}} ->
        new_state = handle(:init_phase2, {id, s_pids, n_pids})
        loop(new_state, exoself_pid, {a_pids, a_pids}, 1, 0, 0, :active, op_mode)
    end
  end
  
  # Main operational loop - with remaining actuators to sync
  defp loop(state, exoself_pid, {[a_pid | a_pids], ma_pids}, cycle_acc, fitness_acc, ef_acc, :active, op_mode) do
    receive do
      {:handle, {:sync, ^a_pid, fitness, e_flag}} ->
        u_fitness_acc = update_fitness_acc(fitness_acc, fitness, op_mode)
        
        case e_flag do
          :goal_reached ->
            LogR.info({:cortex, :status, :ok, "syncd - goal_reached", []})
            new_state = %{state | goal_reached: true}
            loop(new_state, exoself_pid, {a_pids, ma_pids}, cycle_acc, u_fitness_acc, ef_acc + 1, :active, op_mode)
            
          _ ->
            LogR.debug({:cortex, :msg, :ok, "syncd", []})
            loop(state, exoself_pid, {a_pids, ma_pids}, cycle_acc, u_fitness_acc, ef_acc + e_flag, :active, op_mode)
        end
        
      {^exoself_pid, :stop} ->
        terminate(:normal)
    end
  end
  
  # All actuators have synced
  defp loop(state, exoself_pid, {[], ma_pids}, cycle_acc, fitness_acc, ef_acc, :active, op_mode) do
    case ef_acc > 0 do
      true ->
        LogR.debug({:cortex, :msg, :ok, "all sync msgs received - evaluation finished", []})
        start_time = state.start_time
        goal_reached = state.goal_reached
        handle(:evaluation_complete, {exoself_pid, fitness_acc, cycle_acc, start_time, goal_reached})
        loop(state, exoself_pid, {ma_pids, ma_pids}, cycle_acc, fitness_acc, ef_acc, :inactive, op_mode)
        
      false ->
        LogR.debug({:cortex, :msg, :ok, "all sync msgs received - evaluation not finished", []})
        handle(:continue, state.spids)
        loop(state, exoself_pid, {ma_pids, ma_pids}, cycle_acc + 1, fitness_acc, ef_acc, :active, op_mode)
    end
  end
  
  # Inactive state waiting for reactivation
  defp loop(state, exoself_pid, {ma_pids, ma_pids}, _cycle_acc, _fitness_acc, _ef_acc, :inactive, op_mode) do
    receive do
      {:handle, {^exoself_pid, :reactivate}} ->
        handle(:reactivate, state.spids)
        LogR.debug({:cortex, :msg, :ok, "reactivated", []})
        start_time = :erlang.monotonic_time()
        new_state = %{state | start_time: start_time}
        loop(new_state, exoself_pid, {ma_pids, ma_pids}, 1, 0, 0, :active, op_mode)
        
      {^exoself_pid, :stop} ->
        terminate(:normal)
    end
  end
  
  # Handle functions for different operations
  
  defp handle(:init_phase2, {id, s_pids, n_pids}) do
    start_time = :erlang.monotonic_time()
    Enum.each(s_pids, &send(&1, {:sync, self()}))
    LogR.debug({:cortex, :init2, :ok, :undefined, []})
    
    %State{
      id: id,
      spids: s_pids,
      npids: n_pids,
      start_time: start_time,
      goal_reached: false
    }
  end
  
  defp handle(:evaluation_complete, {exoself_pid, fitness_acc, cycle_acc, start_time, goal_reached}) do
    time_dif = :erlang.monotonic_time() - start_time
    send(exoself_pid, {:evaluation_complete, self(), fitness_acc, cycle_acc, time_dif, goal_reached})
  end
  
  defp handle(:continue, s_pids) do
    Enum.each(s_pids, &send(&1, {:sync, self()}))
  end
  
  defp handle(:reactivate, s_pids) do
    Enum.each(s_pids, &send(&1, {:sync, self()}))
  end
  
  # Helper functions
  
  defp update_fitness_acc(fitness_acc, fitness, _op_mode) do
    vector_add(fitness, fitness_acc, [])
  end
  
  defp vector_add(la, 0, []), do: la
  
  defp vector_add([a | la], [b | lb], acc) do
    vector_add(la, lb, [a + b | acc])
  end
  
  defp vector_add([], [], acc) do
    Enum.reverse(acc)
  end
  
  defp terminate(reason) do
    LogR.debug({:cortex, :terminate, :ok, :undefined, []})
    exit(reason)
  end
end