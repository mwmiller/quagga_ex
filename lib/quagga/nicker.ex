defmodule Quagga.Nicker do
  @moduledoc """
  The public greeting announcement of a Quagga instance
  """
  use GenServer
  require Logger

  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(clump_def) do
    case Keyword.get(clump_def, :public) do
      # Not set as public, drop out
      nil -> {:stop, :normal}
      pub -> {:ok, %{public: pub, clump_def: clump_def}, {:continue, :startup}}
    end
  end

  @impl true
  def handle_continue(:startup, %{public: pubset, clump_def: clump_def}) do
    cd = unpack_clump_def(clump_def)
    Logger.info("Nicker starting up: " <> cd[:cid])
    public = fill_out_pubset(pubset, cd)
    Process.send_after(self(), :announce, cd[:gw], [])
    Logger.info("Nicker startup complete -> gossip wait: " <> cd[:cid])
    {:noreply, %{public: public, announce_freq: cd[:af], gossip_wait: cd[:gw]}}
  end

  @impl true
  def handle_info(
        :announce,
        %{
          gossip_wait: gossip_wait,
          public: %{:wait_for_log => pub, "clump_id" => clump_id, "nicker_log_id" => nli} = public
        } = state
      ) do
    Logger.info("Nicker entering announce gossip wait: " <> clump_id)

    case Baobab.max_seqnum(pub, log_id: nli, clump_id: clump_id) do
      0 ->
        Process.send_after(self(), :announce, gossip_wait, [])
        Logger.info("Nicker exiting announce ->  gossip wait: " <> clump_id)
        {:noreply, state}

      _ ->
        Process.send(self(), :announce, [])
        Logger.info("Nicker exiting announce ->  ready: " <> clump_id)
        {:noreply, Map.merge(state, %{public: Map.drop(public, [:wait_for_log])})}
    end
  end

  def handle_info(
        :announce,
        %{
          announce_freq: announce_freq,
          public:
            %{"identity" => id, "name" => name, "clump_id" => clump_id, "nicker_log_id" => nli} =
              public
        } = state
      ) do
    Logger.info("Nicker entering announce ready: " <> clump_id)

    public
    |> Map.drop(["identity", "nicker_log_id"])
    |> Map.merge(%{"running" => "Etc/UTC" |> DateTime.now!() |> DateTime.to_string()})
    |> CBOR.encode()
    |> Baobab.append_log(id, log_id: nli, clump_id: clump_id)

    Logger.info("Logged public announcement: " <> name)

    Process.send_after(self(), :announce, announce_freq, [])
    Logger.info("Nicker exiting announce ready -> announce_wait: " <> clump_id)
    {:noreply, state}
  end

  def handle_info(:announce, state) do
    Logger.info("Nicker noop -> continue: ")
    {:noreply, state}
  end

  defp unpack_clump_def(clump_def) do
    sk = Keyword.get(clump_def, :controlling_secret)
    id = Keyword.get(clump_def, :controlling_identity)

    %{
      cid: Keyword.get(clump_def, :id),
      port: Keyword.get(clump_def, :port),
      id: id,
      sk: sk,
      op: Keyword.get(clump_def, :operator_key),
      pk: Baobab.Identity.create(id, sk),
      gw: Keyword.get(clump_def, :gossip_wait, {19, :minute}) |> Baby.Util.period_to_ms(),
      af: Keyword.get(clump_def, :announce_freq, {24, :hour}) |> Baby.Util.period_to_ms()
    }
  end

  defp fill_out_pubset(pubset, unpacked) do
    facet_id = Map.get(pubset, "facet_id", 0)

    pub =
      pubset
      |> Map.merge(%{
        :wait_for_log => unpacked[:pk],
        "identity" => unpacked[:id],
        "nicker_log_id" => QuaggaDef.facet_log(:oasis, facet_id),
        "clump_id" => unpacked[:cid],
        "port" => unpacked[:port]
      })

    case unpacked[:op] do
      nil -> pub
      key -> Map.merge(pub, %{"operator" => key})
    end
  end
end
