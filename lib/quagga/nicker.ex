defmodule Quagga.Nicker do
  @moduledoc """
  The public greeting announcement of a Quagga instance
  """
  use GenServer
  require Logger
  @gossip_wait 179_969
  @announce_freq 86_399_981

  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(clump_def) do
    id = Keyword.get(clump_def, :controlling_identity)
    sk = Keyword.get(clump_def, :controlling_secret)

    pub =
      case sk do
        nil -> Baobab.create_identity(id)
        secret -> Baobab.create_identity(id, secret)
      end

    state =
      case {Keyword.get(clump_def, :public), sk} do
        {nil, _} -> %{}
        {map, nil} -> map
        {map, _} -> Map.put(map, :wait_for_log, pub)
      end

    Process.send_after(self(), :announce, @gossip_wait, [])

    {:ok,
     Map.merge(state, %{
       "identity" => id,
       "clump_id" => Keyword.get(clump_def, :id),
       "port" => Keyword.get(clump_def, :port)
     })}
  end

  @impl true

  def handle_info(
        :announce,
        %{:wait_for_log => pub, "clump_id" => clump_id, "nicker_log_id" => nli} = state
      ) do
    case Baobab.max_seqnum(pub, log_id: nli, clump_id: clump_id) do
      0 ->
        Process.send_after(self(), :announce, @gossip_wait, [])
        {:noreply, state}

      _ ->
        Process.send(self(), :announce, [])
        {:noreply, Map.drop(state, [:wait_for_log])}
    end
  end

  def handle_info(
        :announce,
        %{"identity" => id, "clump_id" => clump_id, "nicker_log_id" => nli} = state
      ) do
    state
    |> Map.drop(["identity", "nicker_log_id"])
    |> Map.merge(%{"running" => "Etc/UTC" |> DateTime.now!() |> DateTime.to_string()})
    |> CBOR.encode()
    |> Baobab.append_log(id, log_id: nli, clump_id: clump_id)

    Logger.info("Logged public announcement")

    Process.send_after(self(), :announce, @announce_freq)
    {:noreply, state}
  end

  def handle_info(:announce, state), do: {:noreply, state}
end
