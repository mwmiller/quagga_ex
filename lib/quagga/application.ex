defmodule Quagga.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    config = Application.get_all_env(:quagga)

    nickers = define_nickers(Keyword.get(config, :clumps), [])
    babies = [{Baby.Application, config}] ++ nickers

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quagga.Supervisor]
    Supervisor.start_link(babies, opts)
  end

  defp define_nickers([], acc), do: acc

  defp define_nickers([clump_def | rest], acc) do
    nicker = %{
      id: String.to_atom("quagga_nicker_" <> Keyword.get(clump_def, :id)),
      start: {Quagga.Nicker, :start_link, [clump_def]},
      type: :worker,
      restart: :permanent
    }

    define_nickers(rest, [nicker | acc])
  end
end
