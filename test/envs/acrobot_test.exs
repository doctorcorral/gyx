defmodule Gyx.Envs.AcrobotTest do
  use ExUnit.Case, async: true

  alias Gyx.Envs.Acrobot

  test "reset hangs near straight down" do
    env = Acrobot.new(seed: 0)
    {env, {c1, _s1, c2, _s2, _, _}, _} = Acrobot.reset(env, seed: 0)
    assert c1 > 0.9
    assert c2 > 0.9
    assert Acrobot.tip_height(env) < -1.5
  end

  test "reset is deterministic with a seed" do
    env = Acrobot.new()
    {env, obs1, _} = Acrobot.reset(env, seed: 9)
    {_, obs2, _} = Acrobot.reset(env, seed: 9)
    assert obs1 == obs2
  end

  test "torque changes the joint velocities" do
    env = Acrobot.new(seed: 1)
    {env, _, _} = Acrobot.reset(env, seed: 1)
    {:ok, stepped, _} = Acrobot.step(env, 2)
    refute stepped.dtheta1 == env.dtheta1 and stepped.dtheta2 == env.dtheta2
  end

  test "renders svg" do
    env = Acrobot.new(seed: 2)
    assert {:ok, svg} = Acrobot.render(env, :svg)
    assert svg =~ "Acrobot"
  end

  test "invalid action" do
    env = Acrobot.new(seed: 0)
    assert Acrobot.step(env, 3) == {:error, :invalid_action}
  end
end
