defmodule Gyx.Core.EnvTest do
  use ExUnit.Case, async: true

  alias Gyx.Core.Exp

  test "unknown environment" do
    assert Gyx.make("NotAnEnv-v0") == {:error, {:unknown_env, "NotAnEnv-v0"}}
  end

  test "invalid action is rejected" do
    {:ok, env} = Gyx.make("Blackjack-v1")
    assert Gyx.step(env, 140) == {:error, :invalid_action}
  end

  test "server wrapper steps and resets" do
    {:ok, pid} = Gyx.make("FrozenLake-v1", server: true, is_slippery: false, seed: 1)
    {_env, obs, _info} = Gyx.reset(pid, seed: 1)
    assert obs == 0
    {:ok, _env, %Exp{} = exp} = Gyx.step(pid, 1)
    assert exp.action == 1
    assert is_integer(exp.next_observation)
  end
end
