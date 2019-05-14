defmodule Gyx.MixProject do
  use Mix.Project

  def project do
    [
      app: :gyx,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Gyx.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:earmark, "~> 1.2", only: :dev},
      {:ex_doc, "~> 0.19", only: :dev},
      {:credo, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:erlport, "~> 0.10.0"},
      {:distillery, "~> 1.5", runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:poolboy, "~> 1.5.1"}
    ]
  end
end
