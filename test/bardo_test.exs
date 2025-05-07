defmodule BardoTest do
  use ExUnit.Case
  doctest Bardo

  test "greets the world" do
    assert Bardo.hello() == :world
  end
end
