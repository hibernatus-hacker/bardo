defmodule Bardo.Models do
  @moduledoc """
  Shared data models and functions for the Bardo system.
  
  This module defines the type specifications and data models used throughout
  the system, as well as utility functions for working with these models.
  """

  @doc """
  Get a value from a model by key.
  
  Returns the value for the given key or keys in the model. If the key is not found,
  returns :not_found.
  
  ## Examples
  
      iex> model = topology_summary(%{type: :neural, tot_neurons: 10})
      iex> get(:type, model)
      :neural
      
      iex> get([:type, :tot_neurons], model)
      [:neural, 10]
      
      iex> get(:unknown, model)
      :not_found
  """
  @spec get([atom()] | atom(), map()) :: [term() | :not_found] | term() | :not_found
  def get(keys, %{data: data}) when is_list(keys) do
    Enum.map(keys, fn k -> Map.get(data, k, :not_found) end)
  end
  
  def get(key, %{data: data}) do
    Map.get(data, key, :not_found)
  end

  @doc """
  Update a value in a model by key.
  
  Sets the value for the given key or keys in the model and returns the updated model.
  
  ## Examples
  
      iex> model = topology_summary(%{type: :neural, tot_neurons: 10})
      iex> set({:tot_neurons, 20}, model)
      %{data: %{type: :neural, tot_neurons: 20}}
      
      iex> set([{:tot_neurons, 20}, {:tot_n_ils, 30}], model)
      %{data: %{type: :neural, tot_neurons: 20, tot_n_ils: 30}}
  """
  @spec set([{atom(), term()}] | {atom(), term()}, map()) :: map()
  def set([h | tail], model) do
    new_model = set(h, model)
    set(tail, new_model)
  end
  
  def set([], model), do: model
  
  def set({k, v}, %{data: data} = model) do
    %{model | data: Map.put(data, k, v)}
  end

  # Model construction functions

  @doc """
  Create a topology summary model.
  """
  @spec topology_summary(map()) :: map()
  def topology_summary(data), do: %{data: data}

  @doc """
  Create a sensor model.
  """
  @spec sensor(map()) :: map()
  def sensor(data), do: %{data: data}

  @doc """
  Create an actuator model.
  """
  @spec actuator(map()) :: map()
  def actuator(data), do: %{data: data}

  @doc """
  Create a neuron model.
  """
  @spec neuron(map()) :: map()
  def neuron(data), do: %{data: data}

  @doc """
  Create a cortex model.
  """
  @spec cortex(map()) :: map()
  def cortex(data), do: %{data: data}

  @doc """
  Create a substrate model.
  """
  @spec substrate(map()) :: map()
  def substrate(data), do: %{data: data}

  @doc """
  Create a constraint model.
  """
  @spec constraint(map()) :: map()
  def constraint(data), do: %{data: data}

  @doc """
  Create an experiment model.
  """
  @spec experiment(map()) :: map()
  def experiment(data), do: %{data: data}

  @doc """
  Create an agent model.
  """
  @spec agent(map()) :: map()
  def agent(data), do: %{data: data}

  @doc """
  Create a champion model.
  """
  @spec champion(map()) :: map()
  def champion(data), do: %{data: data}

  @doc """
  Create a PMP (Population Manager Parameters) model.
  """
  @spec pmp(map()) :: map()
  def pmp(data), do: %{data: data}

  @doc """
  Create a stat model.
  """
  @spec stat(map()) :: map()
  def stat(data), do: %{data: data}

  @doc """
  Create a trace model.
  """
  @spec trace(map()) :: map()
  def trace(data), do: %{data: data}

  @doc """
  Create a population model.
  """
  @spec population(map()) :: map()
  def population(data), do: %{data: data}

  @doc """
  Create a population status model.
  """
  @spec population_status(map()) :: map()
  def population_status(data), do: %{data: data}

  @doc """
  Create a specie model.
  """
  @spec specie(map()) :: map()
  def specie(data), do: %{data: data}
end