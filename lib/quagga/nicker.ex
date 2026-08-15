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
          announce_freq: announce_freq,
          public: %{:wait_for_log => pk, "clump_id" => clump_id, "nicker_log_id" => nli} = public
        } = state
      ) do
    Logger.info("Nicker entering announce gossip wait: " <> clump_id)

    # A node's oasis is written under its own public key. On a normal boot the
    # local Baobab spool is empty, but peers may still hold this node's
    # *previous* oasis logs (replicated before the last restart). If we started
    # writing at sequence number 1 before those old logs came back, the
    # late-arriving history would fork our log.
    cond do
      # Brand-new identity: no peer can hold our logs, so announce at
      # sequence number 1 without waiting.
      fresh_announce ->
        Logger.info("Nicker exiting announce -> ready (fresh): " <> clump_id)
        Process.send(self(), :announce, [])
        {:noreply, Map.merge(state, %{public: Map.drop(public, [:wait_for_log])})}

      # Our own logs have not yet gossiped back from the network.
      Baobab.max_seqnum(pk, log_id: nli, clump_id: clump_id) == 0 ->
        Logger.info("Nicker announce blocked waiting for own logs: " <> clump_id)
        Process.send_after(self(), :announce, gossip_wait, [])
        {:noreply, state}

      # Our own logs are back, so we continue from the global max sequence
      # number. Hold the next announcement until it is due on the previous
      # announcement's cadence, so a redeploy does not reannounce (and reset
      # the schedule) ahead of time -- unless the advertised address changed
      # (e.g. the node moved), in which case the new address must go out
      # immediately rather than waiting out the old cadence.
      true ->
        case next_announce_delay(public, pk, nli, clump_id, announce_freq) do
          {:now, :address_changed} ->
            Logger.info("Nicker announce address changed, announcing now: " <> clump_id)
            Process.send(self(), :announce, [])

          {:now, _} ->
            Logger.info("Nicker exiting announce -> ready: " <> clump_id)
            Process.send(self(), :announce, [])

          {:hold, delay} ->
            Logger.info("Nicker next announce due in #{div(delay, 1000)} s: " <> clump_id)
            Process.send_after(self(), :announce, delay, [])
        end

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

  @doc false
  # The decoded CBOR map of this node's most recent announcement, or `:error`
  # when it cannot be read (e.g. the log has not fully returned yet).
  def last_announcement(pk, nli, clump_id) do
    with %Baobab.Entry{payload: payload} <-
           Baobab.log_entry(pk, :max, log_id: nli, clump_id: clump_id),
         {:ok, map, ""} <- CBOR.decode(payload) do
      {:ok, map}
    else
      _ -> :error
    end
  end

  @doc false
  # Whether the configured announcement pubset advertises a different address
  # than the previous announcement. A missing field on either side counts as a
  # change so nothing is silently advertised on stale data.
  def address_changed?(pubset, last) do
    Map.get(pubset, "host") != Map.get(last, "host") or
      Map.get(pubset, "port") != Map.get(last, "port")
  end

  # Decide whether to announce now or hold to the cadence. An announcement is
  # due immediately when the advertised address changed, when it is already
  # past due, or when the previous announcement cannot be read. The address
  # check comes first so a key that moved host/port does not respect the
  # previous announcement's cadence.
  defp next_announce_delay(public, pk, nli, clump_id, announce_freq) do
    case last_announcement(pk, nli, clump_id) do
      {:ok, last} ->
        cond do
          address_changed?(public, last) -> {:now, :address_changed}
          cadence_delay(last, announce_freq) <= 0 -> {:now, :due}
          true -> {:hold, cadence_delay(last, announce_freq)}
        end

      _ ->
        {:now, :due}
    end
  end

  @doc false
  # Milliseconds until the next announcement is due, based on the `running`
  # timestamp of a previous announcement. A non-positive result (or -1 when
  # the timestamp cannot be parsed) means an announcement is due immediately.
  def cadence_delay(last, announce_freq) do
    case parse_running(Map.get(last, "running")) do
      {:ok, last} -> announce_freq - DateTime.diff(DateTime.now!("Etc/UTC"), last, :millisecond)
      _ -> -1
    end
  end

  @doc false
  # Parse an announcement `running` timestamp. Newer entries are written with
  # `DateTime.to_string/1` (space-separated), so normalise to ISO 8601 before
  # parsing to also accept the "T" separator.
  def parse_running(running) when is_binary(running) do
    running
    |> String.replace(" ", "T")
    |> DateTime.from_iso8601()
    |> case do
      {:ok, dt, _} -> {:ok, dt}
      _ -> :error
    end
  end

  def parse_running(_), do: :error
end
