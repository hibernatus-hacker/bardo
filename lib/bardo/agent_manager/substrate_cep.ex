defmodule Bardo.AgentManager.SubstrateCEP do
  @moduledoc """
  The substrate polls the substrate_cpps (Substrate Coordinate PreProcessor), and then waits for the signals from the
  substrate_ceps (Substrate Connectivity Expression Producer) process, which tells it what the synaptic weight is between
  the two neurodes with which the substrate_cpps were called with, and whether the connection between these neurodes is
  expressed or not.
  
  The substrate_cpp and substrate_cep processes are analogous to the sensors and actuators respectively, but
  driven and polled by the substrate when it wishes to calculate the synaptic weights and connectivity expression
  between its various neurodes.
  
  The substrate will forward to its one or more substrate_cpps the coordinates of the two connected neurodes in question,
  the called substrate_cpp will process those coordinates based on its type and forward the processed vector to the NN. The
  substrate will then wait for the signals from its one or more substrate_ceps, which will provide it with the various signals
  which the substrate will then use to set its synaptic weights, connectivity expressions, or even plasticity based synaptic
  weight updates.
  
  The substrate uses its substrate_cpps and substrate_ceps for every synaptic weight/expression it wishes to set or update. Unlike the
  sensors and actuators, the substrate_cpps and substrate_ceps do not need to sync up with the cortex because the substrate_cpps are
  not be triggered by the cortex, and because the signals from substrate_ceps are awaited by the substrate, and since the substrate
  itself only processes signals once it has received all the sensory signals from the sensors which themselves are triggered by the cortex,
  the whole system is synchronized.
  """
  
  require Logger
  alias Bardo.{Utils, Functions}
  
  @doc """
  Spawns a SubstrateCEP process belonging to the exoself process that
  spawned it and calls init to initialize.
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
  Terminates the SubstrateCEP.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end
  
  @doc """
  Initializes the substrate_cep.
  """
  @spec init_phase2(pid(), pid(), any(), pid(), pid(), atom(), [float()], [pid()]) :: :ok
  def init_phase2(pid, exoself_pid, id, cx_pid, substrate_pid, cep_name, parameters, fanin_pids) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, cx_pid, substrate_pid,
      cep_name, parameters, fanin_pids}})
    :ok
  end
  
  @doc """
  The neurons in the output layer of the NN produce output signals,
  which are then sent to the CEPs they are connected to.
  The CEPs wait and gather the signals from all the neurons with whom
  they have presynaptic links. The CEPs process the accumulated signals.
  The CEPs forward the vector signals to the substrate.
  """
  @spec forward(pid(), pid(), [float()]) :: :ok
  def forward(pid, i_pid, input) do
    send(pid, {:handle, {:forward, i_pid, input}})
    :ok
  end
  
  @doc """
  Whenever a SubstrateCEP process is started via the start function this
  function is called by the new process to initialize.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Utils.random_seed()
    Logger.debug("[substrate_cep] init: ok")
    loop(exoself_pid)
  end
  
  @doc """
  Receive and handle messages.
  """
  @spec loop(pid()) :: no_return()
  def loop(exoself_pid) do
    receive do
      {:handle, {:init_phase2, ^exoself_pid, id, cx_pid, substrate_pid, cep_name, parameters, fanin_pids}} ->
        loop(id, exoself_pid, cx_pid, substrate_pid, cep_name, parameters, {fanin_pids, fanin_pids}, [])
    end
  end
  
  @doc """
  The substrate_cep process gathers the control signals from the
  neurons, appending them to the accumulator. The order in which the
  signals are accumulated into a vector is in the same order that the
  neuron ids are stored within NIds. Once all the signals have been
  gathered, the substrate_cep executes its function, forwards the
  processed signal to the substrate, and then again begins to wait
  for the neural signals from the output layer by reseting the
  FaninPids from the second copy of the list.
  """
  def loop(id, exoself_pid, cx_pid, substrate_pid, cep_name,
      parameters, {[from_pid | fanin_pids], m_fanin_pids}, acc) do
    receive do
      {:handle, {:forward, ^from_pid, input}} ->
        Logger.debug("[substrate_cep] msg: SIPid forward message received from #{inspect(from_pid)}")
        loop(id, exoself_pid, cx_pid, substrate_pid, cep_name, parameters, {fanin_pids, m_fanin_pids},
          input ++ acc)
      {:forward, ^from_pid, input} ->
        Logger.debug("[substrate_cep] msg: SIPid forward message received from #{inspect(from_pid)}")
        loop(id, exoself_pid, cx_pid, substrate_pid, cep_name, parameters, {fanin_pids, m_fanin_pids},
          input ++ acc)
      {^exoself_pid, :stop} ->
        terminate(:normal)
    end
  end
  
  def loop(id, exoself_pid, cx_pid, substrate_pid, cep_name, parameters, {[], m_fanin_pids}, acc) do
    properly_ordered_input = Enum.reverse(acc)
    
    case cep_name do
      :set_weight ->
        set_weight(properly_ordered_input, parameters, substrate_pid)
      :set_abcn ->
        set_abcn(properly_ordered_input, parameters, substrate_pid)
      :delta_weight ->
        delta_weight(properly_ordered_input, parameters, substrate_pid)
    end
    
    loop(id, exoself_pid, cx_pid, substrate_pid, cep_name, parameters, {m_fanin_pids, m_fanin_pids}, [])
  end
  
  @doc """
  This function is called to terminate the process. It performs
  any necessary cleaning up before exiting with the reason
  parameter that it was called with.
  """
  @spec terminate(atom()) :: no_return()
  def terminate(reason) do
    Logger.debug("[substrate_cep] terminate: #{inspect(reason)}")
    exit(reason)
  end
  
  # Internal functions
  
  defp set_weight(output, _parameters, substrate_pid) do
    [val] = output
    threshold = 0.33
    weight = calc_weight(val, threshold)
    Bardo.AgentManager.Substrate.set_weight(substrate_pid, self(), [weight])
  end
  
  defp set_abcn(output, _parameters, substrate_pid) do
    Bardo.AgentManager.Substrate.set_abcn(substrate_pid, self(), output)
  end
  
  defp delta_weight(output, _parameters, substrate_pid) do
    [val] = output
    threshold = 0.33
    dw = calc_weight(val, threshold)
    Bardo.AgentManager.Substrate.set_iterative(substrate_pid, self(), [dw])
  end
  
  defp calc_weight(val, threshold) do
    cond do
      val > threshold ->
        (Functions.scale(val, 1.0, threshold) + 1.0) / 2.0
      val < -threshold ->
        (Functions.scale(val, -threshold, -1.0) - 1.0) / 2.0
      true ->
        0.0
    end
  end
end