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
  """
  
  alias Bardo.Functions
  
  # Constant for saturation limit
  @sat_limit :math.pi() * 2
  
  @doc """
  None plasticity function - no learning happens.
  
  Returns the original InputPidPs to the caller.
  """
  @spec none(any(), any(), any(), any()) :: any()
  def none(_neural_parameters, _i_acc, input_pidps, _output) do
    input_pidps
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
  Oja's plasticity function with a global learning rate.
  
  The function applies Oja's learning rule to all weights using a single,
  neuron-wide learning rate.
  """
  @spec ojas([float()], [{pid(), [float()]}], [{pid(), [{float(), [float()]}]}], [float()]) ::
        [{pid(), [{float(), [float()]}]}]
  def ojas([_m, h], i_acc, input_pidps, output) do
    ojas(h, i_acc, input_pidps, output, [])
  end
  
  # Internal functions
  
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
  
  # Additional plasticity functions can be added here as required by other modules
end