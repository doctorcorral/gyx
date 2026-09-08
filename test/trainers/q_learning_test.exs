defmodule Gyx.Trainers.QLearningTest do
  use ExUnit.Case, async: true

  alias Gyx.Agents.QLearning
  alias Gyx.Core.Exp
  alias Gyx.Encode
  alias Gyx.Envs.FrozenLake
  alias Gyx.Trainers.Episodic

  test "Q-learning solves deterministic FrozenLake-v1" do
    agent =
      QLearning.new(
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

  test "episodic trainer reports per-episode progress" do
    parent = self()

    %{returns: returns, episodes: 4} =
      Episodic.train(FrozenLake, QLearning.new(epsilon: 1.0),
        episodes: 4,
        seed: 1,
        env: [is_slippery: false],
        on_progress: fn info -> send(parent, {:progress, info}) end
      )

    assert length(returns) == 4

    for episode <- 1..4 do
      assert_receive {:progress, %{episode: ^episode, episodes: 4, return: ret, returns: acc}}
      assert is_float(ret) or is_integer(ret)
      assert length(acc) == episode
    end
  end

  test "Q-learning stores values under encoded observations" do
    agent = QLearning.new(encode: Encode.bins([{-1.0, 1.0, 4}]), epsilon: 0.0)

    exp = %Exp{
      observation: {-0.9},
      action: 0,
      next_observation: {0.9},
      reward: 1.0,
      terminated: true
    }

    agent = QLearning.learn(agent, exp, [0, 1])
    assert QLearning.q(agent, {-0.9}, 0) > 0
    assert Map.has_key?(agent.q, {0})
  end

  @tag timeout: 120_000
  test "discretized Q-learning learns CartPole-v1" do
    :rand.seed(:exsss, {1, 2, 3})
    {agent, opts} = Gyx.Trainers.Presets.q_learning("CartPole-v1")
    %{agent: agent} = Episodic.train("CartPole-v1", agent, Keyword.put(opts, :episodes, 1500))

    avg = Episodic.evaluate("CartPole-v1", agent, episodes: 15, seed: 9_000, max_steps: 500)
    assert avg >= 25.0
  end

  @tag timeout: 180_000
  test "discretized Q-learning reaches the MountainCar flag" do
    :rand.seed(:exsss, {1, 2, 3})
    {agent, opts} = Gyx.Trainers.Presets.q_learning("MountainCar-v0")
    %{agent: agent} = Episodic.train("MountainCar-v0", agent, Keyword.put(opts, :episodes, 2500))

    avg = Episodic.evaluate("MountainCar-v0", agent, episodes: 15, seed: 9_000, max_steps: 200)
    assert avg > -190.0
  end
end
