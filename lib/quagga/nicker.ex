defmodule Quagga.Nicker do
  @moduledoc """
  The public greeting announcement of a Quagga instance
  """
  use GenServer
  @nicker_log_id 8483
  @gossip_wait 179_969
  @announce_freq 86_399_981

  def start_link(args) when is_list(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init([nil, state]) when is_map(state) do
    Baobab.create_identity(Application.get_env(:baby, :identity))
    Process.send(self(), :announce, [])
    {:ok, state}
  end

  def init([sk, state]) when is_map(state) do
    pub = Baobab.create_identity(Application.get_env(:baby, :identity), sk)
    Process.send_after(self(), :announce, @gossip_wait, [])
    {:ok, Map.put(state, :wait_for_log, pub)}
  end

  # We still want to start up, even though we're not doing anything
  # at present. Someday this will be important, I think
  def init([_, _]), do: {:ok, %{}}

  @impl true
  def handle_info(:announce, state) when map_size(state) == 0, do: {:noreply, state}

  def handle_info(:announce, %{:wait_for_log => pub, "clump_id" => clump_id} = state) do
    case Baobab.max_seqnum(pub, log_id: @nicker_log_id, clump_id: clump_id) do
      0 ->
        Process.send_after(self(), :announce, @gossip_wait, [])
        {:noreply, state}

      _ ->
        Process.send(self(), :announce, [])
        {:noreply, Map.drop(state, [:wait_for_log])}
    end
  end

  def handle_info(:announce, %{"clump_id" => clump_id} = state) do
    state
    |> Map.merge(%{"running" => "Etc/UTC" |> DateTime.now!() |> DateTime.to_string()})
    |> CBOR.encode()
    |> Baobab.append_log(Application.get_env(:baby, :identity),
      log_id: @nicker_log_id,
      clump_id: clump_id
    )

    Process.send_after(self(), :announce, @announce_freq)
    {:noreply, state}
  end
end
