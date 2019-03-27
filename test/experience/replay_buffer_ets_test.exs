defmodule Gyx.Experience.ReplayBufferETSTest do
  use ExUnit.Case
  alias Gyx.Experience.ReplayBufferETS

  setup do
    alias Gyx.Core.Spaces
    environment = Gyx.Environments.Blackjack
    action_space = environment.get_state().action_space

    Enum.map(1..13, fn _ ->
      ReplayBufferETS.add(
        environment.step(
          with {:ok, action} <- Spaces.sample(action_space) do
            action
          end
        )
      )
    end)

    :ok
  end

  test "Replay Buffer ETS | size" do
    assert length(ReplayBufferETS.get_batch({20, :random})) == 13
  end
end
