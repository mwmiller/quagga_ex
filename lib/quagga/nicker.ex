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
    cid = Keyword.get(clump_def, :id)
    Logger.info("Nicker entering init: " <> cid)
    id = Keyword.get(clump_def, :controlling_identity)
    sk = Keyword.get(clump_def, :controlling_secret)
    pk = Baobab.Identity.create(id, sk)
    gossip_wait = Keyword.get(clump_def, :gossip_wait, {19, :minute}) |> Baby.Util.period_to_ms()

    announce_freq =
      Keyword.get(clump_def, :announce_frew, {24, :hour}) |> Baby.Util.period_to_ms()

    pubset =
      case {Keyword.get(clump_def, :public), sk} do
        {nil, _} -> %{}
        {map, nil} -> map
        {map, _} -> Map.put(map, :wait_for_log, pk)
      end

    facet_id = Map.get(pubset, "facet_id", 0)

    public =
      Map.merge(pubset, %{
        "identity" => id,
        "nicker_log_id" => QuaggaDef.facet_log(:oasis, facet_id),
        "clump_id" => Keyword.get(clump_def, :id),
        "port" => Keyword.get(clump_def, :port)
      })

    Process.send_after(self(), :announce, gossip_wait, [])
    Logger.info("Nicker init complete -> gossip wait: " <> cid)
    {:ok, %{public: public, announce_freq: announce_freq, gossip_wait: gossip_wait}}
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
    IO.inspect(state)
    {:noreply, state}
  end
end
