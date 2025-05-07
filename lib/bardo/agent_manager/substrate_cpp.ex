defmodule Bardo.AgentManager.SubstrateCPP do
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
  alias Bardo.AgentManager.Neuron
  
  @doc """
  Spawns a SubstrateCPP process belonging to the exoself process that
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
  Terminates substrate_cpp.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end
  
  @doc """
  Initializes substrate_cpp.
  """
  @spec init_phase2(pid(), pid(), any(), pid(), pid(), atom(), integer(), [float()], [pid()]) :: :ok
  def init_phase2(pid, exoself_pid, id, cx_pid, substrate_pid, cpp_name, vl, parameters, fanout_pids) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, cx_pid, substrate_pid, cpp_name, vl,
      parameters, fanout_pids}})
    :ok
  end
  
  @doc """
  The substrate sends the coordinates of the connected neurodes to the
  substrate_cpps it is connected to. The CPPs process the coordinates.
  The CPPs forward the processed coordinate vectors to the neurons they
  are connected to in the NN. The NN processes the coordinate signals.
  """
  @spec neurode_coordinates(pid(), pid(), [float()], [float()]) :: :ok
  def neurode_coordinates(pid, substrate_pid, presynaptic_coords, postsynaptic_coords) do
    send(pid, {:handle, {:neurode_coordinates, substrate_pid, presynaptic_coords, postsynaptic_coords}})
    :ok
  end
  
  @doc """
  IOW = Input, Output and Weight.
  The substrate sends the coordinates of the connected neurodes to the
  substrate_cpps it is connected to. The CPPs process the coordinates.
  The CPPs forward the processed coordinate vectors to the neurons they
  are connected to in the NN. The NN processes the coordinate signals.
  """
  @spec neurode_coordinates_iow(pid(), pid(), [float()], [float()], [float()]) :: :ok
  def neurode_coordinates_iow(pid, substrate_pid, presynaptic_coords, postsynaptic_coords, iow) do
    send(pid, {:handle, {:neurode_coordinates, substrate_pid, presynaptic_coords, postsynaptic_coords, iow}})
    :ok
  end
  
  @doc """
  Whenever a SubstrateCPP process is started via the start function this
  function is called by the new process to initialize.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Utils.random_seed()
    Logger.debug("[substrate_cpp] init: ok")
    loop(exoself_pid)
  end
  
  @doc """
  Receive and handle messages.
  """
  @spec loop(pid()) :: no_return()
  def loop(exoself_pid) do
    receive do
      {:handle, {:init_phase2, ^exoself_pid, id, cx_pid, substrate_pid,
      cpp_name, vl, parameters, fanout_pids}} ->
        loop(id, exoself_pid, cx_pid, substrate_pid, cpp_name, vl, parameters, fanout_pids)
    end
  end
  
  @doc """
  Receive and handle messages.
  """
  def loop(id, exoself_pid, cx_pid, substrate_pid, cpp_name, vl, parameters, fanout_pids) do
    receive do
      {:handle, {:neurode_coordinates, ^substrate_pid, presynaptic_coords, postsynaptic_coords}} ->
        Logger.debug("[substrate_cpp] msg: neurode_coordinates: #{inspect(presynaptic_coords)}, #{inspect(postsynaptic_coords)}")
        handle(:neurode_coordinates, {cpp_name, fanout_pids, presynaptic_coords, postsynaptic_coords})
        loop(id, exoself_pid, cx_pid, substrate_pid, cpp_name, vl, parameters, fanout_pids)
      
      {:handle, {:neurode_coordinates, ^substrate_pid, presynaptic_coords, postsynaptic_coords, iow}} ->
        Logger.debug("[substrate_cpp] msg: neurode_coordinates_iow: #{inspect(presynaptic_coords)}, #{inspect(postsynaptic_coords)}")
        handle(:neurode_coordinates_iow, {cpp_name, fanout_pids, presynaptic_coords, postsynaptic_coords, iow})
        loop(id, exoself_pid, cx_pid, substrate_pid, cpp_name, vl, parameters, fanout_pids)
      
      {^exoself_pid, :stop} ->
        terminate(:normal)
    end
  end
  
  @doc """
  This function is called to terminate the process. It performs
  any necessary cleaning up before exiting with the reason
  parameter that it was called with.
  """
  @spec terminate(atom()) :: no_return()
  def terminate(reason) do
    Logger.debug("[substrate_cpp] terminate: #{inspect(reason)}")
    exit(reason)
  end
  
  # Internal functions
  
  defp handle(:neurode_coordinates, {cpp_name, fanout_pids, presynaptic_coords, postsynaptic_coords}) do
    sensory_vector = apply(Functions, cpp_name, [presynaptic_coords, postsynaptic_coords])
    Logger.debug("[substrate_cpp] neurode_coordinates: ok")
    
    Enum.each(fanout_pids, fn pid ->
      Neuron.forward(pid, self(), sensory_vector)
    end)
  end
  
  defp handle(:neurode_coordinates_iow, {cpp_name, fanout_pids, presynaptic_coords, postsynaptic_coords, iow}) do
    sensory_vector = apply(Functions, cpp_name, [presynaptic_coords, postsynaptic_coords, iow])
    Logger.debug("[substrate_cpp] neurode_coordinates_iow: ok")
    
    Enum.each(fanout_pids, fn pid ->
      Neuron.forward(pid, self(), sensory_vector)
    end)
  end
end