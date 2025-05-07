defmodule Bardo.PopulationManager.Morphology do
  @moduledoc """
  Defines generic morphology behavior.
  The list of morphologies defines the list of sensors and actuators
  available to the NNs in a population. Since the morphology defines
  the sensors and actuators of the NN system, this list effectively
  defines the problem or simulation to which the evolving population of
  NN systems will be applied, and for what purpose the agents will be
  evolved. The sensors/actuators/scape are a separate part from the NN
  itself, all specified through the morphology module.
  """

  alias Bardo.{Models, Utils}

  @doc """
  The get_init_sensors starts the population off with the NN based
  agents using just a single sensor, exploring other available sensors
  within the morphology as it evolves.
  """
  @spec get_init_sensors(atom()) :: [Models.sensor()]
  def get_init_sensors(mod) do
    m = Utils.get_module(mod)
    sensors = apply(m, :sensors, [])
    [List.first(sensors)]
  end

  @doc """
  The get_init_actuators starts the population off with the NN based
  agents using just a single actuator, exploring other available
  actuators within the morphology as it evolves.
  """
  @spec get_init_actuators(atom()) :: [Models.actuator()]
  def get_init_actuators(mod) do
    m = Utils.get_module(mod)
    actuators = apply(m, :actuators, [])
    [List.first(actuators)]
  end

  @doc """
  The get_sensors starts the population off with the NN based
  agents using all available sensors from the start.
  """
  @spec get_sensors(atom()) :: [Models.sensor()]
  def get_sensors(mod) do
    m = Utils.get_module(mod)
    apply(m, :sensors, [])
  end

  @doc """
  The get_actuators starts the population off with the NN based
  agents using all available actuators from the start.
  """
  @spec get_actuators(atom()) :: [Models.actuator()]
  def get_actuators(mod) do
    m = Utils.get_module(mod)
    apply(m, :actuators, [])
  end

  @doc """
  The get_init_substrate_cpps starts the population off with the NN based
  agents using just a single substrate_cpp, exploring other available
  substrate_cpps within the morphology as it evolves.
  """
  @spec get_init_substrate_cpps(integer(), atom()) :: [Models.sensor()]
  def get_init_substrate_cpps(dimensions, plasticity) do
    substrate_cpps = get_substrate_cpps(dimensions, plasticity)
    [List.first(substrate_cpps)]
  end

  @doc """
  The get_init_substrate_ceps starts the population off with the NN based
  agents using just a single substrate_cep, exploring other available
  substrate_ceps within the morphology as it evolves.
  """
  @spec get_init_substrate_ceps(integer(), atom()) :: [Models.actuator()]
  def get_init_substrate_ceps(dimensions, plasticity) do
    substrate_ceps = get_substrate_ceps(dimensions, plasticity)
    [List.first(substrate_ceps)]
  end

  @doc """
  The get_substrate_cpps starts the population off with the NN based
  agents using substrate_cpps determined by Dimensions and Plasticity.
  Substrate CPPs:
  x cartesian: The cartesian cpp simply forwards to the NN the appended
    coordinates of the two connected neurodes. Because each neurode has
    a coordinate specified by a list of length: Dimension, the vector
    specifying the two appended coordinates will have
    vl = Dimensions * 2. For example: [X1,Y1,Z1,X2,Y2,Z2] will have a
    vector length of dimension: vl = 3*2 = 6.
  x centripetal_distances: This cpp uses the Cartesian coordinates of
    the two neurodes to calculate the Cartesian distance of neurode_1
    to the center of the substrate located at the origin, and the
    Cartesian distance of neurode_2 to the center of the substrate.
    It then fans out to the NN the vector of length 2, composed of the
    two distances.
  x cartesian_distance: This cpp calculates the Cartesian distance
    between the two neurodes, forwarding the resulting vector of
    length 1 to the NN.
  x cartesian_CoordDiffs: This cpp calculates the difference between
    each coordinate element of the two neurodes, and thus for this cpp,
    the vl = Dimensions.
  x cartesian_GaussedCoordDiffs: Exactly the same as the above cpp, but
    each of the values is first sent through the Gaussian function
    before it is entered into the vector.
  x polar: This cpp converts the Cartesian coordinates to polar
    coordinates. This can only be done if the substrate is 2d.
  x spherical: This cpp converts the Cartesian coordinates to the
    spherical coordinates. This can only be done if the substrate is 3d.
  """
  @spec get_substrate_cpps(integer(), atom()) :: [Models.sensor()]
  def get_substrate_cpps(dimensions, plasticity) do
    case plasticity == :iterative or plasticity == :abcn do
      true ->
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
        
      false ->
        case plasticity == :none do
          true ->
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
          
          false ->
            []
        end
    end
  end

  @doc """
  The get_substrate_ceps starts the population off with the NN based
  agents using substrate_ceps determined by the Plasticity.
  """
  @spec get_substrate_ceps(integer(), atom()) :: [Models.actuator()]
  def get_substrate_ceps(_dimensions, plasticity) do
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

  @doc """
  Defines the behavior for morphology modules.
  """
  @callback sensors() :: [Models.sensor()]
  @callback actuators() :: [Models.actuator()]
end