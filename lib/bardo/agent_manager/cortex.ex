defmodule Bardo.AgentManager.Cortex do
  @moduledoc """
  The Cortex is the central coordination element of a neural network agent.
  
  ## Overview
  
  The Cortex manages the synchronization and communication between all components of
  a neural network agent:
  
  * **Sensors**: Receive information from the environment
  * **Neurons**: Process information through activation functions
  * **Actuators**: Act on the environment based on neural outputs
  
  It orchestrates the sense-think-act cycle by:
  1. Triggering sensors to gather input from the environment
  2. Coordinating the forward propagation of signals through the neural network
  3. Ensuring actuators receive their control signals to interact with the environment
  4. Managing the timing and synchronization of the entire process
  
  ## Key Responsibilities
  
  * **Network Coordination**: Ensures all neurons, sensors, and actuators operate in coordination
  * **Cycle Management**: Controls the timing of sensing, processing, and acting phases
  * **Message Routing**: Directs signals between appropriate network components
  * **State Management**: Maintains the state of the neural network across operational cycles
  
  ## Implementation Details
  
  Each Cortex is implemented as an Erlang process that communicates with other processes
  (sensors, neurons, actuators) through message passing. This leverages the BEAM VM's
  concurrency model for efficient parallel processing across the neural network.
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
    if node == Node.self() do
      spawn_link(fn -> __MODULE__.init(exoself_pid) end)
    else
      Node.spawn_link(node, fn -> __MODULE__.init(exoself_pid) end)
    end
  end
  
  @doc """
  Creates a neural network (cortex) from a genotype.
  
  This is a simplified implementation for basic examples and testing.
  It creates an in-memory neural network without spawning processes.
  """
  @spec from_genotype(map()) :: map()
  def from_genotype(genotype) do
    neurons = genotype.neurons || %{}
    connections = genotype.connections || %{}
    
    # Create a simple neural network representation
    %{
      neurons: neurons,
      connections: connections,
      type: :feed_forward,
      state: :ready
    }
  end
  
  @doc """
  Activates a neural network with the given inputs.
  
  This is a simplified implementation for basic examples and testing.
  """
  @spec activate(map(), [float()]) :: [float()]
  def activate(nn, inputs) do
    # Get input, hidden, and output neurons
    input_neurons = filter_neurons_by_layer(nn.neurons, :input)
    bias_neurons = filter_neurons_by_layer(nn.neurons, :bias)
    hidden_neurons = filter_neurons_by_layer(nn.neurons, :hidden)
    output_neurons = filter_neurons_by_layer(nn.neurons, :output)
    
    # Set input values
    neuron_values = 
      # Set input neurons to input values
      Enum.zip(input_neurons, inputs)
      |> Enum.map(fn {{id, _neuron}, value} -> {id, value} end)
      |> Map.new()
      
    # Set bias neurons to 1.0
    neuron_values = 
      Enum.reduce(bias_neurons, neuron_values, fn {id, _neuron}, acc ->
        Map.put(acc, id, 1.0)
      end)
      
    # Calculate hidden layer values
    neuron_values = 
      calculate_layer_values(hidden_neurons, neuron_values, nn.connections)
      
    # Calculate output layer values
    neuron_values = 
      calculate_layer_values(output_neurons, neuron_values, nn.connections)
      
    # Return output values in order
    Enum.map(output_neurons, fn {id, _neuron} -> Map.get(neuron_values, id, 0.0) end)
  end
  
  # Filter neurons by layer
  defp filter_neurons_by_layer(neurons, layer) do
    Enum.filter(neurons, fn {_id, neuron} -> neuron.layer == layer end)
  end
  
  # Calculate values for a layer of neurons
  defp calculate_layer_values(neurons, values, connections) do
    Enum.reduce(neurons, values, fn {neuron_id, neuron}, acc ->
      # Find connections to this neuron
      incoming_connections = 
        Enum.filter(connections, fn {_id, connection} -> 
          connection.to_id == neuron_id
        end)
        
      # Calculate weighted sum of inputs
      weighted_sum = 
        Enum.reduce(incoming_connections, 0.0, fn {_conn_id, connection}, sum ->
          from_id = connection.from_id
          weight = connection.weight
          input_value = Map.get(values, from_id, 0.0)
          sum + (input_value * weight)
        end)
        
      # Apply activation function
      output = apply_activation_function(weighted_sum, neuron.activation_function)
      
      # Add result to values map
      Map.put(acc, neuron_id, output)
    end)
  end
  
  # Apply activation function
  defp apply_activation_function(x, activation_function) do
    case activation_function do
      :sigmoid -> sigmoid(x)
      :tanh -> :math.tanh(x)
      :relu -> max(0, x)
      _ -> sigmoid(x) # Default to sigmoid
    end
  end
  
  # Sigmoid activation function
  defp sigmoid(x) do
    1.0 / (1.0 + :math.exp(-x))
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
  Sync the Cortex with an actuator, providing fitness and status.
  """
  @spec sync(pid(), pid(), [float()], 0 | 1 | :goal_reached) :: :ok
  def sync(cortex_pid, actuator_pid, fitness, e_flag) do
    send(cortex_pid, {:handle, {:sync, actuator_pid, fitness, e_flag}})
    :ok
  end
  
  @doc """
  Reactivate the Cortex after it's gone inactive.
  """
  @spec reactivate(pid(), pid()) :: :ok
  def reactivate(cortex_pid, exoself_pid) do
    send(cortex_pid, {:handle, {exoself_pid, :reactivate}})
    :ok
  end

  # Internal operation details
  # 
  # The Cortex's goal is to synchronize the NN system such that when
  # the actuators have received all their control signals, the sensors are
  # once again triggered to gather new sensory information. Thus the
  # cortex waits for the sync messages from the actuator PIDs in its
  # system, and once it has received all the sync messages, it triggers
  # the sensors and then drops back to waiting for a new set of sync
  # messages. The cortex stores 2 copies of the actuator PIDs: the APids,
  # and the MemoryAPids (MAPids). Once all the actuators have sent it the
  # sync messages, it can restore the APids list from the MAPids. Finally,
  # there is also the Step variable which decrements every time a full
  # cycle of Sense-Think-Act completes, once this reaches 0, the NN system
  # begins its termination and backup process.
  
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