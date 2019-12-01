defmodule Gyx.MixProject do
  use Mix.Project

  def project do
    [
      app: :gyx,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
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
      {:matrex, "~> 0.6"},
      {:observer_cli, "~> 1.5"},
      {:libcluster, "~> 3.0"}
    ]
  end

  defp description do
    """
    Gyx allows designing and training Reinforcement Learning tasks.
    It includes environment abstractions that allows interaction with Python based environments like OpenAI Gym.
    """
  end

  defp package do
    [
      files: ["lib", "mix.exs", "README*", "LICENSE*", "config"],
      maintainers: ["Ricardo Corral-Corral"],
      licenses: ["BSD-2-Clause"],
      links: %{"GitHub" => "https://github.com/doctorcorral/gyx"}
    ]
  end
end
