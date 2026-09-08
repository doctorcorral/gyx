defmodule Gyx.ExperimentTest do
  use ExUnit.Case, async: false

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

    {:ok, loaded} = Experiment.load("lake", @dir)
    assert loaded.env == "FrozenLake-v1"

    ran = Experiment.run(loaded, episodes: 2, max_steps: 8)
    assert ran.episodes == 2
    assert length(ran.returns) == 2
    assert is_float(ran.eval_return)
    assert ran.agent != nil

    assert :ok = Experiment.save(ran, @dir)
    {:ok, stored} = Experiment.load("lake", @dir)
    assert stored.returns == ran.returns
  end
end
