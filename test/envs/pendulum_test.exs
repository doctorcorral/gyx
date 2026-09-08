defmodule Gyx.Envs.PendulumTest do
  use ExUnit.Case, async: true

  alias Gyx.Envs.Pendulum

  test "reset is deterministic with a seed" do
    env = Pendulum.new()
    {env, {c1, s1, w1}, _} = Pendulum.reset(env, seed: 4)
    {_, {c2, s2, w2}, _} = Pendulum.reset(env, seed: 4)
    assert {c1, s1, w1} == {c2, s2, w2}
    assert abs(c1 * c1 + s1 * s1 - 1.0) < 1.0e-6
  end

  test "reward is non-positive and episode truncates" do
    env = Pendulum.new(seed: 0, max_episode_steps: 5)
    {env, _, _} = Pendulum.reset(env, seed: 0)

    {_env, last} =
      Enum.reduce(1..5, {env, nil}, fn _, {env, _} ->
        {:ok, env, exp} = Pendulum.step(env, 1)
        {env, exp}
      end)

    assert last.truncated
    refute last.terminated
    assert last.reward <= 0.0
  end

  test "integer actions map to discrete torques" do
    env = Pendulum.new(seed: 1)
    {:ok, env, exp} = Pendulum.step(env, 2)
    assert exp.action == 2.0
    assert env.last_u == 2.0
  end

  test "accepts a 1-tuple torque" do
    env = Pendulum.new(seed: 1)
    assert {:ok, _env, exp} = Pendulum.step(env, {-1.5})
    assert exp.action == -1.5
  end

  test "renders svg" do
    env = Pendulum.new(seed: 2)
    assert {:ok, svg} = Pendulum.render(env, :svg)
    assert svg =~ "Pendulum"
  end

  test "invalid action" do
    env = Pendulum.new(seed: 0)
    assert Pendulum.step(env, :spin) == {:error, :invalid_action}
  end
end
