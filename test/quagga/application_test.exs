defmodule Quagga.ApplicationTest do
  use ExUnit.Case, async: true

  alias Quagga.Application, as: App

  describe "validate_clumps/1" do
    test "accepts no clumps" do
      assert App.validate_clumps([]) == :ok
    end

    test "accepts a well-formed 43-char base62 secret" do
      clump = [id: "Quagga", controlling_secret: String.duplicate("a", 43)]
      assert App.validate_clumps([clump]) == :ok
    end

    test "accepts a 32-byte raw secret" do
      clump = [id: "Quagga", controlling_secret: <<0::size(256)>>]
      assert App.validate_clumps([clump]) == :ok
    end

    test "rejects a missing secret" do
      clump = [id: "Quagga"]
      assert {:error, message} = App.validate_clumps([clump])
      assert message =~ "controlling_secret"
    end

    test "rejects a malformed secret length" do
      clump = [id: "Quagga", controlling_secret: "short"]
      assert {:error, message} = App.validate_clumps([clump])
      assert message =~ "controlling_secret"
    end
  end

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
