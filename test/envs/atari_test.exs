defmodule Gyx.Envs.AtariTest do
  use ExUnit.Case, async: false

  alias Gyx.Core.Spaces.{Box, Discrete}

  test "ALE ids are gymnasium/ALE wraps and do not take unprefixed names" do
    assert "gymnasium/ALE/Pong-v5" in Gyx.envs()
    refute "ALE/Pong-v5" in Gyx.envs()
    refute "tree/ALE/Pong-v5" in Gyx.envs()
    refute "Pong-v5" in Gyx.envs()

    spec = Gyx.spec("gymnasium/ALE/Pong-v5")
    assert spec.action_space == %Discrete{n: 6}
    assert spec.observation_space.shape == {210, 160, 3}
    assert spec.observation_space.dtype == :u8
    assert Box.tensor?(spec.observation_space)
  end

  test "Atari trains with a conv actor-critic, not a Q-table" do
    refute Gyx.Trainers.Presets.available?("q_learning", "gymnasium/ALE/Pong-v5")
    refute Gyx.Trainers.Presets.available?("sarsa", "gymnasium/ALE/Pong-v5")
    assert Gyx.Trainers.Presets.available?("a2c", "gymnasium/ALE/Pong-v5")
    assert Gyx.Trainers.Presets.available?("ppo", "gymnasium/ALE/Pong-v5")

    {agent, opts} = Gyx.Trainers.Presets.build("a2c", "gymnasium/ALE/Pong-v5")
    assert agent.vision == {84, 84, 1}
    assert agent.n_actions == 6
    assert length(opts[:actions]) == 6
  end

  describe "live ALE" do
    @describetag :atari

    test "reset returns a uint8 frame tensor and Discrete step works" do
      {:ok, env} = Gyx.make("gymnasium/ALE/Pong-v5")
      {env, obs, _} = Gyx.reset(env, seed: 0)
      assert Nx.shape(obs) == {210, 160, 3}
      assert Nx.type(obs) == {:u, 8}

      {:ok, env, exp} = Gyx.step(env, 0)
      assert exp.action == 0
      assert is_float(exp.reward)
      assert Nx.shape(exp.next_observation) == {210, 160, 3}
      assert Nx.type(exp.next_observation) == {:u, 8}

      {:ok, svg} = Gyx.render(env, :svg)
      assert svg =~ "image/png"
      assert svg =~ "pixelated"
    end

    test "invalid Discrete actions are rejected" do
      {:ok, env} = Gyx.make("gymnasium/ALE/Pong-v5")
      {env, _, _} = Gyx.reset(env, seed: 1)
      assert {:error, :invalid_action} = Gyx.step(env, 99)
      assert {:error, :invalid_action} = Gyx.step(env, [0.0])
    end
  end
end
