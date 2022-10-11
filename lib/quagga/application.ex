defmodule Quagga.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    path = Application.get_env(:quagga, :spool_dir, "/tmp/baobab") |> Path.expand()
    File.mkdir_p(path)

    babies =
      define_babies(
        Application.get_env(:quagga, :clumps, []),
        path,
        []
      )

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quagga.Supervisor]
    Supervisor.start_link(babies, opts)
  end

  defp define_babies([], _, acc), do: acc

  defp define_babies([clump_def | rest], spool_dir, acc) do
    listener = %{
      id: String.to_atom("baby_application_" <> Keyword.get(clump_def, :id)),
      start: {Baby.Application, :start, [nil, [{:spool_dir, spool_dir} | clump_def]]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }

    nicker = %{
      id: String.to_atom("quagga_nicker_" <> Keyword.get(clump_def, :id)),
      start: {Quagga.Nicker, :start_link, [clump_def]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }

    define_babies(rest, spool_dir, acc ++ [listener, nicker])
  end
end
