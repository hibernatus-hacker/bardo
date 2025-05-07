defmodule Bardo.FunctionsTest do
  use ExUnit.Case, async: true
  alias Bardo.Functions
  
  test "saturation constrains values to range" do
    assert Functions.saturation(1500.0) == 1000.0
    assert Functions.saturation(-1500.0) == -1000.0
    assert Functions.saturation(-500.0) == -500.0
    
    assert Functions.saturation(1500.0, 500.0) == 500.0
    assert Functions.saturation(-1500.0, 500.0) == -500.0
    assert Functions.saturation(-250.0, 500.0) == -250.0
  end
  
  test "scale transforms values" do
    assert Functions.scale([12.3, 5.5], 5.6, 3.2) == [6.583333333333335, 0.9166666666666665]
  end
  
  test "sat function constrains values to range" do
    assert Functions.sat(1500.0, 500.0, 750.0) == 750.0
    assert Functions.sat(-1500.0, 500.0, 750.0) == 500.0
    assert Functions.sat(-250.0, 500.0, 750.0) == 500.0
  end
  
  test "sat_dzone function zeroes values in deadzone range" do
    assert Functions.sat_dzone(550.0, 250.0, 750.0, 600.0, 500.0) == 0.0
    assert Functions.sat_dzone(1500.0, 250.0, 750.0, 500.0, 600.0) == 750.0
  end
  
  test "tanh function returns hyperbolic tangent" do
    assert_in_delta Functions.tanh(3.0), 0.9950547536867305, 0.000001
  end
  
  test "relu function returns rectified linear unit" do
    assert Functions.relu(-3.0) == 0.0
    assert Functions.relu(3.0) == 3.0
  end
  
  test "cos function returns cosine" do
    assert_in_delta Functions.cos(3.0), -0.9899924966004454, 0.000001
  end
  
  test "sin function returns sine" do
    assert_in_delta Functions.sin(3.0), 0.1411200080598672, 0.000001
  end
  
  test "sgn function returns sign" do
    assert Functions.sgn(0) == 0
    assert Functions.sgn(3) == 1
    assert Functions.sgn(-5) == -1
  end
  
  test "bin function returns binary value" do
    assert Functions.bin(0) == 0
    assert Functions.bin(3) == 1
    assert Functions.bin(-5) == 0
  end
  
  test "trinary function returns trinary value" do
    assert Functions.trinary(0.11) == 0
    assert Functions.trinary(44.3) == 1
    assert Functions.trinary(-5.44) == -1
  end
  
  test "multiquadric function" do
    assert_in_delta Functions.multiquadric(0.24), 0.26, 0.000001
  end
  
  test "absolute function returns absolute value" do
    assert Functions.absolute(-23.24) == 23.24
  end
  
  test "linear function returns input value" do
    assert Functions.linear(3.24) == 3.24
  end
  
  test "quadratic function returns squared value with sign" do
    assert_in_delta Functions.quadratic(13.24), 175.29760000000002, 0.000001
  end
  
  test "gaussian function" do
    assert_in_delta Functions.gaussian(13.24), 3.7200757651350987e-44, 1.0e-45
    assert_in_delta Functions.gaussian(130.24), 3.7200757651350987e-44, 1.0e-45
    assert_in_delta Functions.gaussian(3.24), 2.7602616032381225e-5, 1.0e-7
    
    assert_in_delta Functions.gaussian(2, 13.24), 7.888609052210118e-31, 1.0e-32
    assert_in_delta Functions.gaussian(2, 130.24), 7.888609052210118e-31, 1.0e-32
    assert_in_delta Functions.gaussian(2, 3.24), 6.91683662039504e-4, 1.0e-7
  end
  
  test "sqrt function returns square root with sign" do
    assert Functions.sqrt(4.0) == 2.0
  end
  
  test "log function returns natural log with sign" do
    assert Functions.log(0.0) == 0.0
    assert_in_delta Functions.log(10.0), 2.302585092994046, 0.000001
    assert_in_delta Functions.log(100.0), 4.605170185988092, 0.000001
    assert_in_delta Functions.log(10000.0), 9.210340371976184, 0.000001
  end
  
  test "sigmoid function returns logistic function" do
    assert_in_delta Functions.sigmoid(15.0), 0.9999546021312976, 0.000001
    assert_in_delta Functions.sigmoid(150.0), 0.9999546021312976, 0.000001
    assert_in_delta Functions.sigmoid(0.123123), 0.5307419243727364, 0.000001
    assert_in_delta Functions.sigmoid(-12.0), 4.5397868702434395e-5, 1.0e-7
    assert_in_delta Functions.sigmoid(-120.0), 4.5397868702434395e-5, 1.0e-7
  end
  
  test "sigmoid1 function" do
    assert_in_delta Functions.sigmoid1(15.0), 0.9375, 0.000001
    assert_in_delta Functions.sigmoid1(0.123123), 0.10962557084130588, 0.000001
    assert_in_delta Functions.sigmoid1(-12.0), -0.9230769230769231, 0.000001
  end
  
  test "avg function calculates average of list" do
    assert Functions.avg([1.0, 3.0, 5.0, 7.0]) == 4.0
  end
  
  test "normalize function" do
    normalized = Functions.normalize([1.0, 3.0, 5.0, 2.0])
    expected = [0.16012815380508713, 0.48038446141526137, 0.8006407690254357, 0.32025630761017426]
    
    Enum.zip(normalized, expected)
    |> Enum.each(fn {actual, expect} ->
      assert_in_delta actual, expect, 0.000001
    end)
  end
  
  test "vector_difference calculates component-wise differences" do
    result = Functions.vector_difference([1.0, 3.0, 5.0], [0.234, 0.435, 0.452])
    expected = [-0.766, -2.565, -4.548]
    
    Enum.zip(result, expected)
    |> Enum.each(fn {actual, expect} ->
      assert_in_delta actual, expect, 0.001
    end)
    
    # With additional elements
    result2 = Functions.vector_difference([1.0, 3.0, 5.0], [0.234, 0.435, 0.452], [5.0, 2.0, 3.4])
    expected2 = [3.4, 2.0, 5.0, -0.766, -2.565, -4.548]
    
    Enum.zip(result2, expected2)
    |> Enum.each(fn {actual, expect} ->
      assert_in_delta actual, expect, 0.001
    end)
  end
  
  test "distance calculates Euclidean distance" do
    assert_in_delta Functions.distance([1.0, 3.0, 5.0], [0.234, 0.435, 0.452]), 5.277336923108093, 0.000001
    assert_in_delta Functions.distance([1.0, 3.0, 5.0], [0.234, 0.435, 0.452], 12.1234), 6.322474594650421, 0.000001
  end
end