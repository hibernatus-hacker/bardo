defmodule Bardo.AgentManager.Neuron do
  @moduledoc """
  The neuron is a signal processing element.
  
  It accepts signals, accumulates them into an ordered vector, then processes this input
  vector to produce an output, and finally passes the output to other elements it is 
  connected to. The neuron never interacts with the environment directly, and even when 
  it does receive signals and produces output signals, it does not know whether these 
  input signals are coming from sensors or neurons, or whether it is sending its output 
  signals to other neurons or actuators. 
  
  All the neuron does is have a list of input PIDs from which it expects to receive
  signals, a list of output PIDs to which the neuron sends its output, a weight list 
  correlated with the input PIDs, and an activation function it applies to the dot 
  product of the input vector and its weight vector. The neuron waits until it receives 
  all the input signals, and then passes the output onwards.
  
  NOTE: The neuron is the basic processing element, the basic processing node in the 
  neural network system. The neurons in this system are more general than those used 
  by others. They can easily use various activation functions, and accept and output 
  vectors. Because we can use anything for the activation function, including logical 
  operators, the neurons are really just processing nodes. In some sense, this system 
  is not a Topology and Weight Evolving Artificial Neural Network, but a Topology and 
  Parameter Evolving Universal Learning Network (TPEULN). Nevertheless, we will continue
  referring to these processing elements as neurons.
  """
  
  use GenServer
  require Logger
  alias Bardo.Logger, as: LogR
  alias Bardo.Functions
  alias Bardo.Utils
  alias Bardo.AppConfig
  alias Bardo.AgentManager.SignalAggregator
  alias Bardo.Plasticity
  
  # Define a constant for saturation limit
  @sat_limit :math.pi() * 2
  
  # Define a struct to represent neuron state
  defmodule State do
    @moduledoc """
    Struct representing the internal state of a neuron.
    """
    
    defstruct [
      :id,              # models:neuron_id()
      :cx_pid,          # pid()
      :af,              # models:neural_af()
      :aggr_f,          # atom()
      :heredity_type,   # :darwinian | :lamarckian
      :si_pids,         # [pid()] | [:ok]
      :si_pidps_current, # [{pid(), [float()]}]
      :si_pidps_bl,     # [{pid(), [float()]}]
      :si_pidps_backup, # [{pid(), [float()]}]
      :mi_pids,         # [pid()] | [:ok]
      :mi_pidps_current, # [{pid(), [float()]}]
      :mi_pidps_backup, # [{pid(), [float()]}]
      :pf_current,      # {models:neural_pfn(), [float()]}
      :pf_backup,       # {models:neural_pfn(), [float()]}
      :output_pids,     # [pid()]
      :ro_pids          # [pid()]
    ]
  end
  
  # Client API
  
  @doc """
  Spawns a Neuron process belonging to the Exoself process that spawned it
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
  Terminates neuron.
  """
  @spec stop(pid(), pid()) :: :ok
  def stop(pid, exoself_pid) do
    send(pid, {exoself_pid, :stop})
    :ok
  end
  
  @doc """
  Initializes the neuron setting it to its initial state.
  """
  @spec init_phase2(pid(), pid(), tuple(), pid(), atom(), {atom(), [float()]}, atom(), 
        atom(), [tuple()], [tuple()], [pid()], [pid()]) :: :ok
  def init_phase2(pid, exoself_pid, id, cx_pid, af, pf, aggr_f, heredity_type, 
                 si_pidps, mi_pidps, output_pids, ro_pids) do
    send(pid, {:handle, {:init_phase2, exoself_pid, id, cx_pid, af, pf, aggr_f, 
               heredity_type, si_pidps, mi_pidps, output_pids, ro_pids}})
    :ok
  end
  
  @doc """
  The Neuron process waits for vector signals from all the processes
  that it's connected from, taking the dot product of the input and
  weight vectors, and then adding it to the accumulator. Once all the
  signals from InputPids are received, the accumulator contains the
  dot product to which the neuron then adds the bias and executes the
  activation function. After fanning out the output signal, the neuron
  again returns to waiting for incoming signals.
  """
  @spec forward(pid(), pid(), float()) :: :ok
  def forward(pid, i_pid, input) do
    send(pid, {:handle, {:forward, i_pid, input}})
    :ok
  end
  
  @doc """
  Weight backup: The signal from the exoself, which tells the neuron
  that the NN system performs best when this particular neuron is using
  its current synaptic weight combination, and thus it should save this
  synaptic weight list as MInputPidPs, and that it is the best weight
  combination achieved thus far. The message is sent if after the weight
  perturbation, the NN's evaluation achieves a higher fitness than when
  the neurons of this NN used their previous synaptic weights.
  """
  @spec weight_backup(pid(), pid()) :: :ok
  def weight_backup(pid, exoself_pid) do
    send(pid, {:handle, {exoself_pid, :weight_backup}})
    :ok
  end
  
  @doc """
  Weight restore: This message is sent from the exoself, and it tells
  the neuron that it should restore its synaptic weight list to the one
  previously used, saved as MInputPidPs. This message is usually sent if
  after the weight perturbation, the NN based agent's evaluation performs
  worse than it did with its previous synaptic weight combinations.
  """
  @spec weight_restore(pid(), pid()) :: :ok
  def weight_restore(pid, exoself_pid) do
    send(pid, {:handle, {exoself_pid, :weight_restore}})
    :ok
  end
  
  @doc """
  Weight perturb: Uses the Spread value for the purpose of generating
  synaptic weight perturbations.
  """
  @spec weight_perturb(pid(), pid(), integer()) :: :ok
  def weight_perturb(pid, exoself_pid, spread) do
    send(pid, {:handle, {exoself_pid, :weight_perturb, spread}})
    :ok
  end
  
  @doc """
  Reset prep: This message is sent after a single evaluation is completed,
  and the exoself wishes to reset all the neurons to their original states,
  with empty inboxes. Once a neuron receives this message, it goes into a
  reset_prep state, flushes its buffer/inbox, and then awaits for the
  {ExoselfPid, reset} signal. When the neuron receives the {ExoselfPid, reset}
  message, it again sends out the default output message to all its recurrent
  connections (Ids stored in the ro_ids list), and then finally drops back
  into its main receive loop.
  """
  @spec reset_prep(pid(), pid()) :: :ok
  def reset_prep(pid, exoself_pid) do
    send(pid, {:handle, {exoself_pid, :reset_prep}})
    :ok
  end
  
  @doc """
  Get backup: neuron sends back to the exoself its last best synaptic
  weight combination, stored as the MInputPids list.
  """
  @spec get_backup(pid(), pid()) :: :ok
  def get_backup(pid, exoself_pid) do
    send(pid, {:handle, {exoself_pid, :get_backup}})
    :ok
  end
  
  @doc """
  Perturb plasticity function: perturbs the plasticity function.
  """
  @spec perturb_pf(float(), {atom(), [float()]}) :: {atom(), [float()]}
  def perturb_pf(spread, {pf_name, pf_parameters}) do
    do_perturb_pf(spread, {pf_name, pf_parameters})
  end
  
  @doc """
  The perturb_weights_p function is the function that actually goes
  through each weight block, and perturbs each weight with a
  probability of MP. If the weight is chosen to be perturbed, the
  perturbation intensity is chosen uniformly between -Spread and
  Spread.
  """
  @spec perturb_weights_p(float(), float(), [{float(), [float()]}], [float()]) :: [float()]
  def perturb_weights_p(spread, mp, [{w, lps} | weights], acc) do
    do_perturb_weights_p(spread, mp, [{w, lps} | weights], acc)
  end
  
  # Server Callbacks
  
  @doc """
  Initialize the neuron process.
  """
  @spec init(pid()) :: no_return()
  def init(exoself_pid) do
    Utils.random_seed()
    LogR.debug({:neuron, :init, :ok, :undefined, []})
    loop(exoself_pid)
  end
  
  @doc """
  Main process loop during initialization.
  """
  @spec loop(pid()) :: no_return()
  def loop(exoself_pid) do
    receive do
      {:handle, {:init_phase2, ^exoself_pid, id, cx_pid, af, pf, aggr_f, heredity_type, 
                 si_pidps, mi_pidps, output_pids, ro_pids}} ->
        si_pids = append_ipids(si_pidps)
        mi_pids = append_ipids(mi_pidps)
        new_state = handle(:init_phase2, {id, cx_pid, af, pf, aggr_f, heredity_type, 
                          si_pidps, mi_pidps, output_pids, ro_pids, si_pids, mi_pids})
        loop(new_state, exoself_pid, si_pids, mi_pids, [], [])
    end
  end
  
  @doc """
  Main process loop after initialization.
  """
  @spec loop(State.t(), pid(), [:ok] | [pid()], [:ok] | [pid()], [{pid(), [float()]}] | [], 
             [{pid(), [float()]}] | []) :: no_return()
  def loop(state, exoself_pid, [:ok], [:ok], si_acc, mi_acc) do
    new_state = handle(:forward_output, {si_acc, mi_acc, state})
    si_pids = new_state.si_pids
    mi_pids = new_state.mi_pids
    loop(new_state, exoself_pid, si_pids, mi_pids, [], [])
  end
  
  def loop(state, exoself_pid, [si_pid | si_pids], [mi_pid | mi_pids], si_acc, mi_acc) do
    receive do
      {:handle, {:forward, ^si_pid, input}} ->
        LogR.debug({:neuron, :msg, :ok, "SIPid forward message received", [si_pid]})
        loop(state, exoself_pid, si_pids, [mi_pid | mi_pids], [{si_pid, input} | si_acc], mi_acc)
        
      {:handle, {:forward, ^mi_pid, input}} ->
        LogR.debug({:neuron, :msg, :ok, "MIPid forward message received", [mi_pid]})
        loop(state, exoself_pid, [si_pid | si_pids], mi_pids, si_acc, [{mi_pid, input} | mi_acc])
        
      {:forward, ^si_pid, input} ->
        LogR.debug({:neuron, :msg, :ok, "SIPid forward message received", [si_pid]})
        loop(state, exoself_pid, si_pids, [mi_pid | mi_pids], [{si_pid, input} | si_acc], mi_acc)
        
      {:forward, ^mi_pid, input} ->
        LogR.debug({:neuron, :msg, :ok, "MIPid forward message received", [mi_pid]})
        loop(state, exoself_pid, [si_pid | si_pids], mi_pids, si_acc, [{mi_pid, input} | mi_acc])
        
      {:handle, {^exoself_pid, :weight_backup}} ->
        new_state = handle(:weight_backup, state)
        loop(new_state, exoself_pid, [si_pid | si_pids], [mi_pid | mi_pids], si_acc, mi_acc)
        
      {:handle, {^exoself_pid, :weight_restore}} ->
        new_state = handle(:weight_restore, state)
        loop(new_state, exoself_pid, [si_pid | si_pids], [mi_pid | mi_pids], si_acc, mi_acc)
        
      {:handle, {^exoself_pid, :weight_perturb, spread}} ->
        new_state = handle(:weight_perturb, {state, spread})
        loop(new_state, exoself_pid, [si_pid | si_pids], [mi_pid | mi_pids], si_acc, mi_acc)
        
      {:handle, {^exoself_pid, :reset_prep}} ->
        flush_buffer()
        send(exoself_pid, {self(), :ready})
        ro_pids = state.ro_pids
        
        receive do
          {^exoself_pid, :reset} ->
            LogR.debug({:neuron, :reset, :ok, "Fanning out ROPids", [ro_pids]})
            fanout(ro_pids)
            
          {^exoself_pid, :stop} ->
            terminate(:normal)
        end
        
        loop(state, exoself_pid, state.si_pids, state.mi_pids, [], [])
        
      {:handle, {^exoself_pid, :get_backup}} ->
        handle(:get_backup, {state, exoself_pid})
        loop(state, exoself_pid, [si_pid | si_pids], [mi_pid | mi_pids], si_acc, mi_acc)
        
      {^exoself_pid, :stop} ->
        terminate(:normal)
    end
  end
  
  @doc """
  Terminate the neuron process.
  """
  @spec terminate(atom()) :: :ok
  def terminate(reason) do
    LogR.debug({:neuron, :terminate, :ok, :undefined, [reason]})
    exit(reason)
  end
  
  # Internal functions
  
  @doc false
  def handle(:init_phase2, {id, cx_pid, af, pf, aggr_f, heredity_type, si_pidps, mi_pidps, 
                           output_pids, ro_pids, si_pids, mi_pids}) do
    fanout(ro_pids)
    LogR.debug({:neuron, :init2, :ok, :undefined, []})
    
    %State{
      id: id,
      cx_pid: cx_pid,
      af: af,
      pf_current: pf,
      pf_backup: pf,
      aggr_f: aggr_f,
      heredity_type: heredity_type,
      si_pids: si_pids,
      si_pidps_bl: si_pidps,
      si_pidps_current: si_pidps,
      si_pidps_backup: si_pidps,
      mi_pids: mi_pids,
      mi_pidps_current: mi_pidps,
      mi_pidps_backup: mi_pidps,
      output_pids: output_pids,
      ro_pids: ro_pids
    }
  end
  
  def handle(:forward_output, {si_acc, mi_acc, state}) do
    output_sat_limit = AppConfig.get_env(:output_sat_limit)
    {pf_name, pf_parameters} = state.pf_current
    af = state.af
    aggr_f = state.aggr_f
    ordered_si_acc = Enum.reverse(si_acc)
    si_pidps = state.si_pidps_current
    
    # Apply the activation function to the aggregated signal
    s_output = [
      sat(apply(Functions, af, [SignalAggregator.apply(aggr_f, ordered_si_acc, si_pidps)]), 
          output_sat_limit)
    ]
    
    new_state = case pf_name do
      :none ->
        state
        
      _ ->
        ordered_mi_acc = Enum.reverse(mi_acc)
        mi_pidps = state.mi_pidps_current
        m_aggregation_product = SignalAggregator.dot_product(ordered_mi_acc, mi_pidps)
        m_output = sat(Functions.tanh(m_aggregation_product), @sat_limit)
        u_si_pidps = apply(Plasticity, pf_name, [[m_output | pf_parameters], ordered_si_acc, 
                                                si_pidps, s_output])
        %{state | si_pidps_current: u_si_pidps}
    end
    
    # Fan out to output PIDs
    Enum.each(state.output_pids, fn output_pid -> 
      send(output_pid, {:forward, self(), s_output})
    end)
    
    LogR.debug({:neuron, :forward_output, :ok, :undefined, []})
    new_state
  end
  
  def handle(:weight_backup, state) do
    new_state = case state.heredity_type do
      :darwinian ->
        %{state | 
          si_pidps_backup: state.si_pidps_bl,
          mi_pidps_backup: state.mi_pidps_current,
          pf_backup: state.pf_current
        }
        
      :lamarckian ->
        %{state | 
          si_pidps_backup: state.si_pidps_current,
          mi_pidps_backup: state.mi_pidps_current,
          pf_backup: state.pf_current
        }
    end
    
    LogR.debug({:neuron, :weight_backup, :ok, :undefined, []})
    new_state
  end
  
  def handle(:weight_restore, state) do
    new_state = %{state | 
      si_pidps_bl: state.si_pidps_backup,
      si_pidps_current: state.si_pidps_backup,
      mi_pidps_current: state.mi_pidps_backup,
      pf_current: state.pf_backup
    }
    
    LogR.debug({:neuron, :weight_restore, :ok, :undefined, []})
    new_state
  end
  
  def handle(:weight_perturb, {state, spread}) do
    perturbed_si_pidps = perturb_ipidps(spread, state.si_pidps_backup)
    perturbed_mi_pidps = perturb_ipidps(spread, state.mi_pidps_backup)
    perturbed_pf = perturb_pf(spread, state.pf_backup)
    
    new_state = %{state |
      si_pidps_bl: perturbed_si_pidps,
      si_pidps_current: perturbed_si_pidps,
      mi_pidps_current: perturbed_mi_pidps,
      pf_current: perturbed_pf
    }
    
    LogR.debug({:neuron, :weight_perturb, :ok, :undefined, []})
    new_state
  end
  
  def handle(:get_backup, {state, exoself_pid}) do
    n_id = state.id
    send(exoself_pid, {self(), n_id, state.si_pidps_backup, 
                      state.mi_pidps_backup, state.pf_backup})
    LogR.debug({:neuron, :get_backup, :ok, :undefined, []})
  end
  
  @doc false
  def do_perturb_pf(spread, {pf_name, pf_parameters}) do
    u_pf_parameters = Enum.map(pf_parameters, fn pf_parameter ->
      sat(pf_parameter + (:rand.uniform() - 0.5) * spread, -@sat_limit, @sat_limit)
    end)
    
    {pf_name, u_pf_parameters}
  end
  
  @doc false
  def append_ipids(i_pidps) do
    i_pidps
    |> Enum.filter(fn 
         {:bias, _} -> false
         _ -> true
       end)
    |> Enum.map(fn {i_pid, _} -> i_pid end)
    |> Kernel.++([:ok])
  end
  
  @doc false
  def perturb_ipidps(_spread, []), do: []
  
  def perturb_ipidps(spread, input_pidps) do
    tot_weights = Enum.sum(for {_input_pid, weights_p} <- input_pidps, do: length(weights_p))
    mp = 1 / :math.sqrt(tot_weights)
    perturb_ipidps(spread, mp, input_pidps, [])
  end
  
  @doc false
  def perturb_ipidps(spread, mp, [{input_pid, weights_p} | input_pidps], acc) do
    u_weights_p = do_perturb_weights_p(spread, mp, weights_p, [])
    perturb_ipidps(spread, mp, input_pidps, [{input_pid, u_weights_p} | acc])
  end
  
  def perturb_ipidps(_spread, _mp, [], acc), do: Enum.reverse(acc)
  
  @doc false
  def do_perturb_weights_p(spread, mp, [{w, lps} | weights], acc) do
    u_w = if :rand.uniform() < mp do
      sat((:rand.uniform() - 0.5) * 2 * spread + w, -@sat_limit, @sat_limit)
    else
      w
    end
    
    do_perturb_weights_p(spread, mp, weights, [{u_w, lps} | acc])
  end
  
  def do_perturb_weights_p(_spread, _mp, [], acc), do: Enum.reverse(acc)
  
  @doc false
  def fanout([pid | pids]) do
    ro_signal = AppConfig.get_env(:ro_signal)
    send(pid, {:forward, self(), ro_signal})
    fanout(pids)
  end
  
  def fanout([]), do: true
  
  @doc false
  def flush_buffer do
    receive do
      _ -> flush_buffer()
    after
      0 -> :done
    end
  end
  
  @doc false
  def sat(val, limit), do: sat(val, -limit, limit)
  
  def sat(val, min, _max) when val < min, do: min
  def sat(val, _min, max) when val > max, do: max
  def sat(val, _min, _max), do: val
end