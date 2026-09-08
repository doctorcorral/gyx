defmodule Gyx.Envs.MountainCarTest do
  use ExUnit.Case, async: true

  alias Gyx.Envs.MountainCar

  test "reset is deterministic with a seed" do
    env = MountainCar.new()
    {env, {x1, v1}, _} = MountainCar.reset(env, seed: 3)
    {_, {x2, v2}, _} = MountainCar.reset(env, seed: 3)
    assert v1 == 0
    assert v2 == 0
    assert x1 == x2
    assert x1 >= -0.6 and x1 < -0.4
  end

  test "each step costs -1 and can truncate" do
    env = MountainCar.new(seed: 0, max_episode_steps: 5)
    {env, _, _} = MountainCar.reset(env, seed: 0)

    {_env, last} =
      Enum.reduce(1..5, {env, nil}, fn _, {env, _} ->
        {:ok, env, exp} = MountainCar.step(env, 2)
        {env, exp}
      end)

    assert last.truncated
    assert last.reward == -1.0
  end

  test "renders svg" do
    env = MountainCar.new(seed: 1)
    assert {:ok, svg} = MountainCar.render(env, :svg)
    assert svg =~ "MountainCar"
  end

  test "invalid action" do
    env = MountainCar.new(seed: 0)
    assert MountainCar.step(env, 9) == {:error, :invalid_action}
  end
end
