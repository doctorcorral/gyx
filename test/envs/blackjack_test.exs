defmodule Gyx.Envs.BlackjackTest do
  use ExUnit.Case, async: true

  alias Gyx.Envs.Blackjack

  test "observation is {player_sum, dealer_showing, usable_ace}" do
    env = Blackjack.new(seed: 3)
    {sum, showing, ace} = Blackjack.observe(env)
    assert sum in 4..21
    assert showing in 1..10
    assert ace in [0, 1]
    assert env.observation_space.spaces |> length() == 3
  end

  test "hit can bust and terminate" do
    env = force_hands(Blackjack.new(seed: 0), [10, 10, 2], [5, 6])
    {:ok, env, exp} = Blackjack.step(env, 1)
    assert exp.terminated
    assert exp.reward == -1.0
    {sum, _, _} = Blackjack.observe(env)
    assert sum > 21
  end

  test "stick compares against the dealer" do
    env = force_hands(Blackjack.new(seed: 0), [10, 9], [5, 6])
    {:ok, env, exp} = Blackjack.step(env, 0)
    assert exp.terminated
    assert exp.reward in [-1.0, 0.0, 1.0, 1.5]
    assert length(env.dealer) >= 2
  end

  test "dealer showing card stays the first card after stick" do
    env = force_hands(Blackjack.new(seed: 0), [10, 9], [5, 6])
    {_, showing, _} = Blackjack.observe(env)
    {:ok, env, _} = Blackjack.step(env, 0)
    {_, showing_after, _} = Blackjack.observe(env)
    assert showing == 5
    assert showing_after == showing
  end

  test "usable ace is counted as 11 when it does not bust" do
    env = force_hands(Blackjack.new(seed: 0), [1, 6], [10, 3])
    assert Blackjack.observe(env) == {17, 10, 1}
  end

  defp force_hands(env, player, dealer) do
    %{env | player: player, dealer: dealer, finished: false}
  end
end
