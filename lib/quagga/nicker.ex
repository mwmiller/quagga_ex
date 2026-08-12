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

    {:noreply,
     %{
       public: public,
       announce_freq: cd[:af],
       gossip_wait: cd[:gw],
       fresh_announce: cd[:fresh]
     }}
  end

  @impl true
  def handle_info(
        :announce,
        %{
          gossip_wait: gossip_wait,
          fresh_announce: fresh_announce,
          public: %{:wait_for_log => pub, "clump_id" => clump_id, "nicker_log_id" => nli} = public
        } = state
      ) do
    Logger.info("Nicker entering announce gossip wait: " <> clump_id)

    # A node's oasis is written under its own public key. On a normal boot the
    # local Baobab spool is empty, but peers may still hold this node's
    # *previous* oasis logs (replicated before the last restart). If we started
    # writing at sequence number 1 before those old logs came back, the
    # late-arriving history would fork our log.
    #
    # Two ways out of the wait:
    #   * fresh_announce  -> this is a brand-new identity, so no peer can hold
    #                        our logs; safe to announce at sequence number 1.
    #   * max_seqnum != 0 -> our own oasis logs have been gossiped back from the
    #                        network, so we continue from the global max.
    ready? = fresh_announce or Baobab.max_seqnum(pub, log_id: nli, clump_id: clump_id) != 0

    if ready? do
      Logger.info("Nicker exiting announce ->  ready: " <> clump_id)
      Process.send(self(), :announce, [])
      {:noreply, Map.merge(state, %{public: Map.drop(public, [:wait_for_log])})}
    else
      Logger.info("Nicker announce blocked waiting for own logs: " <> clump_id)
      Process.send_after(self(), :announce, gossip_wait, [])
      {:noreply, state}
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
      af: Keyword.get(clump_def, :announce_freq, {24, :hour}) |> Baby.Util.period_to_ms(),
      fresh: Keyword.get(clump_def, :fresh_announce, false)
    }
  end

  @doc false
  def fill_out_pubset(pubset, unpacked) do
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
