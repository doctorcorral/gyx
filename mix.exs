defmodule Gyx.MixProject do
  use Mix.Project

  def project do
    [
      app: :gyx,
      version: "0.3.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      description: description(),
      package: package(),
      deps: deps(),
      docs: [
        main: "readme",
        extras: ["README.md"]
      ]
    ]
  end

  def application do
    [
      mod: {Gyx.Application, []},
      extra_applications: [:logger, :crypto]
    ]
  end

  defp elixirc_paths(:test), do: ["lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:nx, "~> 0.9"},
      {:exla, "~> 0.9"},
      {:axon, "~> 0.7"},
      {:synthex, github: "doctorcorral/synthex", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end

  defp description do
    """
    Native Elixir reinforcement learning: Gymnasium-like environments
    and classical trainers, with a Mix CLI for experiments.
    """
  end

  defp package do
    [
      files: ["lib", "priv", "images", "mix.exs", "README*", "LICENSE*", "config"],
      maintainers: ["Ricardo Corral-Corral"],
      licenses: ["BSD-2-Clause"],
      links: %{"GitHub" => "https://github.com/doctorcorral/gyx"}
    ]
  end
end
