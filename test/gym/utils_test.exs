defmodule Gyx.Gym.UtilsTest do
  use ExUnit.Case

  test "Discrete" do
    assert Map.get(Gyx.Gym.Utils.gyx_space('Discrete(42)'), :n) == 42
  end

  test "Box" do
    assert Map.get(Gyx.Gym.Utils.gyx_space('Box(2,)'), :shape) == {2,}
  end

end
