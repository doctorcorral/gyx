defmodule Gyx.EncodeTest do
  use ExUnit.Case, async: true

  alias Gyx.Encode

  test "bins clamp and index each dimension" do
    encode = Encode.bins([{-1.0, 1.0, 4}, {0.0, 10.0, 5}])

    assert encode.({-1.0, 0.0}) == {0, 0}
    assert encode.({1.0, 10.0}) == {3, 4}
    assert encode.({-100.0, 100.0}) == {0, 4}
    assert encode.([0.0, 5.0]) == {2, 2}
  end

  test "MountainCar encoder is an 18×18 grid" do
    encode = Encode.for_env("MountainCar-v0")
    assert encode.({-1.2, -0.07}) == {0, 0}
    assert encode.({0.6, 0.07}) == {17, 17}
    assert encode.({-0.5, 0.0}) == {7, 9}
  end

  test "unknown envs use identity" do
    encode = Encode.for_env("FrozenLake-v1")
    assert encode.(4) == 4
  end

  test "one_hot encodes a discrete index" do
    assert Encode.one_hot(4).(2) == [0.0, 0.0, 1.0, 0.0]
  end

  test "Pendulum encoder is an 8×8×8 grid" do
    encode = Encode.for_env("Pendulum-v1")
    assert encode.({-1.0, -1.0, -8.0}) == {0, 0, 0}
    assert encode.({1.0, 1.0, 8.0}) == {7, 7, 7}
  end
end
