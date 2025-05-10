defmodule Bardo.Morphology do
  @moduledoc """
  Morphology module for the Bardo neuroevolution system.
  
  The Morphology module defines the structure and properties of neural networks
  in the Bardo system. It provides functions for creating, modifying, and querying
  neural network morphologies, including:
  
  - Sensors: Input mechanisms for receiving data from the environment
  - Actuators: Output mechanisms for interacting with the environment
  - Substrates: Spatial arrangements of neurons in n-dimensional space
  - Connections: Patterns and rules for connecting neurons
  
  This module serves as the foundation for defining the physical structure of neural
  networks, which combined with learning rules and evolutionary algorithms, enables
  the creation of complex, adaptive systems.
  """
  
  alias Bardo.Models
  alias Bardo.Utils
  alias Bardo.DB
  
  # Type definitions
  
  @typedoc """
  Type definition for a neural network morphology.
  """
  @type t :: %{
    id: binary(),
    name: binary(),
    description: binary(),
    dimensions: non_neg_integer(),
    inputs: non_neg_integer(),
    outputs: non_neg_integer(),
    hidden_layers: [non_neg_integer()],
    activation_functions: [atom()],
    substrate_type: :cartesian | :hypercube | :hypersphere | :custom,
    connection_pattern: :feedforward | :recurrent | :dense | :custom,
    plasticity: :none | :hebbian | :stdp | :abcn | :iterative,
    sensors: [sensor()],
    actuators: [actuator()],
    substrate_cpps: [substrate_cpp()],
    substrate_ceps: [substrate_cep()],
    parameters: map()
  }
  
  @typedoc """
  Type definition for a sensor specification.
  """
  @type sensor :: %{
    id: binary() | nil,
    name: atom(),
    type: atom(),
    cx_id: binary() | nil,
    scape: atom() | nil,
    vl: non_neg_integer(),
    fanout_ids: [binary()],
    generation: non_neg_integer() | nil,
    format: atom() | nil,
    parameters: map() | nil
  }
  
  @typedoc """
  Type definition for an actuator specification.
  """
  @type actuator :: %{
    id: binary() | nil,
    name: atom(),
    type: atom(),
    cx_id: binary() | nil,
    scape: atom() | nil,
    vl: non_neg_integer(),
    fanin_ids: [binary()],
    generation: non_neg_integer() | nil,
    format: atom() | nil,
    parameters: map() | nil
  }
  
  @typedoc """
  Type definition for a substrate connection pattern producer.
  """
  @type substrate_cpp :: %{
    id: binary() | nil,
    name: atom(),
    type: atom(),
    cx_id: binary() | nil,
    scape: atom() | nil,
    vl: non_neg_integer(),
    fanout_ids: [binary()],
    generation: non_neg_integer() | nil,
    format: atom() | nil,
    parameters: map() | nil
  }
  
  @typedoc """
  Type definition for a substrate connection expression producer.
  """
  @type substrate_cep :: %{
    id: binary() | nil,
    name: atom(),
    type: atom(),
    cx_id: binary() | nil,
    scape: atom() | nil,
    vl: non_neg_integer(),
    fanin_ids: [binary()],
    generation: non_neg_integer() | nil,
    format: atom() | nil,
    parameters: map() | nil
  }
  
  # Public API
  
  @doc """
  Create a new morphology with the given options.
  
  ## Parameters
    * `opts` - A map of options for the morphology
    
  ## Returns
    * A new morphology struct
    
  ## Examples
      iex> Bardo.Morphology.new(%{name: "Simple XOR", dimensions: 2, inputs: 2, outputs: 1})
      %{id: "morph_xxxxxxxxxxx", name: "Simple XOR", dimensions: 2, inputs: 2, outputs: 1, ...}
  """
  @spec new(map()) :: t()
  def new(opts \\ %{}) do
    id = Map.get(opts, :id, "morph_" <> Utils.random_string(11))
    name = Map.get(opts, :name, "Generic Morphology")
    description = Map.get(opts, :description, "A generic neural network morphology")
    dimensions = Map.get(opts, :dimensions, 2)
    inputs = Map.get(opts, :inputs, 1)
    outputs = Map.get(opts, :outputs, 1)
    hidden_layers = Map.get(opts, :hidden_layers, [3])
    activation_functions = Map.get(opts, :activation_functions, [:sigmoid])
    substrate_type = Map.get(opts, :substrate_type, :cartesian)
    connection_pattern = Map.get(opts, :connection_pattern, :feedforward)
    plasticity = Map.get(opts, :plasticity, :none)
    parameters = Map.get(opts, :parameters, %{})
    
    # Default sensors and actuators based on inputs and outputs
    default_sensors = [
      Models.sensor(%{
        id: nil,
        name: :default_sensor,
        type: :standard,
        cx_id: nil,
        scape: nil,
        vl: inputs,
        fanout_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
    
    default_actuators = [
      Models.actuator(%{
        id: nil,
        name: :default_actuator,
        type: :standard,
        cx_id: nil,
        scape: nil,
        vl: outputs,
        fanin_ids: [],
        generation: nil,
        format: nil,
        parameters: nil
      })
    ]
    
    # Use provided sensors/actuators or defaults
    sensors = Map.get(opts, :sensors, default_sensors)
    actuators = Map.get(opts, :actuators, default_actuators)
    
    # Create default substrate CPPs and CEPs based on plasticity
    substrate_cpps = Map.get(opts, :substrate_cpps, get_default_substrate_cpps(dimensions, plasticity))
    substrate_ceps = Map.get(opts, :substrate_ceps, get_default_substrate_ceps(dimensions, plasticity))
    
    # Construct the morphology map
    %{
      id: id,
      name: name,
      description: description,
      dimensions: dimensions,
      inputs: inputs,
      outputs: outputs,
      hidden_layers: hidden_layers,
      activation_functions: activation_functions,
      substrate_type: substrate_type,
      connection_pattern: connection_pattern,
      plasticity: plasticity,
      sensors: sensors,
      actuators: actuators,
      substrate_cpps: substrate_cpps,
      substrate_ceps: substrate_ceps,
      parameters: parameters
    }
  end
  
  @doc """
  Save a morphology to the database.
  
  ## Parameters
    * `morphology` - The morphology to save
    
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{name: "Simple XOR"})
      iex> Bardo.Morphology.save(morphology)
      :ok
  """
  @spec save(t()) :: :ok | {:error, term()}
  def save(morphology) do
    Models.write(morphology.id, :morphology, morphology)
  end
  
  @doc """
  Load a morphology from the database.
  
  ## Parameters
    * `id` - The ID of the morphology to load
    
  ## Returns
    * `{:ok, morphology}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Morphology.load("morph_123456789")
      {:ok, %{id: "morph_123456789", name: "Simple XOR", ...}}
  """
  @spec load(binary()) :: {:ok, t()} | {:error, term()}
  def load(id) do
    Models.read(id, :morphology)
  end
  
  @doc """
  Delete a morphology from the database.
  
  ## Parameters
    * `id` - The ID of the morphology to delete
    
  ## Returns
    * `:ok` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Morphology.delete("morph_123456789")
      :ok
  """
  @spec delete(binary()) :: :ok | {:error, term()}
  def delete(id) do
    Models.delete(id, :morphology)
  end
  
  @doc """
  List all morphologies in the database.
  
  ## Returns
    * `{:ok, [morphology]}` on success
    * `{:error, reason}` on failure
    
  ## Examples
      iex> Bardo.Morphology.list()
      {:ok, [%{id: "morph_123456789", name: "Simple XOR", ...}, ...]}
  """
  @spec list() :: {:ok, [t()]} | {:error, term()}
  def list do
    try do
      {:ok, DB.list(:morphology) || []}
    rescue
      e -> {:error, "Error listing morphologies: #{inspect(e)}"}
    end
  end
  
  @doc """
  Add a sensor to a morphology.
  
  ## Parameters
    * `morphology` - The morphology to add the sensor to
    * `sensor` - The sensor to add
    
  ## Returns
    * An updated morphology with the new sensor
    
  ## Examples
      iex> sensor = Models.sensor(%{name: :eye, type: :vision, vl: 100})
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.add_sensor(morphology, sensor)
      %{id: "morph_xxxxxxxxxxx", sensors: [%{name: :eye, type: :vision, vl: 100}, ...], ...}
  """
  @spec add_sensor(t(), sensor()) :: t()
  def add_sensor(morphology, sensor) do
    %{morphology | sensors: [sensor | morphology.sensors]}
  end
  
  @doc """
  Add an actuator to a morphology.
  
  ## Parameters
    * `morphology` - The morphology to add the actuator to
    * `actuator` - The actuator to add
    
  ## Returns
    * An updated morphology with the new actuator
    
  ## Examples
      iex> actuator = Models.actuator(%{name: :motor, type: :movement, vl: 2})
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.add_actuator(morphology, actuator)
      %{id: "morph_xxxxxxxxxxx", actuators: [%{name: :motor, type: :movement, vl: 2}, ...], ...}
  """
  @spec add_actuator(t(), actuator()) :: t()
  def add_actuator(morphology, actuator) do
    %{morphology | actuators: [actuator | morphology.actuators]}
  end
  
  @doc """
  Get the total number of neurons in a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get the neuron count for
    
  ## Returns
    * The total number of neurons
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{inputs: 2, hidden_layers: [3], outputs: 1})
      iex> Bardo.Morphology.neuron_count(morphology)
      6
  """
  @spec neuron_count(t()) :: non_neg_integer()
  def neuron_count(morphology) do
    hidden_count = Enum.sum(morphology.hidden_layers)
    morphology.inputs + hidden_count + morphology.outputs
  end
  
  @doc """
  Get the initial sensors for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get sensors for
    
  ## Returns
    * A list of sensors
    
  ## Examples
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.get_init_sensors(morphology)
      [%{name: :default_sensor, ...}]
  """
  @spec get_init_sensors(t() | atom()) :: [sensor()]
  def get_init_sensors(%{sensors: sensors}) when is_list(sensors) do
    # If there are multiple sensors, start with just the first one
    # This allows evolution to explore adding more sensors later
    if length(sensors) > 0, do: [List.first(sensors)], else: []
  end
  
  # Allow passing a morphology module name
  def get_init_sensors(morphology_module) when is_atom(morphology_module) do
    m = Utils.get_module(morphology_module)
    
    if function_exported?(m, :sensors, 0) do
      sensors = apply(m, :sensors, [])
      if length(sensors) > 0, do: [List.first(sensors)], else: []
    else
      []
    end
  end
  
  @doc """
  Get all available sensors for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get sensors for
    
  ## Returns
    * A list of all sensors
    
  ## Examples
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.get_sensors(morphology)
      [%{name: :default_sensor, ...}]
  """
  @spec get_sensors(t() | atom()) :: [sensor()]
  def get_sensors(%{sensors: sensors}) when is_list(sensors) do
    sensors
  end
  
  # Allow passing a morphology module name
  def get_sensors(morphology_module) when is_atom(morphology_module) do
    m = Utils.get_module(morphology_module)
    
    if function_exported?(m, :sensors, 0) do
      apply(m, :sensors, [])
    else
      []
    end
  end
  
  @doc """
  Get the initial actuators for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get actuators for
    
  ## Returns
    * A list of actuators
    
  ## Examples
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.get_init_actuators(morphology)
      [%{name: :default_actuator, ...}]
  """
  @spec get_init_actuators(t() | atom()) :: [actuator()]
  def get_init_actuators(%{actuators: actuators}) when is_list(actuators) do
    # If there are multiple actuators, start with just the first one
    # This allows evolution to explore adding more actuators later
    if length(actuators) > 0, do: [List.first(actuators)], else: []
  end
  
  # Allow passing a morphology module name
  def get_init_actuators(morphology_module) when is_atom(morphology_module) do
    m = Utils.get_module(morphology_module)
    
    if function_exported?(m, :actuators, 0) do
      actuators = apply(m, :actuators, [])
      if length(actuators) > 0, do: [List.first(actuators)], else: []
    else
      []
    end
  end
  
  @doc """
  Get all available actuators for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get actuators for
    
  ## Returns
    * A list of all actuators
    
  ## Examples
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.get_actuators(morphology)
      [%{name: :default_actuator, ...}]
  """
  @spec get_actuators(t() | atom()) :: [actuator()]
  def get_actuators(%{actuators: actuators}) when is_list(actuators) do
    actuators
  end
  
  # Allow passing a morphology module name
  def get_actuators(morphology_module) when is_atom(morphology_module) do
    m = Utils.get_module(morphology_module)
    
    if function_exported?(m, :actuators, 0) do
      apply(m, :actuators, [])
    else
      []
    end
  end
  
  @doc """
  Get the initial substrate connection pattern producers (CPPs) for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get substrate CPPs for
    * `plasticity` - Optional plasticity type (overrides the morphology's plasticity)
    
  ## Returns
    * A list of substrate CPPs
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{plasticity: :hebbian})
      iex> Bardo.Morphology.get_init_substrate_cpps(morphology)
      [%{name: :cartesian, ...}]
  """
  @spec get_init_substrate_cpps(t() | integer(), atom() | nil) :: [substrate_cpp()]
  def get_init_substrate_cpps(%{dimensions: dimensions, plasticity: plasticity, substrate_cpps: cpps}) do
    # If substrate CPPs are defined in the morphology, use the first one
    # Otherwise generate default CPPs based on dimensions and plasticity
    if length(cpps) > 0 do
      [List.first(cpps)]
    else
      cpps = get_default_substrate_cpps(dimensions, plasticity)
      if length(cpps) > 0, do: [List.first(cpps)], else: []
    end
  end
  
  # Allow passing dimensions and plasticity directly
  def get_init_substrate_cpps(dimensions, plasticity) when is_integer(dimensions) do
    cpps = get_default_substrate_cpps(dimensions, plasticity)
    if length(cpps) > 0, do: [List.first(cpps)], else: []
  end
  
  @doc """
  Get all available substrate connection pattern producers (CPPs) for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get substrate CPPs for
    * `plasticity` - Optional plasticity type (overrides the morphology's plasticity)
    
  ## Returns
    * A list of all substrate CPPs
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{plasticity: :hebbian})
      iex> Bardo.Morphology.get_substrate_cpps(morphology)
      [%{name: :cartesian, ...}, %{name: :centripital_distances, ...}, ...]
  """
  @spec get_substrate_cpps(t() | integer(), atom() | nil) :: [substrate_cpp()]
  def get_substrate_cpps(%{dimensions: dimensions, plasticity: plasticity, substrate_cpps: cpps}) do
    # If substrate CPPs are defined in the morphology, use them
    # Otherwise generate default CPPs based on dimensions and plasticity
    if length(cpps) > 0 do
      cpps
    else
      get_default_substrate_cpps(dimensions, plasticity)
    end
  end
  
  # Allow passing dimensions and plasticity directly
  def get_substrate_cpps(dimensions, plasticity) when is_integer(dimensions) do
    get_default_substrate_cpps(dimensions, plasticity)
  end
  
  @doc """
  Get the initial substrate connection expression producers (CEPs) for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get substrate CEPs for
    * `plasticity` - Optional plasticity type (overrides the morphology's plasticity)
    
  ## Returns
    * A list of substrate CEPs
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{plasticity: :hebbian})
      iex> Bardo.Morphology.get_init_substrate_ceps(morphology)
      [%{name: :delta_weight, ...}]
  """
  @spec get_init_substrate_ceps(t() | integer(), atom() | nil) :: [substrate_cep()]
  def get_init_substrate_ceps(%{dimensions: dimensions, plasticity: plasticity, substrate_ceps: ceps}) do
    # If substrate CEPs are defined in the morphology, use the first one
    # Otherwise generate default CEPs based on dimensions and plasticity
    if length(ceps) > 0 do
      [List.first(ceps)]
    else
      ceps = get_default_substrate_ceps(dimensions, plasticity)
      if length(ceps) > 0, do: [List.first(ceps)], else: []
    end
  end
  
  # Allow passing dimensions and plasticity directly
  def get_init_substrate_ceps(dimensions, plasticity) when is_integer(dimensions) do
    ceps = get_default_substrate_ceps(dimensions, plasticity)
    if length(ceps) > 0, do: [List.first(ceps)], else: []
  end
  
  @doc """
  Get all available substrate connection expression producers (CEPs) for a morphology.
  
  ## Parameters
    * `morphology` - The morphology to get substrate CEPs for
    * `plasticity` - Optional plasticity type (overrides the morphology's plasticity)
    
  ## Returns
    * A list of all substrate CEPs
    
  ## Examples
      iex> morphology = Bardo.Morphology.new(%{plasticity: :hebbian})
      iex> Bardo.Morphology.get_substrate_ceps(morphology)
      [%{name: :delta_weight, ...}, %{name: :set_abcn, ...}, ...]
  """
  @spec get_substrate_ceps(t() | integer(), atom() | nil) :: [substrate_cep()]
  def get_substrate_ceps(%{dimensions: dimensions, plasticity: plasticity, substrate_ceps: ceps}) do
    # If substrate CEPs are defined in the morphology, use them
    # Otherwise generate default CEPs based on dimensions and plasticity
    if length(ceps) > 0 do
      ceps
    else
      get_default_substrate_ceps(dimensions, plasticity)
    end
  end
  
  # Allow passing dimensions and plasticity directly
  def get_substrate_ceps(dimensions, plasticity) when is_integer(dimensions) do
    get_default_substrate_ceps(dimensions, plasticity)
  end
  
  @doc """
  Create a physical configuration for an agent.
  
  ## Parameters
    * `morphology` - The morphology to create a physical configuration for
    * `cortex_id` - The ID of the cortex
    * `scape_name` - The name of the scape
    
  ## Returns
    * A map with :sensors and :actuators keys
    
  ## Examples
      iex> morphology = Bardo.Morphology.new()
      iex> Bardo.Morphology.get_phys_config(morphology, "cx_123", :test_scape)
      %{sensors: [...], actuators: [...]}
  """
  @spec get_phys_config(t() | atom(), binary(), atom()) :: map()
  def get_phys_config(%{} = morphology, cortex_id, scape_name) do
    # Create full configurations for each sensor and actuator
    sensors = Enum.map(morphology.sensors, fn sensor ->
      # Handle the case where Models.get(:data, sensor) returns :not_found
      base = case Models.get(:data, sensor) do
        :not_found -> sensor  # Use the sensor directly if :data key not found
        base_data -> base_data
      end

      %{
        id: Map.get(base, :id, Utils.random_string(8)),
        name: Map.get(base, :name, :default_sensor),
        module: get_module_for_sensor(base),
        sensor_type: Map.get(base, :name, :default_sensor),
        params: Map.get(base, :parameters, %{}),
        fanout: Map.get(base, :vl, 1),
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    end)

    actuators = Enum.map(morphology.actuators, fn actuator ->
      # Handle the case where Models.get(:data, actuator) returns :not_found
      base = case Models.get(:data, actuator) do
        :not_found -> actuator  # Use the actuator directly if :data key not found
        base_data -> base_data
      end

      %{
        id: Map.get(base, :id, Utils.random_string(8)),
        name: Map.get(base, :name, :default_actuator),
        module: get_module_for_actuator(base),
        actuator_type: Map.get(base, :name, :default_actuator),
        params: Map.get(base, :parameters, %{}),
        fanin: Map.get(base, :vl, 1),
        cortex_id: cortex_id,
        scape_name: scape_name
      }
    end)

    %{
      sensors: sensors,
      actuators: actuators
    }
  end
  
  # Allow passing a morphology module name
  def get_phys_config(morphology_module, cortex_id, scape_name) when is_atom(morphology_module) do
    m = Utils.get_module(morphology_module)
    
    if function_exported?(m, :get_phys_config, 3) do
      apply(m, :get_phys_config, [nil, cortex_id, scape_name])
    else
      # Create a default morphology and use its configuration
      default_morphology = new()
      get_phys_config(default_morphology, cortex_id, scape_name)
    end
  end
  
  @doc """
  Get the parameters required for an agent to enter a scape.
  
  ## Parameters
    * `morphology` - The morphology to get scape parameters for
    * `agent_id` - The ID of the agent
    * `cortex_id` - The ID of the cortex
    * `scape_name` - The name of the scape
    
  ## Returns
    * A map with scape parameters
  """
  @spec get_scape_params(t() | atom(), binary(), binary(), atom()) :: map()
  def get_scape_params(_morphology, _agent_id, _cortex_id, _scape_name) do
    # Default implementation returns an empty map
    # This should be overridden by specific morphology implementations
    %{}
  end
  
  @doc """
  Define the neuron pattern for a neural network.
  
  ## Parameters
    * `morphology` - The morphology to define the neuron pattern for
    * `agent_id` - The ID of the agent
    * `cortex_id` - The ID of the cortex
    * `neural_interface` - A map with sensors and actuators data
    
  ## Returns
    * A map defining the neuron pattern
  """
  @spec neuron_pattern(t() | atom(), binary(), binary(), map()) :: map()
  def neuron_pattern(%{} = _morphology, _agent_id, _cortex_id, neural_interface) do
    # Extract fanout and fanin from neural interface
    sensors = neural_interface.sensors
    actuators = neural_interface.actuators
    
    # Calculate total inputs from all sensors
    sensor_fanout = Enum.reduce(sensors, 0, fn sensor, acc -> 
      sensor.fanout + acc 
    end)
    
    # Calculate total outputs for all actuators
    actuator_fanin = Enum.reduce(actuators, 0, fn actuator, acc -> 
      actuator.fanin + acc 
    end)
    
    # Define the sensor to neuron index mapping
    sensor_id_to_idx_map = create_sensor_mapping(sensors, 0)
    
    # Define the actuator to neuron index mapping
    actuator_id_to_idx_map = create_actuator_mapping(actuators, 0)
    
    # Create the neuron pattern
    %{
      sensor_id_to_idx_map: sensor_id_to_idx_map,
      actuator_id_to_idx_map: actuator_id_to_idx_map,
      total_neuron_count: sensor_fanout,
      output_neuron_count: actuator_fanin,
      bias_as_neuron: true
    }
  end
  
  # Private helpers
  
  # Create sensor ID to neuron index mapping
  defp create_sensor_mapping(sensors, start_idx) do
    Enum.reduce(sensors, {%{}, start_idx}, fn sensor, {map, idx} ->
      end_idx = idx + sensor.fanout
      updated_map = Map.put(map, sensor.id, {idx, end_idx})
      {updated_map, end_idx}
    end)
    |> elem(0)  # Return just the map
  end
  
  # Create actuator ID to neuron index mapping
  defp create_actuator_mapping(actuators, start_idx) do
    Enum.reduce(actuators, {%{}, start_idx}, fn actuator, {map, idx} ->
      end_idx = idx + actuator.fanin
      updated_map = Map.put(map, actuator.id, {idx, end_idx})
      {updated_map, end_idx}
    end)
    |> elem(0)  # Return just the map
  end
  
  # Get the appropriate module for a sensor type
  defp get_module_for_sensor(sensor) do
    case Map.get(sensor, :type) do
      :trading -> Bardo.Examples.Applications.AlgoTrading.TradingSensor
      :substrate -> Bardo.AgentManager.Sensor
      _ -> Bardo.AgentManager.Sensor
    end
  end
  
  # Get the appropriate module for an actuator type
  defp get_module_for_actuator(actuator) do
    case Map.get(actuator, :type) do
      :trading -> Bardo.Examples.Applications.AlgoTrading.TradingActuator
      :substrate -> Bardo.AgentManager.Actuator
      _ -> Bardo.AgentManager.Actuator
    end
  end
  
  # Generate default substrate CPPs based on dimensions and plasticity
  defp get_default_substrate_cpps(dimensions, plasticity) do
    case plasticity do
      plasticity when plasticity in [:iterative, :abcn] ->
        std = [
          Models.sensor(%{
            id: nil,
            name: :cartesian,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (dimensions * 2 + 3),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :centripital_distances,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (2 + 3),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_distance,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (1 + 3),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_coord_diffs,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (dimensions + 3),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_gaussed_coord_diffs,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (dimensions + 3),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :iow,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 3,
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          })
        ]
        
        adt = case dimensions do
          2 ->
            [
              Models.sensor(%{
                id: nil,
                name: :polar,
                type: :substrate,
                cx_id: nil,
                scape: nil,
                vl: (dimensions * 2 + 3),
                fanout_ids: [],
                generation: nil,
                format: nil,
                parameters: nil
              })
            ]
          3 ->
            [
              Models.sensor(%{
                id: nil,
                name: :spherical,
                type: :substrate,
                cx_id: nil,
                scape: nil,
                vl: (dimensions * 2 + 3),
                fanout_ids: [],
                generation: nil,
                format: nil,
                parameters: nil
              })
            ]
          _ ->
            []
        end
        
        std ++ adt
        
      :none ->
        std = [
          Models.sensor(%{
            id: nil,
            name: :cartesian,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: (dimensions * 2),
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :centripital_distances,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 2,
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_distance,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 1,
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_coord_diffs,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: dimensions,
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          }),
          Models.sensor(%{
            id: nil,
            name: :cartesian_gaussed_coord_diffs,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: dimensions,
            fanout_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          })
        ]
        
        adt = case dimensions do
          2 ->
            [
              Models.sensor(%{
                id: nil,
                name: :polar,
                type: :substrate,
                cx_id: nil,
                scape: nil,
                vl: (dimensions * 2),
                fanout_ids: [],
                generation: nil,
                format: nil,
                parameters: nil
              })
            ]
          3 ->
            [
              Models.sensor(%{
                id: nil,
                name: :spherical,
                type: :substrate,
                cx_id: nil,
                scape: nil,
                vl: (dimensions * 2),
                fanout_ids: [],
                generation: nil,
                format: nil,
                parameters: nil
              })
            ]
          _ ->
            []
        end
        
        std ++ adt
        
      _ ->
        []
    end
  end
  
  # Generate default substrate CEPs based on plasticity
  defp get_default_substrate_ceps(_dimensions, plasticity) do
    case plasticity do
      :iterative ->
        [
          Models.actuator(%{
            id: nil,
            name: :delta_weight,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 1,
            fanin_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          })
        ]
        
      :abcn ->
        [
          Models.actuator(%{
            id: nil,
            name: :set_abcn,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 5,
            fanin_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          })
        ]
        
      :none ->
        [
          Models.actuator(%{
            id: nil,
            name: :set_weight,
            type: :substrate,
            cx_id: nil,
            scape: nil,
            vl: 1,
            fanin_ids: [],
            generation: nil,
            format: nil,
            parameters: nil
          })
        ]
        
      _ ->
        []
    end
  end
end