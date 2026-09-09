defmodule Gyx.ExperimentTest do
  use ExUnit.Case, async: false

  alias Gyx.Agents.QLearning
  alias Gyx.Experiment

  @dir Path.join(System.tmp_dir!(), "gyx-experiment-test")

  setup do
    File.rm_rf!(@dir)
    File.mkdir_p!(@dir)
    on_exit(fn -> File.rm_rf!(@dir) end)
    :ok
  end

  test "new validates the preset" do
    exp = Experiment.new(name: "cart", env: "CartPole-v1", algo: "q_learning", episodes: 2)
    assert exp.env == "CartPole-v1"
    assert exp.algo == "q_learning"

    assert_raise ArgumentError, ~r/no preset/, fn ->
      Experiment.new(env: "CartPole-v1", algo: "nope")
    end
  end

  test "save, list, load, and run a tiny FrozenLake experiment" do
    exp =
      Experiment.new(
        name: "lake",
        env: "FrozenLake-v1",
        algo: "q_learning",
        episodes: 3,
        seed: 1
      )

    assert :ok = Experiment.save(exp, @dir)
    assert Experiment.list(@dir) == ["lake"]
    assert File.regular?(Path.join([@dir, "lake", "experiment.json"]))
    refute File.exists?(Path.join([@dir, "lake", "agent.bin"]))

    {:ok, loaded} = Experiment.load("lake", @dir)
    assert loaded.env == "FrozenLake-v1"
    assert loaded.agent == nil

    ran = Experiment.run(loaded, episodes: 2, max_steps: 8)
    assert ran.episodes == 2
    assert length(ran.returns) == 2
    assert is_float(ran.eval_return)
    assert ran.agent != nil

    assert :ok = Experiment.save(ran, @dir)
    {:ok, stored} = Experiment.load("lake", @dir)
    assert stored.returns == ran.returns
    assert stored.agent != nil
    assert File.regular?(Path.join([@dir, "lake", "agent.bin"]))
  end

  test "checkpoint restores the Q-table and resumes unless fresh" do
    exp =
      Experiment.new(name: "lake", env: "FrozenLake-v1", algo: "q_learning", episodes: 8, seed: 1)
      |> Experiment.run(max_steps: 8)

    assert map_size(exp.agent.q) > 0
    q = exp.agent.q
    epsilon = exp.agent.epsilon

    assert :ok = Experiment.save(exp, @dir)
    {:ok, loaded} = Experiment.load("lake", @dir)
    assert loaded.agent.q == q
    assert loaded.agent.epsilon == epsilon
    assert is_function(loaded.agent.encode) or loaded.agent.encode == nil

    resumed = Experiment.run(loaded, episodes: 1, max_steps: 8)
    assert map_size(resumed.agent.q) >= map_size(q)

    fresh = Experiment.run(loaded, episodes: 1, max_steps: 8, fresh: true)
    assert %QLearning{} = fresh.agent
    assert fresh.agent.q != q
  end

  test "eval uses the checkpoint and can retarget the env id" do
    exp =
      Experiment.new(name: "lake", env: "FrozenLake-v1", algo: "q_learning", episodes: 4, seed: 1)
      |> Experiment.run(max_steps: 8)

    scored = Experiment.eval(exp, episodes: 3, max_steps: 8)
    assert is_float(scored.eval_return)

    again = Experiment.eval(scored, env: "FrozenLake-v1", episodes: 2, max_steps: 8)
    assert is_float(again.eval_return)

    assert_raise ArgumentError, ~r/no checkpoint/, fn ->
      Experiment.eval(Experiment.new(name: "empty", env: "FrozenLake-v1", algo: "q_learning"))
    end
  end

  test "A2C params survive a round-trip" do
    exp =
      Experiment.new(name: "cart", env: "CartPole-v1", algo: "a2c", episodes: 2, seed: 1)
      |> Experiment.run(max_steps: 12)

    assert :ok = Experiment.save(exp, @dir)
    {:ok, loaded} = Experiment.load("cart", @dir)
    assert loaded.agent.__struct__ == exp.agent.__struct__

    scored = Experiment.eval(loaded, episodes: 2, max_steps: 12)
    assert is_float(scored.eval_return)
  end
end
