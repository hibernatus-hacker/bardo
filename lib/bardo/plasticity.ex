defmodule Bardo.Plasticity do
  @moduledoc """
  Contains plasticity functions for neural network learning.
  
  True learning is not achieved when a static NN is trained on some data set through 
  destruction and recreation by the exoself based on its performance, but instead is 
  the self organization of the NN, the self adaptation and changing of the NN based 
  on the information it is processing.
  
  The learning rule, the way in which the neurons adapt independently, the way in which 
  their synaptic weights change based on the neuron's experience, that is true learning, 
  and that is neuroplasticity.
  
  There are numerous plasticity rules, some more faithful to their biological counterparts 
  than others, and some more efficient than their biological counterparts.
  
  Note: The self_modulation_v1, self_modulation_v2, and self_modulation_v3 are all very 
  similar, mainly differing in the parameter lists returned by the 
  PlasticityFunctionName(neural_parameters) function. All three of these plasticity 
  functions use the neuromodulation/5 function which accepts the H, A, B, C, and D 
  learning parameters, and updates the synaptic weights of the neuron using the general 
  Hebbian rule: Updated_Wi = Wi + H*(A*Ii*Output + B*Ii + C*Output + D).
  
  The self_modulation_v4 – v5 differ only in that the weight_parameters is a list of length 2, 
  and the A parameter is no longer specified in the neural_parameters list, and is instead 
  calculated by the second dedicated modulatory neuron.
  
  The self_modulation_v6 function specifies the neural_parameters as an empty list, and the
  weight_parameters list is of length 5, a single weight for every embedded modulatory neuron.
  """
  
  @doc """
  Apply a plasticity function by name to get parameters.
  
  This is a convenience function that routes to the appropriate plasticity function
  based on the provided name.
  """
  @spec apply(atom(), atom()) :: list()
  def apply(plasticity_name, param_type) when is_atom(plasticity_name) and is_atom(param_type) do
    case plasticity_name do
      :none -> none(param_type)
      :hebbian -> hebbian(param_type)
      :hebbian_w -> hebbian_w(param_type)
      :ojas -> ojas(param_type)
      :ojas_w -> ojas_w(param_type)
      :self_modulation_v1 -> self_modulation_v1(param_type)
      :self_modulation_v2 -> self_modulation_v2(param_type)
      :self_modulation_v3 -> self_modulation_v3(param_type)
      :self_modulation_v4 -> self_modulation_v4(param_type)
      :self_modulation_v5 -> self_modulation_v5(param_type)
      :self_modulation_v6 -> self_modulation_v6(param_type)
      :neuromodulation -> neuromodulation(param_type)
      _ -> []
    end
  end
  
  alias Bardo.Functions
  alias Bardo.Models
  alias Bardo.DB
  alias Bardo.Utils
  
  # Constant for saturation limit
  @sat_limit :math.pi() * 2
  
  @doc """
  Returns a set of learning parameters needed by the none/4 plasticity function.
  
  Since this function specifies that the neuron has no plasticity, the parameter lists are empty.
  When executed with the {neuron_id, :mutate} parameter, the function exits, since there is
  nothing to mutate. The exit allows for the neuroevolutionary system to try another mutation
  operator on the NN system.
  """
  @spec none(atom() | tuple()) :: list() | no_return()
  def none({_nid, :mutate}) do
    raise "Neuron does not support plasticity."
  end
  
  def none(:neural_parameters) do
    []
  end
  
  def none(:weight_parameters) do
    []
  end
  
  @doc """
  None plasticity function - no learning happens.
  
  Returns the original InputPidPs to the caller.
  """
  @spec none(any(), any(), any(), any()) :: any()
  def none(_neural_parameters, _i_acc, input_pidps, _output) do
    input_pidps
  end
  
  @doc """
  Returns parameters for the hebbian_w learning rule.
  
  The parameter list for the simple hebbian_w learning rule is a parameter list 
  composed of a single parameter H: [H], for every synaptic weight of the neuron.
  """
  @spec hebbian_w(atom() | tuple()) :: list() | Models.neuron()
  def hebbian_w({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set({:input_idps, u_input_idps}, n)
  end
  
  def hebbian_w(:neural_parameters) do
    []
  end
  
  def hebbian_w(:weight_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  @doc """
  Hebbian plasticity function with weight-specific learning rates.
  
  The function operates on each InputPidP, applying the hebbian learning rule to each
  weight using its own specific learning rate.
  """
  @spec hebbian_w(any(), [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) :: 
        [{pid(), [{float(), [float()]}]}]
  def hebbian_w(_neural_parameters, i_acc, input_pidps, output) do
    hebbian_w1(i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the hebbian learning rule.
  
  The parameter list for the standard hebbian learning rule is a parameter list 
  composed of a single parameter H: [H], used by the neuron for all its synaptic weights.
  """
  @spec hebbian(atom() | tuple()) :: list() | Models.neuron()
  def hebbian({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, parameter_list} = Models.get(:pf, n)
    spread = @sat_limit * 10
    mutation_prob = 1 / :math.sqrt(length(parameter_list))
    u_parameter_list = perturb(parameter_list, mutation_prob, spread, [])
    u_pf = {pf_name, u_parameter_list}
    Models.set({:pf, u_pf}, n)
  end
  
  def hebbian(:neural_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  def hebbian(:weight_parameters) do
    []
  end
  
  @doc """
  Hebbian plasticity function with a global learning rate.
  
  The function applies the hebbian learning rule to all weights using a single,
  neuron-wide learning rate.
  """
  @spec hebbian([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def hebbian([_m, h], i_acc, input_pidps, output) do
    hebbian(h, i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the ojas_w learning rule.
  
  The parameter list for Oja's learning rule is a list composed of a single parameter 
  H: [H] per synaptic weight.
  """
  @spec ojas_w(atom() | tuple()) :: list() | Models.neuron()
  def ojas_w({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set({:input_idps, u_input_idps}, n)
  end
  
  def ojas_w(:neural_parameters) do
    []
  end
  
  def ojas_w(:weight_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  @doc """
  Oja's plasticity function with weight-specific learning rates.
  
  The function operates on each InputPidP, applying Oja's learning rule to each
  weight using its own specific learning rate.
  """
  @spec ojas_w(any(), [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def ojas_w(_neural_parameters, i_acc, input_pidps, output) do
    ojas_w1(i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the ojas learning rule.
  
  The parameter list for Oja's learning rule is a list composed of a single parameter 
  H: [H], used by the neuron for all its synaptic weights.
  """
  @spec ojas(atom() | tuple()) :: list() | Models.neuron()
  def ojas({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, parameter_list} = Models.get(:pf, n)
    spread = @sat_limit * 10
    mutation_prob = 1 / :math.sqrt(length(parameter_list))
    u_parameter_list = perturb(parameter_list, mutation_prob, spread, [])
    u_pf = {pf_name, u_parameter_list}
    Models.set({:pf, u_pf}, n)
  end
  
  def ojas(:neural_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  def ojas(:weight_parameters) do
    []
  end
  
  @doc """
  Oja's plasticity function with a global learning rate.
  
  The function applies Oja's learning rule to all weights using a single,
  neuron-wide learning rate.
  """
  @spec ojas([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def ojas([_m, h], i_acc, input_pidps, output) do
    ojas(h, i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v1 learning rule.
  
  Version-1: where the secondary embedded neuron only outputs the H learning parameter, 
  with the parameter A set to some predetermined constant value within the neural_parameters 
  list, and B=C=D=0.
  """
  @spec self_modulation_v1(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v1({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set({:input_idps, u_input_idps}, n)
  end
  
  def self_modulation_v1(:neural_parameters) do
    a = 0.1
    b = 0
    c = 0
    d = 0
    [a, b, c, d]
  end
  
  def self_modulation_v1(:weight_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  @doc """
  Self modulation plasticity function (version 1).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v1([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v1([_m, a, b, c, d], i_acc, input_pidps, output) do
    h = :math.tanh(dot_product_v1(i_acc, input_pidps))
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v2 learning rule.
  
  Version-2: where A is generated randomly when generating the neural_parameters list, 
  and B=C=D=0.
  """
  @spec self_modulation_v2(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v2({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, [a | parameter_list]} = Models.get(:pf, n)
    [u_a] = perturb([a], 0.5, @sat_limit * 10, [])
    u_pf = {pf_name, [u_a | parameter_list]}
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set([{:pf, u_pf}, {:input_idps, u_input_idps}], n)
  end
  
  def self_modulation_v2(:neural_parameters) do
    a = :rand.uniform() - 0.5
    b = 0
    c = 0
    d = 0
    [a, b, c, d]
  end
  
  def self_modulation_v2(:weight_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  @doc """
  Self modulation plasticity function (version 2).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v2([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v2([_m, a, b, c, d], i_acc, input_pidps, output) do
    h = :math.tanh(dot_product_v1(i_acc, input_pidps))
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v3 learning rule.
  
  Version-3: where B, C, and D are also generated randomly in the neural_parameters list.
  """
  @spec self_modulation_v3(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v3({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, parameter_list} = Models.get(:pf, n)
    m_spread = @sat_limit * 10
    mutation_prob = 1 / :math.sqrt(length(parameter_list))
    u_parameter_list = perturb(parameter_list, mutation_prob, m_spread, [])
    u_pf = {pf_name, u_parameter_list}
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set([{:pf, u_pf}, {:input_idps, u_input_idps}], n)
  end
  
  def self_modulation_v3(:neural_parameters) do
    a = :rand.uniform() - 0.5
    b = :rand.uniform() - 0.5
    c = :rand.uniform() - 0.5
    d = :rand.uniform() - 0.5
    [a, b, c, d]
  end
  
  def self_modulation_v3(:weight_parameters) do
    [:rand.uniform() - 0.5]
  end
  
  @doc """
  Self modulation plasticity function (version 3).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v3([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v3([_m, a, b, c, d], i_acc, input_pidps, output) do
    h = :math.tanh(dot_product_v1(i_acc, input_pidps))
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v4 learning rule.
  
  Version-4: where the weight_parameters generates a list of length 2, thus allowing 
  the neuron to have 2 embedded modulatory neurons, one outputting a parameter we use 
  for H, and another outputting the value we can use as A, with B=C=D=0.
  """
  @spec self_modulation_v4(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v4({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set({:input_idps, u_input_idps}, n)
  end
  
  def self_modulation_v4(:neural_parameters) do
    b = 0
    c = 0
    d = 0
    [b, c, d]
  end
  
  def self_modulation_v4(:weight_parameters) do
    [:rand.uniform() - 0.5, :rand.uniform() - 0.5]
  end
  
  @doc """
  Self modulation plasticity function (version 4).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v4([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v4([_m, b, c, d], i_acc, input_pidps, output) do
    {acc_h, acc_a} = dot_product_v4(i_acc, input_pidps)
    h = :math.tanh(acc_h)
    a = :math.tanh(acc_a)
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v5 learning rule.
  
  Version-5: Where B, C, and D are generated randomly by the 
  PlasticityFunctionName(neural_parameters) function.
  """
  @spec self_modulation_v5(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v5({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, parameter_list} = Models.get(:pf, n)
    m_spread = @sat_limit * 10
    mutation_prob = 1 / :math.sqrt(length(parameter_list))
    u_parameter_list = perturb(parameter_list, mutation_prob, m_spread, [])
    u_pf = {pf_name, u_parameter_list}
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set([{:pf, u_pf}, {:input_idps, u_input_idps}], n)
  end
  
  def self_modulation_v5(:neural_parameters) do
    b = :rand.uniform() - 0.5
    c = :rand.uniform() - 0.5
    d = :rand.uniform() - 0.5
    [b, c, d]
  end
  
  def self_modulation_v5(:weight_parameters) do
    [:rand.uniform() - 0.5, :rand.uniform() - 0.5]
  end
  
  @doc """
  Self modulation plasticity function (version 5).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v5([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v5([_m, b, c, d], i_acc, input_pidps, output) do
    {acc_h, acc_a} = dot_product_v4(i_acc, input_pidps)
    h = :math.tanh(acc_h)
    a = :math.tanh(acc_a)
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the self_modulation_v6 learning rule.
  
  Version-6: Where the weight_parameters produces a list of length 5, allowing the neuron 
  to have 5 embedded modulatory neurons, whose outputs are used for H, A, B, C, and D.
  """
  @spec self_modulation_v6(atom() | tuple()) :: list() | Models.neuron()
  def self_modulation_v6({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    input_idps = Models.get(:input_idps, n)
    u_input_idps = perturb_parameters(input_idps, @sat_limit)
    Models.set({:input_idps, u_input_idps}, n)
  end
  
  def self_modulation_v6(:neural_parameters) do
    []
  end
  
  def self_modulation_v6(:weight_parameters) do
    h = :rand.uniform() - 0.5
    a = :rand.uniform() - 0.5
    b = :rand.uniform() - 0.5
    c = :rand.uniform() - 0.5
    d = :rand.uniform() - 0.5
    [h, a, b, c, d]
  end
  
  @doc """
  Self modulation plasticity function (version 6).
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec self_modulation_v6([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def self_modulation_v6([_m], i_acc, input_pidps, output) do
    {acc_h, acc_a, acc_b, acc_c, acc_d} = dot_product_v6(i_acc, input_pidps)
    h = :math.tanh(acc_h)
    a = :math.tanh(acc_a)
    b = :math.tanh(acc_b)
    c = :math.tanh(acc_c)
    d = :math.tanh(acc_d)
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  @doc """
  Returns parameters for the neuromodulation learning rule.
  
  Neuromodulation is a form of heterosynaptic plasticity where the synaptic weights 
  are changed due to the synaptic activity of other neurons.
  """
  @spec neuromodulation(atom() | tuple()) :: list() | Models.neuron()
  def neuromodulation({n_id, :mutate}) do
    Utils.random_seed()
    n = DB.read(n_id, :neuron)
    {pf_name, parameter_list} = Models.get(:pf, n)
    m_spread = @sat_limit * 10
    mutation_prob = 1 / :math.sqrt(length(parameter_list))
    u_parameter_list = perturb(parameter_list, mutation_prob, m_spread, [])
    u_pf = {pf_name, u_parameter_list}
    Models.set({:pf, u_pf}, n)
  end
  
  def neuromodulation(:neural_parameters) do
    h = :rand.uniform() - 0.5
    a = :rand.uniform() - 0.5
    b = :rand.uniform() - 0.5
    c = :rand.uniform() - 0.5
    d = :rand.uniform() - 0.5
    [h, a, b, c, d]
  end
  
  def neuromodulation(:weight_parameters) do
    []
  end
  
  @doc """
  Neuromodulation plasticity function.
  
  Updates the synaptic weights of the neuron using a modulated Hebbian learning rule.
  """
  @spec neuromodulation([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def neuromodulation([m, h, a, b, c, d], i_acc, input_pidps, output) do
    modulator = scale_dzone(m, 0.33, @sat_limit)
    neuromodulation([modulator * h, a, b, c, d], i_acc, input_pidps, output, [])
  end
  
  # Internal functions
  
  defp perturb_parameters(input_idps, spread) do
    tot_parameters = Enum.sum(
      for {_input_id, wps} <- input_idps do
        Enum.sum(for {_w, ps} <- wps, do: length(ps))
      end
    )
    
    mutation_prob = 1 / :math.sqrt(tot_parameters)
    
    for {input_id, wps} <- input_idps do
      {input_id, (for {w, ps} <- wps, do: {w, perturb(ps, mutation_prob, spread, [])})}
    end
  end
  
  defp perturb([val | vals], mutation_prob, spread, acc) do
    if :rand.uniform() < mutation_prob do
      u_val = sat((:rand.uniform() - 0.5) * 2 * spread + val, spread, -spread)
      perturb(vals, mutation_prob, spread, [u_val | acc])
    else
      perturb(vals, mutation_prob, spread, [val | acc])
    end
  end
  
  defp perturb([], _mutation_prob, _spread, acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def hebbian_w1([{i_pid, is} | i_acc], [{i_pid, wps} | input_pidps], output, acc) do
    updated_wps = hebbrule_w(is, wps, output, [])
    hebbian_w1(i_acc, input_pidps, output, [{i_pid, updated_wps} | acc])
  end
  
  def hebbian_w1([], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  def hebbian_w1([], [{:bias, wps}], _output, acc) do
    Enum.reverse([{:bias, wps} | acc])
  end
  
  @doc false
  def hebbrule_w([i | is], [{w, [h]} | wps], [output], acc) do
    updated_w = Functions.saturation(w + (h * i * output), @sat_limit)
    hebbrule_w(is, wps, [output], [{updated_w, [h]} | acc])
  end
  
  def hebbrule_w([], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def hebbian(h, [{i_pid, is} | i_acc], [{i_pid, wps} | input_pidps], output, acc) do
    updated_wps = hebbrule(h, is, wps, output, [])
    hebbian(h, i_acc, input_pidps, output, [{i_pid, updated_wps} | acc])
  end
  
  def hebbian(_h, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  def hebbian(_h, [], [{:bias, wps}], _output, acc) do
    Enum.reverse([{:bias, wps} | acc])
  end
  
  @doc false
  def hebbrule(h, [i | is], [{w, []} | wps], [output], acc) do
    updated_w = Functions.saturation(w + (h * i * output), @sat_limit)
    hebbrule(h, is, wps, [output], [{updated_w, []} | acc])
  end
  
  def hebbrule(_h, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def ojas_w1([{i_pid, is} | i_acc], [{i_pid, wps} | input_pidps], output, acc) do
    updated_wps = ojas_rule_w(is, wps, output, [])
    ojas_w1(i_acc, input_pidps, output, [{i_pid, updated_wps} | acc])
  end
  
  def ojas_w1([], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  def ojas_w1([], [{:bias, wps}], _output, acc) do
    Enum.reverse([{:bias, wps} | acc])
  end
  
  @doc false
  def ojas_rule_w([i | is], [{w, [h]} | wps], [output], acc) do
    updated_w = Functions.saturation(w + (h * output) * (i - output * w), @sat_limit)
    ojas_rule_w(is, wps, [output], [{updated_w, [h]} | acc])
  end
  
  def ojas_rule_w([], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def ojas(h, [{i_pid, is} | i_acc], [{i_pid, wps} | input_pidps], output, acc) do
    updated_wps = ojas_rule(h, is, wps, output, [])
    ojas(h, i_acc, input_pidps, output, [{i_pid, updated_wps} | acc])
  end
  
  def ojas(_h, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  def ojas(_h, [], [{:bias, wps}], _output, acc) do
    Enum.reverse([{:bias, wps} | acc])
  end
  
  @doc false
  def ojas_rule(h, [i | is], [{w, []} | wps], [output], acc) do
    updated_w = Functions.saturation(w + (h * output) * (i - output * w), @sat_limit)
    ojas_rule(h, is, wps, [output], [{updated_w, []} | acc])
  end
  
  def ojas_rule(_h, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def neuromodulation([h, a, b, c, d], [{i_pid, is} | i_acc], [{i_pid, wps} | input_pidps], output, acc) do
    updated_wps = genheb_rule([h, a, b, c, d], is, wps, output, [])
    neuromodulation([h, a, b, c, d], i_acc, input_pidps, output, [{i_pid, updated_wps} | acc])
  end
  
  def neuromodulation(_neural_parameters, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  def neuromodulation([h, a, b, c, d], [], [{:bias, wps}], output, acc) do
    updated_wps = genheb_rule([h, a, b, c, d], [1], wps, output, [])
    Enum.reverse([{:bias, updated_wps} | acc])
  end
  
  @doc false
  def genheb_rule([h, a, b, c, d], [i | is], [{w, ps} | wps], [output], acc) do
    updated_w = Functions.saturation(w + h * ((a*i*output) + (b*i) + (c*output) + d), @sat_limit)
    genheb_rule([h, a, b, c, d], is, wps, [output], [{updated_w, ps} | acc])
  end
  
  def genheb_rule(_neural_learning_parameters, [], [], _output, acc) do
    Enum.reverse(acc)
  end
  
  defp dot_product_v1(i_acc, i_pid_ps) do
    dot_product_v1(i_acc, i_pid_ps, 0)
  end
  
  defp dot_product_v1([{i_pid, input} | i_acc], [{i_pid, weights_p} | i_pid_ps], acc) do
    dot = dot_v1(input, weights_p, 0)
    dot_product_v1(i_acc, i_pid_ps, dot + acc)
  end
  
  defp dot_product_v1([], [{:bias, [{_bias, [h_bias]}]}], acc) do
    acc + h_bias
  end
  
  defp dot_product_v1([], [], acc) do
    acc
  end
  
  defp dot_v1([i | input], [{_w, [h_w]} | weights], acc) do
    dot_v1(input, weights, i * h_w + acc)
  end
  
  defp dot_v1([], [], acc) do
    acc
  end
  
  defp dot_product_v4(i_acc, i_pid_ps) do
    dot_product_v4(i_acc, i_pid_ps, 0, 0)
  end
  
  defp dot_product_v4([{i_pid, input} | i_acc], [{i_pid, weights_p} | i_pid_ps], acc_h, acc_a) do
    {dot_h, dot_a} = dot_v4(input, weights_p, 0, 0)
    dot_product_v4(i_acc, i_pid_ps, dot_h + acc_h, dot_a + acc_a)
  end
  
  defp dot_product_v4([], [{:bias, [{_bias, [h_bias, a_bias]}]}], acc_h, acc_a) do
    {acc_h + h_bias, acc_a + a_bias}
  end
  
  defp dot_product_v4([], [], acc_h, acc_a) do
    {acc_h, acc_a}
  end
  
  defp dot_v4([i | input], [{_w, [h_w, a_w]} | weights], acc_h, acc_a) do
    dot_v4(input, weights, i * h_w + acc_h, i * a_w + acc_a)
  end
  
  defp dot_v4([], [], acc_h, acc_a) do
    {acc_h, acc_a}
  end
  
  defp dot_product_v6(i_acc, i_pid_ps) do
    dot_product_v6(i_acc, i_pid_ps, 0, 0, 0, 0, 0)
  end
  
  defp dot_product_v6([{i_pid, input} | i_acc], [{i_pid, weights_p} | i_pid_ps], acc_h, acc_a, acc_b, acc_c, acc_d) do
    {dot_h, dot_a, dot_b, dot_c, dot_d} = dot_v6(input, weights_p, 0, 0, 0, 0, 0)
    dot_product_v6(i_acc, i_pid_ps, dot_h + acc_h, dot_a + acc_a, dot_b + acc_b, dot_c + acc_c, dot_d + acc_d)
  end
  
  defp dot_product_v6([], [{:bias, [{_bias, [h_bias, a_bias, b_bias, c_bias, d_bias]}]}], acc_h, acc_a, acc_b, acc_c, acc_d) do
    {acc_h + h_bias, acc_a + a_bias, acc_b + b_bias, acc_c + c_bias, acc_d + d_bias}
  end
  
  defp dot_product_v6([], [], acc_h, acc_a, acc_b, acc_c, acc_d) do
    {acc_h, acc_a, acc_b, acc_c, acc_d}
  end
  
  defp dot_v6([i | input], [{_w, [h_w, a_w, b_w, c_w, d_w]} | weights], acc_h, acc_a, acc_b, acc_c, acc_d) do
    dot_v6(input, weights, 
      i * h_w + acc_h, 
      i * a_w + acc_a, 
      i * b_w + acc_b, 
      i * c_w + acc_c, 
      i * d_w + acc_d)
  end
  
  defp dot_v6([], [], acc_h, acc_a, acc_b, acc_c, acc_d) do
    {acc_h, acc_a, acc_b, acc_c, acc_d}
  end
  
  defp scale_dzone(val, threshold, max_magnitude) when val > threshold do
    (Functions.scale(val, max_magnitude, threshold) + 1) * max_magnitude / 2
  end
  
  defp scale_dzone(val, threshold, max_magnitude) when val < -threshold do
    (Functions.scale(val, -threshold, -max_magnitude) - 1) * max_magnitude / 2
  end
  
  defp scale_dzone(_val, _threshold, _max_magnitude) do
    0.0
  end
  
  defp sat(val, max, min) do
    cond do
      val > max -> max
      val < min -> min
      true -> val
    end
  end
end