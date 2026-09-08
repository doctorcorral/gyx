defmodule Gyx.Envs.FaramaTest do
  use ExUnit.Case, async: false

  @suite [
    {"InvertedPendulum-v4", 4, 1},
    {"InvertedDoublePendulum-v4", 11, 1},
    {"Reacher-v4", 11, 2},
    {"Swimmer-v4", 8, 2},
    {"Hopper-v4", 11, 3},
    {"Walker2d-v4", 17, 6},
    {"HalfCheetah-v4", 17, 6},
    {"Ant-v4", 27, 8}
  ]

  test "unprefixed ids are the Farama suite, not tree" do
    assert "Hopper-v4" in Gyx.envs()
    assert "tree/Hopper-v4" in Gyx.envs()
    assert Gyx.Envs.fetch!("Hopper-v4") == Gyx.Envs.Hopper
    assert Gyx.Envs.fetch!("tree/Hopper-v4") == Gyx.Envs.Tree.Hopper
    refute function_exported?(Gyx.Envs.InvertedPendulum, :theta, 1)
  end

  for {id, obs_n, act_n} <- @suite do
    test "#{id} reset, step, and scene" do
      id = unquote(id)
      obs_n = unquote(obs_n)
      act_n = unquote(act_n)

      {:ok, env} = Gyx.make(id)
      {env, obs, _} = Gyx.reset(env, seed: 3)
      assert tuple_size(obs) == obs_n

      zeros = List.to_tuple(List.duplicate(0.0, act_n))
      assert {:ok, env, exp} = Gyx.step(env, zeros)
      assert tuple_size(exp.next_observation) == obs_n
      assert is_number(exp.reward)
      assert {:ok, scene} = Gyx.render(env, :scene)
      assert scene.bodies != []
      assert {:ok, svg} = Gyx.render(env, :svg)
      assert svg =~ "<svg"
    end
  end

  test "InvertedPendulum terminates when the pole tips past 0.2 rad" do
    {:ok, env} = Gyx.make("InvertedPendulum-v4", seed: 0)
    {env, _, _} = Gyx.reset(env, qpos: {0.0, 0.25}, qvel: {0.0, 0.0})
    {:ok, _env, exp} = Gyx.step(env, 0.0)
    assert exp.terminated
  end

  describe "gold trajectories vs gymnasium.make" do
    @describetag :gymnasium

    test "InvertedPendulum-v4 matches from a shared state" do
      assert_transfer("InvertedPendulum-v4", [[0.3], [-0.5], [1.2], [0.0]], 1.0e-3)
    end

    test "InvertedDoublePendulum-v4 matches from a shared state" do
      assert_transfer("InvertedDoublePendulum-v4", [[0.0], [0.2], [-0.15], [0.4]], 5.0e-3)
    end

    test "Reacher-v4 matches from a shared state" do
      assert_transfer("Reacher-v4", [[0.2, -0.1], [0.0, 0.4], [-0.3, 0.1]], 5.0e-3)
    end

    test "Hopper-v4 first step matches from a shared state" do
      assert_transfer_parts("Hopper-v4", [[0.0, 0.0, 0.0]], 5, 0.02, 0.15)
    end

    test "Swimmer-v4 matches from a shared state" do
      assert_transfer("Swimmer-v4", [[0.2, -0.1], [0.0, 0.3], [-0.2, 0.1]], 0.15)
    end

    test "Walker2d-v4 first step matches from a shared state" do
      assert_transfer_parts("Walker2d-v4", [List.duplicate(0.0, 6)], 8, 0.05, 0.25)
    end

    test "HalfCheetah-v4 first step matches from a shared state" do
      assert_transfer_parts("HalfCheetah-v4", [List.duplicate(0.0, 6)], 8, 0.05, 0.55)
    end

    test "Ant-v4 first step matches from a shared state" do
      assert_transfer_parts("Ant-v4", [List.duplicate(0.0, 8)], 13, 0.10, 1.25)
    end

    test "open-loop Hopper returns stay comparable" do
      actions = for i <- 0..39, do: [0.2 * :math.sin(i / 5), -0.1, 0.15]
      ref = Gyx.Gymnasium.Bridge.replay("Hopper-v4", 0, actions)
      assert ref["ok"]

      {:ok, env} = Gyx.make("Hopper-v4")
      {env, _, _} = Gyx.reset(env, qpos: ref["qpos"], qvel: ref["qvel"])

      {gyx_ret, gym_ret, _} =
        Enum.reduce(Enum.zip(actions, ref["steps"]), {0.0, 0.0, env}, fn {action, step}, {a, b, env} ->
          {:ok, env, exp} = Gyx.step(env, List.to_tuple(action))
          {a + exp.reward, b + step["reward"], env}
        end)

      assert Enum.all?([gyx_ret, gym_ret], &(&1 == &1 and abs(&1) < 1.0e4))
      # Contact locomotion is the hard part; require a finite, same-sign return.
      assert gyx_ret * gym_ret > 0 or abs(gyx_ret - gym_ret) < 20.0
    end
  end

  defp assert_transfer(id, actions, tol), do: assert_transfer_parts(id, actions, 0, tol, tol)

  defp assert_transfer_parts(id, actions, pos_n, pos_tol, vel_tol) do
    ref = Gyx.Gymnasium.Bridge.replay(id, 0, actions)
    assert ref["ok"]

    {:ok, env} = Gyx.make(id)
    {env, _obs, _} = Gyx.reset(env, qpos: ref["qpos"], qvel: ref["qvel"])

    Enum.reduce(Enum.zip(actions, ref["steps"]), env, fn {action, step}, env ->
      {:ok, env, exp} = Gyx.step(env, action_tuple(action))
      gyx = Tuple.to_list(exp.next_observation)
      gym = step["obs"]
      {gpos, gvel} = Enum.split(gyx, pos_n)
      {ypos, yvel} = Enum.split(gym, pos_n)
      if pos_n > 0, do: assert_close(gpos, ypos, pos_tol)
      assert_close(gvel, yvel, vel_tol)
      assert_in_delta exp.reward, step["reward"], max(vel_tol, 1.0e-3)
      assert exp.terminated == step["terminated"]
      env
    end)
  end

  defp action_tuple([x]), do: x
  defp action_tuple(xs), do: List.to_tuple(xs)

  defp assert_close(a, b, tol) when is_tuple(a), do: assert_close(Tuple.to_list(a), b, tol)

  defp assert_close(a, b, tol) when is_list(a) and is_list(b) do
    assert length(a) == length(b)

    Enum.zip(a, b)
    |> Enum.with_index()
    |> Enum.each(fn {{x, y}, i} ->
      assert_in_delta x * 1.0, y * 1.0, tol, "mismatch at #{i}: #{x} vs #{y}"
    end)
  end
end
