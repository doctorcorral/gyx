defmodule Gyx.Envs.GymnasiumTest do
  use ExUnit.Case, async: false

  @ids [
    "gymnasium/InvertedPendulum-v4",
    "gymnasium/Hopper-v4",
    "gymnasium/Ant-v5"
  ]

  test "gymnasium ids are registered and do not replace tree ids" do
    assert "gymnasium/Hopper-v4" in Gyx.envs()
    assert "Hopper-v4" in Gyx.envs()
    assert Gyx.Envs.fetch!("gymnasium/Hopper-v4") != Gyx.Envs.fetch!("Hopper-v4")
    assert Gyx.spec("gymnasium/Hopper-v4").observation_space.shape == {11}
    assert Gyx.spec("gymnasium/Ant-v5").observation_space.shape == {105}
  end

  describe "live MuJoCo" do
    @describetag :gymnasium

    test "reset and step match a fresh gymnasium.make on the same seed" do
      actions = [[0.0, 0.0, 0.0], [0.15, -0.1, 0.05], [0.0, 0.2, -0.2]]

      {:ok, env} = Gyx.make("gymnasium/Hopper-v4")
      {env, obs, _} = Gyx.reset(env, seed: 0)

      ref = Gyx.Gymnasium.Bridge.replay("Hopper-v4", 0, actions)
      assert ref["ok"]
      assert_close(obs, ref["obs"])

      Enum.reduce(Enum.zip(actions, ref["steps"]), env, fn {action, step}, env ->
        {:ok, env, exp} = Gyx.step(env, List.to_tuple(action))
        assert_close(exp.next_observation, step["obs"])
        assert_in_delta exp.reward, step["reward"], 1.0e-6
        assert exp.terminated == step["terminated"]
        assert exp.truncated == step["truncated"]
        env
      end)
    end

    test "suite reset/step dimensions" do
      for id <- @ids do
        spec = Gyx.spec(id)
        {:ok, env} = Gyx.make(id)
        {env, obs, _} = Gyx.reset(env, seed: 1)
        assert tuple_size(obs) == elem(spec.observation_space.shape, 0)

        zeros = List.to_tuple(List.duplicate(0.0, elem(spec.action_space.shape, 0)))
        assert {:ok, _env, exp} = Gyx.step(env, zeros)
        assert tuple_size(exp.next_observation) == tuple_size(obs)
      end
    end
  end

  defp assert_close(a, b) when is_tuple(a) do
    assert_close(Tuple.to_list(a), b)
  end

  defp assert_close(a, b) when is_list(a) and is_list(b) do
    assert length(a) == length(b)

    Enum.zip(a, b)
    |> Enum.with_index()
    |> Enum.each(fn {{x, y}, i} ->
      assert_in_delta x * 1.0, y * 1.0, 1.0e-5, "mismatch at #{i}: #{x} vs #{y}"
    end)
  end
end
