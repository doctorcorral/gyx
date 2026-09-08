defmodule Gyx.Experience.ReplayBufferETSTest do
  use ExUnit.Case, async: true

  alias Gyx.Core.Exp
  alias Gyx.Experience.ReplayBufferETS

  test "stores and samples experiences" do
    {:ok, buf} = ReplayBufferETS.start_link()

    for i <- 1..13 do
      ReplayBufferETS.add(buf, %Exp{
        observation: i,
        action: 0,
        next_observation: i + 1,
        reward: 1.0
      })
    end

    # casts are async; give ETS a beat
    assert eventually(fn -> ReplayBufferETS.size(buf) == 13 end)
    batch = ReplayBufferETS.get_batch(buf, {20, :random})
    assert length(batch) == 13
    latest = ReplayBufferETS.get_batch(buf, {3, :latest})
    assert length(latest) == 3
  end

  defp eventually(fun, attempts \\ 20) do
    cond do
      fun.() ->
        true

      attempts <= 0 ->
        false

      true ->
        Process.sleep(5)
        eventually(fun, attempts - 1)
    end
  end
end
