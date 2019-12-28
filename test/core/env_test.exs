defmodule Gyx.Core.EnvTest do
  use ExUnit.Case, async: true

  @environment_module Gyx.Environments.Pure.Blackjack

  setup do
    {:ok, environment} = @environment_module.start_link([], [])
    {:ok, %{environment: environment}}
  end

  test "valid action", %{environment: environment} do
    assert @environment_module.step(environment, 140) == {:error, "invalid_action"}
  end
end
