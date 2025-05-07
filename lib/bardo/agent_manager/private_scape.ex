defmodule Bardo.AgentManager.PrivateScape do
  @moduledoc """
  Defines generic private scape behavior.
  
  Scapes are self contained simulated worlds or virtual environments,
  that is, they are not necessarily physical. They can be thought of as
  a way of interfacing with the problem in question. Scapes are composed
  of two parts, a simulation of an environment or a problem we are
  applying the NN to, and a function that can keep track of the NN's
  performance. Scapes run outside the NN systems, as independent
  processes with which the NNs interact using their sensors and
  actuators. There are two types of scapes. One type of scape, private,
  is spawned for each NN during the NN's creation, and destroyed when
  that NN is taken offline. Another type of scape, public, is
  persistent, they exist regardless of the NNs, and allow multiple NNs
  to interact with them at the same time, and thus they can allow those
  NNs to interact with each other too. This module defines the private
  scape.
  """
  
  use GenServer
  require Logger
  alias Bardo.Utils
  alias Bardo.AgentManager.{Sensor, Actuator}
  
  # Behavior callbacks
  
  @doc """
  Callback to initialize the private scape module state.
  """
  @callback init(params :: any()) :: {:ok, mod_state :: any()}
  
  @doc """
  Callback to sense input from the environment.
  """
  @callback sense(params :: any(), state :: any()) ::
    {result :: atom() | [float()], new_mod_state :: any()}
  
  @doc """
  Callback to actuate on the environment.
  """
  @callback actuate(function :: atom(), params :: any(), agent_id :: tuple(), state :: any()) ::
    {result :: {[float()], integer() | atom()}, new_mod_state :: any()}
  
  @doc """
  Optional callback for cleanup when terminating.
  """
  @callback terminate(reason :: atom(), mod_state :: any()) :: :ok
  @optional_callbacks [terminate: 2]
  
  # API
  
  @doc """
  Spawns the PrivateScape process.
  """
  @spec start_link(tuple(), atom()) :: {:ok, pid()}
  def start_link(agent_id, mod) do
    GenServer.start_link(__MODULE__, {agent_id, mod}, [])
  end
  
  @doc """
  Gathers sensory inputs from the environment.
  """
  @spec sense(pid(), tuple(), pid(), any()) :: :ok
  def sense(pid, agent_id, sensor_pid, params) do
    GenServer.cast(pid, {:sense, agent_id, sensor_pid, params})
    :ok
  end
  
  @doc """
  Performs various PrivateScape functions e.g. move, push, etc. The scape
  API is problem dependent. This function provides an interface
  to call various functions defined by the PrivateScape in question.
  """
  @spec actuate(pid(), tuple(), pid(), atom(), any()) :: :ok
  def actuate(pid, agent_id, actuator_pid, function, params) do
    GenServer.cast(pid, {:actuate, agent_id, actuator_pid, function, params})
    :ok
  end
  
  # GenServer callbacks
  
  @impl GenServer
  def init({agent_id, mod}) do
    Process.flag(:trap_exit, true)
    Utils.random_seed()
    m = Utils.get_module(mod)
    {:ok, mod_state} = apply(m, :init, [[]])
    Logger.debug("[private_scape] init: ok, module: #{inspect(m)}")
    
    state = %{
      agent_id: agent_id,
      mod_name: m,
      mod_state: mod_state
    }
    
    {:ok, state}
  end
  
  @impl GenServer
  def handle_call(_request, _from, state) do
    Logger.warning("[private_scape] unexpected handle_call")
    {:reply, :ok, state}
  end
  
  @impl GenServer
  def handle_cast({:sense, _agent_id, sensor_pid, params}, state) do
    new_state = do_sense(params, sensor_pid, state)
    {:noreply, new_state}
  end
  
  def handle_cast({:actuate, agent_id, actuator_pid, function, params}, state) do
    new_state = do_actuate(function, params, agent_id, actuator_pid, state)
    {:noreply, new_state}
  end
  
  @impl GenServer
  def terminate(reason, state) do
    Logger.debug("[private_scape] terminate: #{inspect(reason)}")
    mod = state.mod_name
    
    if function_exported?(mod, :terminate, 2) do
      apply(mod, :terminate, [reason, state.mod_state])
    else
      :ok
    end
  end
  
  # Internal functions
  
  defp do_sense(params, sensor_pid, state) do
    %{mod_name: mod, mod_state: mod_state} = state
    {result, new_mod_state} = apply(mod, :sense, [params, mod_state])
    Sensor.percept(sensor_pid, result)
    %{state | mod_state: new_mod_state}
  end
  
  defp do_actuate(function, params, agent_id, actuator_pid, state) do
    %{mod_name: mod, mod_state: mod_state} = state
    {result, new_mod_state} = apply(mod, :actuate, [function, params, agent_id, mod_state])
    Actuator.fitness(actuator_pid, result)
    %{state | mod_state: new_mod_state}
  end
end