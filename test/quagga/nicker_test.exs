defmodule Quagga.NickerTest do
  use ExUnit.Case, async: true

  alias Quagga.Nicker

  @unpacked %{
    cid: "Quagga",
    port: 8483,
    id: "fly",
    sk: "secret",
    op: "operator_pubkey",
    pk: "controlling_pubkey",
    gw: 1_000,
    af: 2_000
  }

  describe "init/1" do
    test "stops normally when the clump is not public" do
      assert {:stop, :normal} = Nicker.init(id: "Quagga", port: 8483)
    end

    test "defers startup when the clump is public" do
      pubset = %{"name" => "Quagga ORD"}
      clump_def = [id: "Quagga", port: 8483, public: pubset]

      assert {:ok, state, {:continue, :startup}} = Nicker.init(clump_def)
      assert state.public == pubset
      assert state.clump_def == clump_def
    end
  end

  describe "fill_out_pubset/2" do
    test "merges identity, clump, port and log metadata" do
      pubset = %{"name" => "Quagga ORD", "host" => "quagga.zebrine.net"}

      pub = Nicker.fill_out_pubset(pubset, @unpacked)

      assert pub["name"] == "Quagga ORD"
      assert pub["host"] == "quagga.zebrine.net"
      assert pub["identity"] == "fly"
      assert pub["clump_id"] == "Quagga"
      assert pub["port"] == 8483
      assert pub[:wait_for_log] == "controlling_pubkey"
      assert pub["nicker_log_id"] == QuaggaDef.facet_log(:oasis, 0)
    end

    test "defaults the facet_id to 0" do
      pub = Nicker.fill_out_pubset(%{"name" => "Quagga"}, @unpacked)
      assert pub["nicker_log_id"] == QuaggaDef.facet_log(:oasis, 0)
    end

    test "honours an explicit facet_id" do
      pub = Nicker.fill_out_pubset(%{"name" => "Dazzle", "facet_id" => 1}, @unpacked)
      assert pub["nicker_log_id"] == QuaggaDef.facet_log(:oasis, 1)
    end

    test "includes the operator key when present" do
      pub = Nicker.fill_out_pubset(%{"name" => "Quagga"}, @unpacked)
      assert pub["operator"] == "operator_pubkey"
    end

    test "omits the operator key when absent" do
      pub = Nicker.fill_out_pubset(%{"name" => "Quagga"}, %{@unpacked | op: nil})
      refute Map.has_key?(pub, "operator")
    end
  end

  describe "parse_running/1" do
    test "parses the space-separated DateTime.to_string/1 format" do
      assert {:ok, dt} = Nicker.parse_running("2026-08-15 10:53:37.234567Z")
      assert dt == ~U[2026-08-15 10:53:37.234567Z]
    end

    test "parses the ISO 8601 T-separated format" do
      assert {:ok, dt} = Nicker.parse_running("2026-08-15T10:53:37.234567Z")
      assert dt == ~U[2026-08-15 10:53:37.234567Z]
    end

    test "parses timestamps without fractional seconds" do
      assert {:ok, dt} = Nicker.parse_running("2026-08-15 10:53:37Z")
      assert dt == ~U[2026-08-15 10:53:37Z]
    end

    test "rejects garbage" do
      assert :error = Nicker.parse_running("not a timestamp")
      assert :error = Nicker.parse_running(42)
    end
  end
end
