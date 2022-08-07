defmodule Quagga.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Quagga.Worker.start_link(arg)
      # {Quagga.Worker, arg}
    ]

    Baobab.create_identity("fly")
    started = "Etc/UTC" |> DateTime.now!() |> DateTime.to_string()

    Baobab.append_log("Fly BABY instance from " <> started, "fly", log_id: 8483)

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quagga.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
