defmodule Gyx.SessionTest do
  use ExUnit.Case, async: true

  alias Gyx.Session

  test "start, step, and reset a classic env" do
    assert {:ok, session} = Session.start("CartPole-v1", seed: 0)
    assert session.id == "CartPole-v1"
    assert is_tuple(session.obs)
    refute Session.done?(session)

    assert {:ok, session} = Session.step(session, 1)
    assert session.last_exp.action == 1
    assert session.return == session.last_exp.reward

    session = Session.reset(session, seed: 1)
    assert session.last_exp == nil
    assert session.return == 0.0
  end

  test "unknown env is an error" do
    assert {:error, {:unknown_env, "Nope-v0"}} = Session.start("Nope-v0")
  end

  test "invalid action is rejected" do
    {:ok, session} = Session.start("CartPole-v1", seed: 0)
    assert {:error, :invalid_action} = Session.step(session, 9)
  end
end
