defmodule Gyx.Envs.MujocoTest do
  use ExUnit.Case, async: true

  @suite [
    {"tree/InvertedPendulum-v4", 4, 1},
    {"tree/InvertedDoublePendulum-v4", 11, 1},
    {"tree/Reacher-v4", 11, 2},
    {"tree/Swimmer-v4", 8, 2},
    {"tree/Hopper-v4", 11, 3},
    {"tree/Walker2d-v4", 17, 6},
    {"tree/HalfCheetah-v4", 17, 6},
    {"tree/Ant-v4", 27, 8}
  ]

  test "tree ids stay registered" do
    for {id, _, _} <- @suite do
      assert id in Gyx.envs()
    end

    assert {:ok, _} = Gyx.make("tree/Hopper-v4")
    assert {:ok, _} = Gyx.make(:ant)
  end

  for {id, obs_n, act_n} <- @suite do
    test "#{id} reset, step, and 3D scene" do
      id = unquote(id)
      obs_n = unquote(obs_n)
      act_n = unquote(act_n)

      {:ok, env} = Gyx.make(id)
      {env, obs, _} = Gyx.reset(env, seed: 3)
      assert tuple_size(obs) == obs_n

      {env, obs2, _} = Gyx.reset(env, seed: 3)
      assert obs == obs2

      zeros = List.to_tuple(List.duplicate(0.0, act_n))
      assert {:ok, env, exp} = Gyx.step(env, zeros)
      assert tuple_size(exp.next_observation) == obs_n
      assert is_number(exp.reward)
      assert is_boolean(exp.terminated)
      assert is_boolean(exp.truncated)

      assert {:ok, scene} = Gyx.render(env, :scene)
      assert is_list(scene.bodies)
      assert scene.bodies != []
      assert {:ok, svg} = Gyx.render(env, :svg)
      assert svg =~ "<svg"
    end
  end

  test "tree InvertedPendulum terminates when the pole tips past 0.2 rad" do
    {:ok, env} = Gyx.make("tree/InvertedPendulum-v4", seed: 0)
    {env, _, _} = Gyx.reset(env, seed: 0)
    env = %{env | theta: 0.25, theta_dot: 0.0}

    {:ok, _env, exp} = Gyx.step(env, 0.0)
    assert exp.terminated
    assert exp.reward == 0.0
  end

  test "tree HalfCheetah stays on the floor" do
    {:ok, env} = Gyx.make("tree/HalfCheetah-v4")
    {env, _, _} = Gyx.reset(env, seed: 1)

    env =
      Enum.reduce(1..50, env, fn _, env ->
        {:ok, env, _} = Gyx.step(env, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0})
        env
      end)

    {:ok, scene} = Gyx.render(env, :scene)
    assert lowest_z(scene) > -0.02
    {_, z, _, _, _, _, _, _, _} = env.q
    assert z > 0.35
  end

  test "tree Ant limbs stay attached and above the floor" do
    {:ok, env} = Gyx.make("tree/Ant-v4")
    {env, _, _} = Gyx.reset(env, seed: 1)
    {:ok, scene} = Gyx.render(env, :scene)
    assert attached_legs?(scene)

    env =
      Enum.reduce(1..25, env, fn _, env ->
        {:ok, env, _} = Gyx.step(env, {0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0})
        env
      end)

    {:ok, scene} = Gyx.render(env, :scene)
    assert attached_legs?(scene)
    assert lowest_z(scene) > -0.02
  end

  test "tree Hopper stays finite under random actions" do
    {:ok, env} = Gyx.make("tree/Hopper-v4")
    {env, _, _} = Gyx.reset(env, seed: 1)

    env =
      Enum.reduce(1..80, env, fn _, env ->
        {:ok, action} = Gyx.Core.Spaces.sample(env.action_space)
        {:ok, env, exp} = Gyx.step(env, action)
        assert Enum.all?(Tuple.to_list(exp.next_observation), &is_number/1)
        env
      end)

    {_, z, _, _, _, _} = env.q
    assert is_float(z)
  end

  defp lowest_z(scene) do
    scene.bodies
    |> Enum.map(fn
      %{from: [_, _, z1], to: [_, _, z2], radius: r} -> min(z1, z2) - r
      %{pos: [_, _, z], radius: r} -> z - r
      _ -> 99.0
    end)
    |> Enum.min()
  end

  defp attached_legs?(scene) do
    by_id = Map.new(scene.bodies, &{&1.id, &1})

    Enum.all?(~w(leg_fl leg_fr leg_bl leg_br), fn name ->
      hip = by_id["#{name}_hip-0"]
      ankle = by_id["#{name}_ankle-0"]
      dist(hip.to, ankle.from) < 0.02
    end)
  end

  defp dist([ax, ay, az], [bx, by, bz]) do
    :math.sqrt((ax - bx) ** 2 + (ay - by) ** 2 + (az - bz) ** 2)
  end
end
