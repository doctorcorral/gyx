defmodule Gyx.Synthex.ProbeTest do
  use ExUnit.Case, async: true

  alias Gyx.Synthex.Probe

  test "scores CartPole candidates through Synthex.Gym.Oracle without Python" do
    result =
      Probe.run("CartPole-v1",
        seeds: Enum.to_list(0..3),
        max_steps: 25,
        candidates: 4
      )

    assert result.n_states > 0
    assert result.n_features > 0
    assert is_float(result.baseline)
    assert length(result.scored) == 4

    Enum.each(result.scored, fn {idx, reward, wins} ->
      assert is_integer(idx)
      assert is_number(reward)
      assert is_integer(wins)
    end)
  end
end
