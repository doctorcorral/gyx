defmodule Gyx.Envs.CartPoleTest do
  use ExUnit.Case, async: true

  alias Gyx.Core.Exp
  alias Gyx.Envs.CartPole

  test "reset is deterministic with a seed" do
    {:ok, env} = Gyx.make("CartPole-v1")
    {env, obs_a, _} = Gyx.reset(env, seed: 7)
    {_, obs_b, _} = Gyx.reset(env, seed: 7)
    assert obs_a == obs_b
    assert tuple_size(obs_a) == 4
  end

  test "each step rewards 1.0 until the pole falls or time runs out" do
    {:ok, env} = Gyx.make("CartPole-v1", seed: 0)
    {env, _obs, _} = Gyx.reset(env, seed: 0)

    {env, total, last} =
      Enum.reduce(1..600, {env, 0.0, nil}, fn _, {env, total, _last} ->
        {:ok, env, exp} = Gyx.step(env, 1)
        {env, total + exp.reward, exp}
      end)

    assert total >= 1.0
    assert last.terminated or last.truncated
    assert CartPole.observe(env)
  end

  test "renders svg and ansi" do
    {:ok, env} = Gyx.make("CartPole-v1", seed: 1)
    assert {:ok, svg} = Gyx.render(env, :svg)
    assert svg =~ "<svg"
    assert {:ok, ansi} = Gyx.render(env, :ansi)
    assert ansi =~ "CartPole"
  end

  test "step returns a Gymnasium-shaped experience" do
    {:ok, env} = Gyx.make("CartPole-v1", seed: 2)
    {env, obs, _} = Gyx.reset(env, seed: 2)
    {:ok, _env, %Exp{} = exp} = Gyx.step(env, 0)
    assert exp.observation == obs
    assert exp.action == 0
    assert exp.reward == 1.0
    assert is_tuple(exp.next_observation)
    assert exp.terminated in [true, false]
    assert exp.truncated in [true, false]
  end
end
