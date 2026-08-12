defmodule Quagga.ApplicationTest do
  use ExUnit.Case, async: true

  alias Quagga.Application, as: App

  describe "define_nickers/2" do
    test "returns the accumulator unchanged for no clumps" do
      assert App.define_nickers([], []) == []
      assert App.define_nickers([], [:sentinel]) == [:sentinel]
    end

    test "builds a worker child spec for a single clump" do
      clump = [id: "Quagga", port: 8483]

      assert [nicker] = App.define_nickers([clump], [])

      assert nicker.id == :quagga_nicker_Quagga
      assert nicker.start == {Quagga.Nicker, :start_link, [clump]}
      assert nicker.type == :worker
      assert nicker.restart == :permanent
    end

    test "derives a distinct id from each clump's :id" do
      clumps = [
        [id: "Quagga", port: 8483],
        [id: "Dazzle", port: 8483]
      ]

      nickers = App.define_nickers(clumps, [])

      ids = Enum.map(nickers, & &1.id)
      assert length(nickers) == 2
      assert :quagga_nicker_Quagga in ids
      assert :quagga_nicker_Dazzle in ids
    end

    test "passes the full clump definition through to start_link" do
      clump = [id: "Quagga", port: 8483, public: %{"name" => "Quagga ORD"}]

      assert [%{start: {Quagga.Nicker, :start_link, [^clump]}}] =
               App.define_nickers([clump], [])
    end
  end
end
