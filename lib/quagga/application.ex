defmodule Quagga.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Baby.Application, []},
      {Quagga.Nicker,
       [Application.get_env(:quagga, :secret), Application.get_env(:quagga, :public)]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Quagga.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
