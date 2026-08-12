defmodule QuaggaTest do
  use ExUnit.Case, async: true

  doctest Quagga

  test "the Quagga module is defined" do
    assert Code.ensure_loaded?(Quagga)
  end
end
