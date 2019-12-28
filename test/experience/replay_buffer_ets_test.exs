defmodule Gyx.Experience.ReplayBufferETSTest do
  use ExUnit.Case
  alias Gyx.Experience.ReplayBufferETS

  @environment_module Gyx.Environments.Pure.Blackjack
  @replay_buffer_module ReplayBufferETS
  @target_size 13

  setup do
    alias Gyx.Core.Spaces
    {:ok, environment} = @environment_module.start_link([], [])
    {:ok, replay} = @replay_buffer_module.start_link([], [])
    action_space = :sys.get_state(environment).action_space

    Enum.map(1..@target_size, fn _ ->
      @replay_buffer_module.add(
        replay,
        @environment_module.step(
          environment,
          with {:ok, action} <- Spaces.sample(action_space) do
            action
          end
        )
      )
    end)

    {:ok, replay_process: replay}
  end

  test "Replay Buffer ETS | size", %{replay_process: replay} do
    assert length(@replay_buffer_module.get_batch(replay, {20, :random})) == @target_size
  end
end
