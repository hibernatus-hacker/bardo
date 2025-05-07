defmodule Bardo.Functions do
  @moduledoc """
  The Functions module contains the activation functions used by the
  neuron, and other mathematical functions used by the system. Through
  the Functions module, the activation functions are fully decoupled
  from the neurons using them. A neuron can use any activation
  function, no matter its form, as long as it returns a properly
  formatted value.
  
  NOTE: While the activation functions are all stored in the Functions module,
  the aggregation and the plasticity functions are stored in the SignalAggregator
  and Plasticity modules respectively.
  """

  @doc """
  The function saturation/1 accepts a value val, and returns the same if
  its magnitude is below 1000. Otherwise it returns -1000 or 1000, if
  it's less than or greater than -1000 or 1000 respectively. Thus val
  saturates at -1000 and 1000.
  """
  @spec saturation(float()) :: float()
  def saturation(val) do
    cond do
      val > 1000.0 -> 1000.0
      val < -1000.0 -> -1000.0
      true -> val
    end
  end

  @doc """
  The saturation/2 function is similar to saturation/1, but here the
  spread (symmetric max and min values) is specified by the caller.
  """
  @spec saturation(float(), float()) :: float()
  def saturation(val, spread) do
    cond do
      val > spread -> spread
      val < -spread -> -spread
      true -> val
    end
  end

  @doc """
  The scale/3 function accepts a list of values, and scales them to be
  between the specified min and max values.
  """
  @spec scale(float() | [float()], float(), float()) :: float() | [float()]
  def scale([h | t], max, min) do
    Enum.map([h | t], fn val -> scale(val, max, min) end)
  end

  def scale(val, max, min) do
    if max == min do
      0.0
    else
      (val * 2 - (max + min)) / (max - min)
    end
  end

  @doc """
  The sat/3 function is similar to saturation/2 function, but here the
  max and min can be different, and are specified by the caller.
  """
  @spec sat(float(), float(), float()) :: float()
  def sat(val, min, _max) when val < min, do: min
  def sat(val, _min, max) when val > max, do: max
  def sat(val, _min, _max), do: val

  @doc """
  The sat_dzone/5 function is similar to the sat/3 function, but here,
  if val is between dzmin and dzmax, it is zeroed.
  """
  @spec sat_dzone(float(), float(), float(), float(), float()) :: float()
  def sat_dzone(val, max, min, dzmax, dzmin) do
    if val < dzmax and val > dzmin do
      0.0
    else
      sat(val, max, min)
    end
  end

  # Activation functions

  @spec tanh(float()) :: float()
  def tanh(val), do: :math.tanh(val)

  @spec relu(float()) :: float()
  def relu(val), do: max(0.0, val)

  @spec cos(float()) :: float()
  def cos(val), do: :math.cos(val)

  @spec sin(float()) :: float()
  def sin(val), do: :math.sin(val)

  @spec sgn(float()) :: -1 | 0 | 1
  def sgn(0), do: 0
  def sgn(val) when val > 0, do: 1
  def sgn(val) when val < 0, do: -1

  @doc """
  The bin/1 function converts val into a binary value, 1 if val > 0,
  and 0 if val <= 0.
  """
  @spec bin(float()) :: 0 | 1
  def bin(val) when val > 0, do: 1
  def bin(_val), do: 0

  @doc """
  The trinary/1 function converts val into a trinary value.
  """
  @spec trinary(float()) :: -1 | 0 | 1
  def trinary(val) when val < 0.33 and val > -0.33, do: 0
  def trinary(val) when val >= 0.33, do: 1
  def trinary(val) when val <= -0.33, do: -1

  @spec multiquadric(float()) :: float()
  def multiquadric(val), do: :math.pow(val * val + 0.01, 0.5)

  @spec absolute(float()) :: float()
  def absolute(val), do: abs(val)

  @spec linear(float()) :: float()
  def linear(val), do: val

  @spec quadratic(float()) :: float()
  def quadratic(val), do: sgn(val) * val * val

  @spec gaussian(float()) :: float()
  def gaussian(val), do: gaussian(2.71828183, val)

  @spec gaussian(float(), float()) :: float()
  def gaussian(const, val) do
    v = cond do
      val > 10.0 -> 10.0
      val < -10.0 -> -10.0
      true -> val
    end
    :math.pow(const, -v * v)
  end

  @spec sqrt(float()) :: float()
  def sqrt(val), do: sgn(val) * :math.sqrt(abs(val))

  @spec log(float()) :: float()
  def log(0.0), do: 0.0
  def log(val), do: sgn(val) * :math.log(abs(val))

  @spec sigmoid(float()) :: float()
  def sigmoid(val) do
    v = cond do
      val > 10.0 -> 10.0
      val < -10.0 -> -10.0
      true -> val
    end
    1 / (1 + :math.exp(-v))
  end

  @spec sigmoid1(float()) :: float()
  def sigmoid1(val), do: val / (1 + abs(val))

  @doc """
  The avg/1 function accepts a list for a parameter, and then returns
  the average of the list to the caller.
  """
  @spec avg([float()]) :: float()
  def avg(list), do: Enum.sum(list) / length(list)

  @doc """
  The std/1 function accepts a list for a parameter, and then returns to
  the caller the standard deviation of the list.
  """
  @spec std([float()]) :: float()
  def std(list) do
    avg = avg(list)
    std(list, avg, [])
  end

  @spec std([float()], float(), [float()]) :: float()
  def std([val | list], avg, acc) do
    std(list, avg, [:math.pow(avg - val, 2.0) | acc])
  end

  def std([], _avg, acc) do
    variance = Enum.sum(acc) / length(acc)
    :math.sqrt(variance)
  end

  # Coordinate operators

  @spec cartesian([float()], [float()]) :: [float()]
  def cartesian(icoord, coord), do: icoord ++ coord

  @spec polar([float()], [float()]) :: [float()]
  def polar(icoord, coord), do: cart2pol(icoord) ++ cart2pol(coord)

  @spec spherical([float()], [float()]) :: [float()]
  def spherical(icoord, coord), do: cart2spher(icoord) ++ cart2spher(coord)

  @spec centripital_distances([float()], [float()]) :: [float()]
  def centripital_distances(icoord, coord) do
    [centripital_distance(icoord, 0.0), centripital_distance(coord, 0.0)]
  end

  @spec cartesian_distance([float()], [float()]) :: [float()]
  def cartesian_distance(icoord, coord), do: [calculate_distance(icoord, coord, 0.0)]

  @spec cartesian_coord_diffs([float()], [float()]) :: [float()]
  def cartesian_coord_diffs(icoord, coord), do: cartesian_coord_diffs1(icoord, coord, [])

  @spec cartesian_gaussed_coord_diffs([float()], [float()]) :: [float()]
  def cartesian_gaussed_coord_diffs(from_coords, to_coords) do
    cartesian_gaussed_coord_diffs1(from_coords, to_coords, [])
  end

  @spec cartesian_gaussed_coord_diffs1([float()], [float()], [float()]) :: [float()]
  def cartesian_gaussed_coord_diffs1([from_coord | from_coords], [to_coord | to_coords], acc) do
    cartesian_gaussed_coord_diffs1(from_coords, to_coords, [gaussian(to_coord - from_coord) | acc])
  end

  def cartesian_gaussed_coord_diffs1([], [], acc), do: Enum.reverse(acc)

  @spec cartesian([float()], [float()], [float()]) :: [float()]
  def cartesian(icoord, coord, [i, o, w]), do: [i, o, w | icoord ++ coord]

  @spec polar([float()], [float()], [float()]) :: [float()]
  def polar(icoord, coord, [i, o, w]), do: [i, o, w | cart2pol(icoord) ++ cart2pol(coord)]

  @spec spherical([float()], [float()], [float()]) :: [float()]
  def spherical(icoord, coord, [i, o, w]), do: [i, o, w | cart2spher(icoord) ++ cart2spher(coord)]

  @spec centripital_distances([float()], [float()], [float()]) :: [float()]
  def centripital_distances(icoord, coord, [i, o, w]) do
    [i, o, w, centripital_distance(icoord, 0.0), centripital_distance(coord, 0.0)]
  end

  @spec cartesian_distance([float()], [float()], [float()]) :: [float()]
  def cartesian_distance(icoord, coord, [i, o, w]) do
    [i, o, w, calculate_distance(icoord, coord, 0.0)]
  end

  @spec cartesian_coord_diffs([float()], [float()], [float()]) :: [float()]
  def cartesian_coord_diffs(from_coords, to_coords, [i, o, w]) do
    [i, o, w | cartesian_coord_diffs(from_coords, to_coords)]
  end

  @spec cartesian_gaussed_coord_diffs([float()], [float()], [float()]) :: [float()]
  def cartesian_gaussed_coord_diffs(from_coords, to_coords, [i, o, w]) do
    [i, o, w | cartesian_gaussed_coord_diffs(from_coords, to_coords)]
  end

  @spec iow([float()], [float()], [float()]) :: [float()]
  def iow(_icoord, _coord, iow), do: iow

  @spec to_cartesian({:cartesian, any()} | {:polar, {float(), float()}} | {:spherical, {float(), float(), float()}}) :: {:cartesian, any()}
  def to_cartesian(direction) do
    case direction do
      {:spherical, coordinates} ->
        {:cartesian, spherical2cartesian(coordinates)}
      {:polar, coordinates} ->
        {:cartesian, polar2cartesian(coordinates)}
      {:cartesian, coordinates} ->
        {:cartesian, coordinates}
    end
  end

  @spec normalize([float()]) :: [float()]
  def normalize(vector) do
    normalizer = calculate_normalizer(vector, 0.0)
    normalize(vector, normalizer, [])
  end

  @spec spherical2cartesian({float(), float(), float()}) :: {float(), float(), float()}
  def spherical2cartesian({p, theta, phi}) do
    x = p * :math.sin(phi) * :math.cos(theta)
    y = p * :math.sin(phi) * :math.sin(theta)
    z = p * :math.cos(phi)
    {x, y, z}
  end

  @spec cartesian2spherical({float(), float()} | {float(), float(), float()}) :: {float(), float(), float()}
  def cartesian2spherical({x, y}), do: cartesian2spherical({x, y, 0.0})
  def cartesian2spherical({x, y, z}) do
    pre_r = x * x + y * y
    r = :math.sqrt(pre_r)
    p = :math.sqrt(pre_r + z * z)
    theta = theta(r, x, y)
    phi = phi(p, z)
    {p, theta, phi}
  end

  @spec polar2cartesian({float(), float()}) :: {float(), float(), float()}
  def polar2cartesian({r, theta}) do
    x = r * :math.cos(theta)
    y = r * :math.sin(theta)
    {x, y, 0.0}
  end

  @spec cartesian2polar({float(), float()} | {float(), float(), any()}) :: {float(), float()}
  def cartesian2polar({x, y}), do: cartesian2polar({x, y, 0.0})
  def cartesian2polar({x, y, _z}) do
    r = :math.sqrt(x * x + y * y)
    theta = theta(r, x, y)
    {r, theta}
  end

  @spec distance([float()], [float()]) :: float()
  def distance(vector1, vector2), do: distance(vector1, vector2, 0.0)

  @spec distance([float()], [float()], float()) :: float()
  def distance([val1 | vector1], [val2 | vector2], acc) do
    distance(vector1, vector2, acc + :math.pow(val2 - val1, 2.0))
  end
  def distance([], [], acc), do: :math.sqrt(acc)

  @spec vector_difference([float()], [float()]) :: [float()]
  def vector_difference(vector1, vector2), do: vector_difference(vector1, vector2, [])

  @spec vector_difference([float()], [float()], [float()]) :: [float()]
  def vector_difference([val1 | vector1], [val2 | vector2], acc) do
    vector_difference(vector1, vector2, [val2 - val1 | acc])
  end
  def vector_difference([], [], acc), do: Enum.reverse(acc)

  # Internal functions

  @spec phi(float(), float()) :: float()
  defp phi(_p = 0.0, _z), do: 0.0
  defp phi(p, z), do: :math.acos(z / p)

  @spec cartesian_coord_diffs1([float()], [float()], [float()]) :: [float()]
  defp cartesian_coord_diffs1([from_coord | from_coords], [to_coord | to_coords], acc) do
    cartesian_coord_diffs1(from_coords, to_coords, [to_coord - from_coord | acc])
  end
  defp cartesian_coord_diffs1([], [], acc), do: Enum.reverse(acc)

  @spec cart2pol([float()]) :: [float()]
  defp cart2pol([y, x]) do
    r = :math.sqrt(x * x + y * y)
    theta = theta(r, x, y)
    [r, theta]
  end

  @spec cart2spher([float()]) :: [float()]
  defp cart2spher([z, y, x]) do
    pre_r = x * x + y * y
    r = :math.sqrt(pre_r)
    p = :math.sqrt(pre_r + z * z)
    theta = theta(r, x, y)
    phi = phi(p, z)
    [p, theta, phi]
  end

  @spec theta(float(), float(), float()) :: float()
  defp theta(0.0, _x, _y), do: 0.0
  defp theta(_r, x, y), do: theta_false_case(x, y)

  @spec theta_false_case(float(), float()) :: float()
  defp theta_false_case(x, y) when x > 0.0 and y >= 0.0, do: :math.atan(y / x)
  defp theta_false_case(x, y) when x > 0.0 and y < 0.0, do: :math.atan(y / x) + 2 * :math.pi()
  defp theta_false_case(x, y) when x < 0.0, do: :math.atan(y / x) + :math.pi()
  defp theta_false_case(0.0, y) when y > 0.0, do: :math.pi() / 2
  defp theta_false_case(0.0, y) when y < 0.0, do: 3 * :math.pi() / 2

  @spec centripital_distance([float()], float()) :: float()
  defp centripital_distance([val | coord], acc) do
    centripital_distance(coord, val * val + acc)
  end
  defp centripital_distance([], acc), do: :math.sqrt(acc)

  @spec calculate_distance([float()], [float()], float()) :: float()
  defp calculate_distance([val1 | coord1], [val2 | coord2], acc) do
    distance = val2 - val1
    calculate_distance(coord1, coord2, distance * distance + acc)
  end
  defp calculate_distance([], [], acc), do: :math.sqrt(acc)

  @spec calculate_normalizer([float()], float()) :: float()
  defp calculate_normalizer([val | vector], acc) do
    calculate_normalizer(vector, val * val + acc)
  end
  defp calculate_normalizer([], acc), do: :math.sqrt(acc)

  @spec normalize([float()], float(), [float()]) :: [float()]
  defp normalize([val | vector], normalizer, acc) do
    normalize(vector, normalizer, [val / normalizer | acc])
  end
  defp normalize([], _normalizer, acc), do: Enum.reverse(acc)
end