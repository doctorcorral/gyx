defmodule Mix.Tasks.Gyx.Experiment do
  @shortdoc "Create, list, show, and run named learning experiments"
  @moduledoc """
  Experiment specs live as JSON under `experiments/` (override with `--dir`).

      mix gyx.experiment new cart --env CartPole-v1 --algo a2c
      mix gyx.experiment list
      mix gyx.experiment show cart
      mix gyx.experiment run cart --episodes 20
  """

  use Mix.Task

  alias Gyx.Experiment

  @impl Mix.Task
  def run(["new", name | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        strict: [env: :string, algo: :string, episodes: :integer, max_steps: :integer, seed: :integer, dir: :string]
      )

    env = Keyword.get(opts, :env) || Mix.raise("mix gyx.experiment new NAME --env ENV_ID")
    Mix.Task.run("app.start")

    exp =
      Experiment.new(
        name: name,
        env: env,
        algo: Keyword.get(opts, :algo, "a2c"),
        episodes: Keyword.get(opts, :episodes),
        max_steps: Keyword.get(opts, :max_steps),
        seed: Keyword.get(opts, :seed, 1)
      )

    dir = Keyword.get(opts, :dir, "experiments")
    :ok = Experiment.save(exp, dir)
    Mix.shell().info("created #{Path.join(dir, name <> ".json")}")
  end

  def run(["list" | rest]) do
    {opts, _, _} = OptionParser.parse(rest, strict: [dir: :string])
    dir = Keyword.get(opts, :dir, "experiments")

    case Experiment.list(dir) do
      [] -> Mix.shell().info("no experiments in #{dir}")
      names -> Enum.each(names, &Mix.shell().info/1)
    end
  end

  def run(["show", name | rest]) do
    {opts, _, _} = OptionParser.parse(rest, strict: [dir: :string])
    dir = Keyword.get(opts, :dir, "experiments")

    case Experiment.load(name, dir) do
      {:ok, exp} ->
        Mix.shell().info(Jason.encode!(Experiment.to_map(exp), pretty: true))

      {:error, reason} ->
        Mix.raise("could not load #{name}: #{inspect(reason)}")
    end
  end

  def run(["run", name | rest]) do
    {opts, _, _} =
      OptionParser.parse(rest,
        strict: [dir: :string, episodes: :integer, max_steps: :integer, seed: :integer]
      )

    Mix.Task.run("app.start")
    dir = Keyword.get(opts, :dir, "experiments")

    exp =
      case Experiment.load(name, dir) do
        {:ok, exp} -> exp
        {:error, reason} -> Mix.raise("could not load #{name}: #{inspect(reason)}")
      end

    Mix.shell().info("run #{exp.name} (#{exp.algo} on #{exp.env})")

    exp =
      Experiment.run(exp,
        episodes: Keyword.get(opts, :episodes),
        max_steps: Keyword.get(opts, :max_steps),
        seed: Keyword.get(opts, :seed),
        on_progress: fn info ->
          if info.episode == info.episodes or rem(info.episode, max(1, div(info.episodes, 20))) == 0 do
            Mix.shell().info("  ep #{info.episode}/#{info.episodes} return=#{info.return}")
          end
        end
      )

    :ok = Experiment.save(exp, dir)
    Mix.shell().info("eval return #{exp.eval_return}")
  end

  def run(_args) do
    Mix.shell().info("""
    Usage:
      mix gyx.experiment new NAME --env ENV_ID [--algo a2c]
      mix gyx.experiment list
      mix gyx.experiment show NAME
      mix gyx.experiment run NAME
    """)
  end
end
