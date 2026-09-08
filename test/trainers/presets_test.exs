defmodule Gyx.Trainers.PresetsTest do
  use ExUnit.Case, async: true

  alias Gyx.Trainers.{Episodic, Presets}

  test "A2C/PPO presets cover tree locomotion and gymnasium ids" do
    for id <- ~w(Walker2d-v4 HalfCheetah-v4 Ant-v4 tree/Hopper-v4 gymnasium/Hopper-v4 gymnasium/Ant-v5) do
      assert Presets.available?("a2c", id)
      assert Presets.available?("ppo", id)
      {agent, opts} = Presets.build("a2c", id)
      assert is_list(Keyword.fetch!(opts, :actions))
      assert agent.n_actions == length(opts[:actions])
    end
  end

  test "Q-learning stays off high-dimensional boxes" do
    refute Presets.available?("q_learning", "Walker2d-v4")
    refute Presets.available?("q_learning", "gymnasium/Hopper-v4")
    assert Presets.available?("q_learning", "gymnasium/InvertedPendulum-v4")
  end

  test "every registered env has at least one trainable algorithm" do
    algos = ~w(q_learning sarsa reinforce a2c ppo)

    for id <- Gyx.envs() do
      assert Enum.any?(algos, &Presets.available?(&1, id)),
             "#{id} has no trainer preset"
    end
  end

  test "A2C can take one Walker2d episode" do
    {agent, opts} = Presets.a2c("Walker2d-v4")

    %{episodes: 1} =
      Episodic.train("Walker2d-v4", agent, Keyword.merge(opts, episodes: 1, max_steps: 8))
  end

  @tag :atari
  test "A2C can take one Pong episode" do
    {agent, opts} = Presets.a2c("gymnasium/ALE/Pong-v5")

    %{episodes: 1} =
      Episodic.train(
        "gymnasium/ALE/Pong-v5",
        agent,
        Keyword.merge(opts, episodes: 1, max_steps: 4)
      )
  end
end
