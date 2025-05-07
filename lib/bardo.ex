defmodule Bardo do
  @moduledoc """
  Bardo is a powerful neuroevolution library for Elixir.
  
  It enables the creation, training, and deployment of neural networks that evolve their
  topology and parameters over time through evolutionary algorithms. The library is designed
  to be both powerful for experts and approachable for newcomers to neuroevolution.
  
  ## Core Features
  
  * **Topology and Weight Evolving Artificial Neural Networks (TWEANNs)**: Neural networks
    that evolve not just their weights but their entire structure.
  
  * **Distributed Evolution**: Leverages the Erlang VM for efficient parallel training and evaluation.
  
  * **Sensor-Actuator Framework**: Easy integration with custom environments through a
    standardized interface for inputs and outputs.
  
  * **Multiple Encoding Strategies**: Supports direct, substrate-based, and other encoding schemes.
  
  * **Built-in Examples**: Includes classic benchmarks like pole balancing and complex simulations
    like predator-prey ecosystems.
  
  ## Architecture
  
  Bardo is organized into several key subsystems:
  
  * **ExperimentManager**: Controls the overall experimental process
  * **PopulationManager**: Handles populations of evolving agents
  * **AgentManager**: Manages neural networks and their interactions
  * **ScapeManager**: Provides environments for agents to operate in
  
  ## Origins
  
  Bardo is based on the Topology and Parameter Evolving Universal Learning Network
  (DXNN) system originally created by Gene Sher in Erlang. It has been reimplemented
  and extended in Elixir with a focus on usability, performance, and modern design patterns.
  
  ## Usage
  
  For basic usage, see the `README.md` file. For more detailed examples and tutorials, 
  explore the `docs/` directory in the project repository.
  """

  @doc """
  Returns the current library version.
  
  ## Examples
  
      iex> Bardo.version()
      "0.1.0"
  """
  @spec version() :: String.t()
  def version do
    "0.1.0"
  end
  
  @doc """
  A simple function to say hello. Used in tests and examples.
  
  ## Examples
  
      iex> Bardo.hello()
      :world
  """
  @spec hello() :: atom()
  def hello do
    :world
  end
end