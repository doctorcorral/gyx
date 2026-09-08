defmodule Gyx.Trainers.SarsaTest do
  use ExUnit.Case, async: true

  alias Gyx.Agents.Sarsa
  alias Gyx.Envs.FrozenLake
  alias Gyx.Trainers.Episodic

  test "SARSA solves deterministic FrozenLake-v1" do
    agent =
      Sarsa.new(
        alpha: 0.8,
        gamma: 0.95,
        epsilon: 1.0,
        epsilon_decay: 0.995,
        epsilon_min: 0.05
      )

    %{agent: agent} =
      Episodic.train(FrozenLake, agent,
        episodes: 800,
        seed: 1,
        env: [is_slippery: false]
      )

    avg =
      Episodic.evaluate(FrozenLake, agent, episodes: 40, seed: 5_000, env: [is_slippery: false])

    assert avg >= 0.7
  end
end
