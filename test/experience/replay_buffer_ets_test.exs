defmodule Gyx.Experience.ReplayBufferETSTest do
  use ExUnit.Case
  alias Gyx.Experience.ReplayBufferETS

  @environment_module Gyx.Environments.Pure.Blackjack
  @target_size 13

  setup do
    alias Gyx.Core.Spaces
    environment = @environment_module.start_link([], [])
    action_space = environment.get_state().action_space

    Enum.map(1..@target_size, fn _ ->
      ReplayBufferETS.add(
        @environment_module.step(
          environment,
          with {:ok, action} <- Spaces.sample(action_space) do
            action
          end
        )
      )
    end)

    :ok
  end

  test "Replay Buffer ETS | size" do
    assert length(ReplayBufferETS.get_batch({20, :random})) == @target_size
  end
end
