defmodule Quagga.MixProject do
  use Mix.Project

  def project do
    [
      app: :quagga,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :baby, :inets],
      mod: {Quagga.Application, []}
    ]
  end

  defp releases() do
    [
      quagga: [
        include_executables_for: [:unix],
        cookie: "KE-AGO-RATA"
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:baby, git: "https://github.com/mwmiller/baby_ex"}
    ]
  end
end
