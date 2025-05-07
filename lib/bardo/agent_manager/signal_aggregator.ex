defmodule Bardo.AgentManager.SignalAggregator do
  @moduledoc """
  The SignalAggregator module contains various aggregation functions.
  
  An aggregation function is a function that in some manner gathers the input signal 
  vectors, does something with it and the synaptic weights, and then produces a scalar 
  value. For example, consider the dot product. The dot_product aggregation function
  composes the scalar value by aggregating the input vectors, and then calculating the 
  dot product of the input vectors and the synaptic weights.
  
  Another way to calculate a scalar value from the input and weight vectors is by 
  multiplying the corresponding input signals by their weights, but instead of adding 
  the resulting multiplied values, we multiply them. The are many other types of 
  aggregation functions that could be created. We can also add normalizer functions, 
  which could normalize the input signals.
  """
  
  @doc """
  Apply the appropriate aggregation function to the input.
  
  This is a dispatcher that routes to the appropriate aggregation function based
  on the function name provided.
  """
  @spec apply(atom(), [{pid(), [float()]}], [{pid(), [float()]}]) :: float()
  def apply(:dot_product, i_acc, i_pid_ps), do: dot_product(i_acc, i_pid_ps)
  def apply(:diff_product, i_acc, i_pid_ps), do: diff_product(i_acc, i_pid_ps)
  def apply(:mult_product, i_acc, i_pid_ps), do: mult_product(i_acc, i_pid_ps)
  
  @doc """
  The dot_product aggregation function is used in almost all artificial
  neural network implementations. It can be considered stable/proven.
  """
  @spec dot_product([{pid(), [float()]}], [{pid(), [float()]}]) :: float()
  def dot_product(i_acc, i_pid_ps) do
    dot_product(i_acc, i_pid_ps, 0)
  end
  
  @doc """
  The diff_product can be thought of as a neuron that looks not at the
  actual signal amplitudes, but the temporal difference in signal
  amplitudes. If the input signals have stabilized, then the neuron's
  input is calculated as a 0, if there is a sudden change in the signal,
  the neuron will see it.
  """
  @spec diff_product([{pid(), [float()]}], [{pid(), [float()]}]) :: float()
  def diff_product(i_acc, i_pid_ps) do
    case Process.get(:diff_product) do
      nil ->
        Process.put(:diff_product, i_acc)
        dot_product(i_acc, i_pid_ps, 0)
        
      prev_i_acc ->
        Process.put(:diff_product, i_acc)
        diff_i_acc = input_diff(i_acc, prev_i_acc, [])
        dot_product(diff_i_acc, i_pid_ps, 0)
    end
  end
  
  @doc """
  The worth of the mult_product aggregation function is questionable, and
  should be further studied through benchmarking and testing. If there is
  any worth to this type of signal aggregator, evolution will find it!
  """
  @spec mult_product([{pid(), [float()]}], [{pid(), [float()]}]) :: float()
  def mult_product(i_acc, i_pid_ps) do
    mult_product(i_acc, i_pid_ps, 1)
  end
  
  # Internal functions
  
  @doc false
  def dot_product([{i_pid, input} | i_acc], [{i_pid, weights_p} | i_pid_ps], acc) do
    dot_val = dot(input, weights_p, 0)
    dot_product(i_acc, i_pid_ps, dot_val + acc)
  end
  
  def dot_product([], [{:bias, [{bias, _lps}]}], acc) do
    acc + bias
  end
  
  def dot_product([], [], acc) do
    acc
  end
  
  @doc false
  def dot([i | input], [{w, _lps} | weights_p], acc) do
    dot(input, weights_p, i * w + acc)
  end
  
  def dot([], [], acc) do
    acc
  end
  
  @doc false
  def input_diff([{ip_id, input} | i_acc], [{ip_id, prev_input} | prev_i_acc], acc) do
    vector_diff = diff(input, prev_input, [])
    input_diff(i_acc, prev_i_acc, [{ip_id, vector_diff} | acc])
  end
  
  def input_diff([], [], acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def diff([a | input], [b | prev_input], acc) do
    diff(input, prev_input, [a - b | acc])
  end
  
  def diff([], [], acc) do
    Enum.reverse(acc)
  end
  
  @doc false
  def mult_product([{i_pid, input} | i_acc], [{i_pid, weights_p} | i_pid_ps], acc) do
    mult_val = mult(input, weights_p, 1)
    mult_product(i_acc, i_pid_ps, mult_val * acc)
  end
  
  def mult_product([], [{:bias, [{bias, _lps}]}], acc) do
    acc * bias
  end
  
  def mult_product([], [], acc) do
    acc
  end
  
  @doc false
  def mult([i | input], [{w, _lps} | weights_p], acc) do
    mult(input, weights_p, i * w * acc)
  end
  
  def mult([], [], acc) do
    acc
  end
end