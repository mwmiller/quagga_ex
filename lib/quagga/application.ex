defmodule Quagga.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:quagga)
    clumps = Keyword.get(config, :clumps, [])

    case validate_clumps(clumps) do
      :ok ->
        nickers = define_nickers(clumps, [])
        babies = [{Baby.Application, config}] ++ nickers

        # See https://hexdocs.pm/elixir/Supervisor.html
        # for other strategies and supported options
        opts = [strategy: :one_for_one, name: Quagga.Supervisor]
        Supervisor.start_link(babies, opts)

      {:error, reason} ->
        Logger.error("Refusing to start Quagga: " <> reason)
        {:error, {:config, reason}}
    end
  end

  @doc false
  def validate_clumps(clumps) do
    Enum.reduce_while(clumps, :ok, fn clump, _acc ->
      id = Keyword.get(clump, :id)
      sk = Keyword.get(clump, :controlling_secret)

      if is_binary(sk) and byte_size(sk) in [32, 43] do
        {:cont, :ok}
      else
        {:halt,
         {:error,
          "clump #{id}: controlling_secret is missing or malformed (expected 32 raw or 43 base62 bytes)"}}
      end
    end)
  end

  @doc false
  def define_nickers([], acc), do: acc

  def define_nickers([clump_def | rest], acc) do
    nicker = %{
      id: String.to_atom("quagga_nicker_" <> Keyword.get(clump_def, :id)),
      start: {Quagga.Nicker, :start_link, [clump_def]},
      type: :worker,
      restart: :permanent
    }

    define_nickers(rest, [nicker | acc])
  end
end
