defmodule Gyx.Gym.UtilsTest do
  use ExUnit.Case

  test "Discrete" do
    assert Map.get(Gyx.Gym.Utils.gyx_space('Discrete(42)'), :n) == 42
  end

end
