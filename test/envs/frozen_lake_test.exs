defmodule Gyx.Envs.FrozenLakeTest do
  use ExUnit.Case, async: true

  alias Gyx.Envs.FrozenLake

  test "4x4 observation is 0..15 and starts on S" do
    env = FrozenLake.new(is_slippery: false, seed: 0)
    assert FrozenLake.observe(env) == 0
    assert FrozenLake.cell(env) == ?S
    assert env.observation_space.n == 16
  end

  test "8x8 uses a 64-cell observation space" do
    env = FrozenLake.new(map_name: "8x8", is_slippery: false)
    assert env.observation_space.n == 64
  end

  test "is_slippery is a live configurable parameter" do
    env = FrozenLake.new(is_slippery: false, seed: 0)
    assert [%{key: :is_slippery, value: false} | _] = FrozenLake.params(env)

    env = FrozenLake.configure(env, is_slippery: true)
    assert env.is_slippery
    assert env.row == 0
    assert hd(FrozenLake.params(env)).value == true
  end

  test "Down from start moves down, not sideways, when deterministic" do
    env = FrozenLake.new(is_slippery: false, seed: 0)
    {:ok, env, exp} = FrozenLake.step(env, 1)
    assert env.row == 1
    assert env.col == 0
    assert FrozenLake.observe(env) == 4
    assert exp.info.applied_action == 1
    assert env.last_applied == 1
  end

  test "deterministic path reaches the goal" do
    # Right, right, down, down, down, right
    env = FrozenLake.new(is_slippery: false, seed: 0)
    path = [2, 2, 1, 1, 1, 2]

    {_env, last} =
      Enum.reduce(path, {env, nil}, fn action, {env, _} ->
        {:ok, env, exp} = FrozenLake.step(env, action)
        {env, exp}
      end)

    assert last.reward == 1.0
    assert last.terminated
    refute last.truncated
  end

  test "hole terminates with zero reward" do
    env = FrozenLake.new(is_slippery: false, seed: 0)
    {:ok, env, _} = FrozenLake.step(env, 1)
    {:ok, env, exp} = FrozenLake.step(env, 2)
    assert FrozenLake.cell(env) == ?H
    assert exp.terminated
    assert exp.reward == 0.0
  end

  test "renders a grid" do
    env = FrozenLake.new(is_slippery: false)
    {:ok, svg} = FrozenLake.render(env, :svg)
    assert svg =~ "FrozenLake"
    {:ok, ansi} = FrozenLake.render(env, :ansi)
    assert ansi =~ "@"
  end
end
