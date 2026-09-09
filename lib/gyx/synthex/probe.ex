defmodule Gyx.Synthex.Probe do
  @moduledoc """
  One Synthex Oracle pass against a native GYX environment.

  Collects states, generates axis features, and scores a handful of
  `feat` candidates — no Python, no full CEGAR.
  """

  @env_atoms %{
    "CartPole-v1" => :cartpole,
    "MountainCar-v0" => :mountaincar
  }

  @defaults %{
    "CartPole-v1" => [default: :left, stage: :right],
    "MountainCar-v0" => [default: :push_left, stage: :push_right]
  }

  @spec supported?(String.t()) :: boolean()
  def supported?(id), do: Map.has_key?(@env_atoms, id)

  @spec run(String.t(), keyword()) :: map()
  def run(env_id, opts \\ []) do
    env = Map.fetch!(@env_atoms, env_id)
    defaults = Map.fetch!(@defaults, env_id)
    default = Keyword.get(opts, :default, defaults[:default])
    stage = Keyword.get(opts, :stage, defaults[:stage])
    seeds = Keyword.get(opts, :seeds, Enum.to_list(0..7))
    max_steps = Keyword.get(opts, :max_steps, 80)
    n = Keyword.get(opts, :candidates, 6)
    scorer = Keyword.get(opts, :scorer) || Gyx.Synthex.Scorer.new(env_id)

    {states, n_wins} =
      Synthex.Gym.Oracle.get_trajectory_states([], default,
        env: env,
        seeds: seeds,
        max_steps: max_steps,
        scorer: scorer
      )

    features =
      Synthex.Gym.Oracle.generate_features(states,
        env: env,
        feature_types: [:axis],
        max_coeff: 1
      )

    stride = max(div(max(length(features), 1), n), 1)

    candidates =
      features
      |> Enum.take_every(stride)
      |> Enum.take(n)
      |> Enum.map(&{:feat, &1})

    {scored, baseline, _} =
      Synthex.Gym.Oracle.score_candidates(candidates, stage, default, [],
        env: env,
        seeds: seeds,
        max_steps: max_steps,
        scorer: scorer
      )

    %{
      env: env_id,
      n_states: length(states),
      n_wins: n_wins,
      n_features: length(features),
      baseline: baseline,
      scored: scored,
      candidates: candidates
    }
  end
end
