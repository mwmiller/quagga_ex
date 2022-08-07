defmodule QuaggaTest do
  use ExUnit.Case
  doctest Quagga

  test "greets the world" do
    assert Quagga.hello() == :world
  end
end
