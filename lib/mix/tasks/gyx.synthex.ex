defmodule Mix.Tasks.Gyx.Synthex do
  @shortdoc "Score Synthex candidates on a native GYX env (no Python)"
  @moduledoc """
  Runs `Gyx.Synthex.Probe` against CartPole or MountainCar.

      mix gyx.synthex
      mix gyx.synthex --env MountainCar-v0

  Collects trajectory states with the GYX scorer, generates Synthex
  axis features, and scores a few `feat` candidates. Does not run
  CEGAR or call Python.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args, strict: [env: :string, seeds: :integer, candidates: :integer])

    Mix.Task.run("app.start")

    id = Keyword.get(opts, :env) || List.first(rest) || "CartPole-v1"

    unless Gyx.Synthex.Probe.supported?(id) do
      Mix.raise("unsupported env #{inspect(id)}; try CartPole-v1 or MountainCar-v0")
    end

    probe_opts =
      []
      |> maybe_put(:seeds, Keyword.get(opts, :seeds), fn n -> Enum.to_list(0..(n - 1)) end)
      |> maybe_put(:candidates, Keyword.get(opts, :candidates), & &1)

    result = Gyx.Synthex.Probe.run(id, probe_opts)

    Mix.shell().info("GYX × Synthex probe — #{result.env} (no Python)")
    Mix.shell().info("  states:    #{result.n_states}")
    Mix.shell().info("  features:  #{result.n_features} axis")
    Mix.shell().info("  baseline:  #{fmt(result.baseline)}")

    result.scored
    |> Enum.sort_by(fn {_idx, reward, _} -> -reward end)
    |> Enum.each(fn {idx, reward, wins} ->
      pred = Enum.at(result.candidates, idx)
      Mix.shell().info("  cand #{idx}: #{fmt(reward)} (wins=#{wins})  #{inspect(pred)}")
    end)
  end

  defp maybe_put(opts, _key, nil, _fun), do: opts
  defp maybe_put(opts, key, value, fun), do: Keyword.put(opts, key, fun.(value))

  defp fmt(n) when is_float(n), do: n |> Float.round(2) |> to_string()
  defp fmt(n), do: to_string(n)
end
