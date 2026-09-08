defmodule Mix.Tasks.Gyx.Train do
  @shortdoc "Train a preset algorithm on a Gyx environment"
  @moduledoc """
  Runs a `Gyx.Experiment` from a preset. Optionally writes the spec
  (and returns) to `experiments/NAME.json`.

      mix gyx.train CartPole-v1
      mix gyx.train CartPole-v1 --algo q_learning --episodes 50
      mix gyx.train gymnasium/ALE/Pong-v5 --algo a2c --name pong
  """

  use Mix.Task

  alias Gyx.Experiment

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        strict: [
          algo: :string,
          episodes: :integer,
          max_steps: :integer,
          seed: :integer,
          name: :string,
          dir: :string
        ]
      )

    id = List.first(rest) || Mix.raise("Usage: mix gyx.train ENV_ID [options]")
    Mix.Task.run("app.start")

    exp =
      Experiment.new(
        name: Keyword.get(opts, :name),
        env: id,
        algo: Keyword.get(opts, :algo, "a2c"),
        episodes: Keyword.get(opts, :episodes),
        max_steps: Keyword.get(opts, :max_steps),
        seed: Keyword.get(opts, :seed, 1)
      )

    Mix.shell().info("train #{exp.algo} on #{exp.env}")

    exp =
      Experiment.run(exp,
        on_progress: fn info ->
          if info.episode == info.episodes or rem(info.episode, progress_stride(info.episodes)) == 0 do
            Mix.shell().info("  ep #{info.episode}/#{info.episodes} return=#{info.return}")
          end
        end
      )

    Mix.shell().info("eval return #{exp.eval_return} (#{exp.episodes} episodes)")

    if exp.name do
      dir = Keyword.get(opts, :dir, "experiments")
      :ok = Experiment.save(exp, dir)
      Mix.shell().info("wrote #{Path.join(dir, exp.name <> ".json")}")
    end
  end

  defp progress_stride(episodes), do: max(1, div(episodes, 20))
end
