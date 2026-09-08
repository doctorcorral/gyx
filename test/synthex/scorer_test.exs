defmodule Gyx.Synthex.ScorerTest do
  use ExUnit.Case, async: true

  alias Gyx.Policy
  alias Gyx.Synthex.Scorer

  test "chain_action uses the first matching predicate" do
    # CartPole: push right when pole angle (index 2) is negative
    chain = [{["feat", ["axis", 2, 0.0]], 1}]
    assert Policy.chain_action(chain, 0, {0.0, 0.0, -0.1, 0.0}) == 1
    assert Policy.chain_action(chain, 0, {0.0, 0.0, 0.1, 0.0}) == 0
  end

  test "collect_states rolls out CartPole without Python" do
    scorer = Scorer.new("CartPole-v1")

    assert {:ok, resp} =
             scorer.(%{
               "cmd" => "collect_states",
               "chain" => [],
               "default" => 0,
               "seeds" => [0, 1],
               "max_steps" => 20
             })

    assert length(resp["states"]) > 0
    assert length(hd(resp["states"])) == 4
    assert resp["n_episodes"] == 2
  end

  test "score compares candidate predicates on MountainCar" do
    scorer = Scorer.new("MountainCar-v0")

    assert {:ok, resp} =
             scorer.(%{
               "cmd" => "score",
               "candidates" => [["feat", ["axis", 0, 0.0]]],
               "stage_action" => 2,
               "default" => 0,
               "chain_so_far" => [],
               "chain_after" => [],
               "seeds" => [0],
               "max_steps" => 30
             })

    assert [%{"idx" => 0, "reward" => reward}] = resp["scores"]
    assert is_float(reward)
    assert is_float(resp["baseline_reward"])
  end
end
