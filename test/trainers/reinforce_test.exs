defmodule Gyx.Trainers.ReinforceTest do
  use ExUnit.Case, async: true

  alias Gyx.Agents.Reinforce
  alias Gyx.Core.Exp
  alias Gyx.Encode
  alias Gyx.Trainers.Episodic

  test "finish_episode updates the linear softmax weights" do
    agent = Reinforce.new(lr: 0.5, gamma: 1.0, baseline: false)

    exp = %Exp{
      observation: {1.0, 0.0},
      action: 1,
      next_observation: {1.0, 0.0},
      reward: 1.0,
      terminated: true
    }

    agent = Reinforce.learn(agent, exp, [0, 1])
    refute agent.trajectory == []
    agent = Reinforce.finish_episode(agent)
    assert agent.trajectory == []
    assert map_size(agent.weights) > 0
  end

  test "REINFORCE with one-hot features learns FrozenLake-v1" do
    :rand.seed(:exsss, {7, 8, 9})
    {agent, opts} = Gyx.Trainers.Presets.reinforce("FrozenLake-v1")

    %{agent: agent} =
      Episodic.train("FrozenLake-v1", agent, Keyword.merge(opts, episodes: 3000, seed: 2))

    avg =
      Episodic.evaluate("FrozenLake-v1", agent,
        episodes: 40,
        seed: 9_000,
        env: [is_slippery: false]
      )

    assert avg >= 0.3
  end

  test "one_hot encode is used by the FrozenLake preset" do
    {agent, _opts} = Gyx.Trainers.Presets.reinforce("FrozenLake-v1")
    assert is_function(agent.encode, 1)
    assert Encode.one_hot(16).(3) == agent.encode.(3)
  end
end
