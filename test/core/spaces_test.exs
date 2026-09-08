defmodule Gyx.Core.SpacesTest do
  use ExUnit.Case, async: true

  alias Gyx.Core.Spaces
  alias Gyx.Core.Spaces.{Box, Discrete, Tuple}

  test "Discrete contains? and sample" do
    space = %Discrete{n: 7}
    refute Spaces.contains?(space, 7)
    refute Spaces.contains?(space, -1)
    assert Spaces.contains?(space, 6)
    {:ok, point} = Spaces.sample(space)
    assert Spaces.contains?(space, point)
  end

  test "Box sample matches shape and bounds" do
    space = %Box{shape: {2}, low: 0.0, high: 1.0}
    {:ok, {a, b} = point} = Spaces.sample(space)
    assert Spaces.contains?(space, point)
    assert a >= 0.0 and a <= 1.0
    assert b >= 0.0 and b <= 1.0
    refute Spaces.contains?(space, {0.5})
  end

  test "1-D Box accepts a scalar" do
    space = %Box{shape: {1}, low: -2.0, high: 2.0}
    assert Spaces.contains?(space, 0.5)
    assert Spaces.contains?(space, {-1.0})
    refute Spaces.contains?(space, 3.0)
  end

  test "image Box samples a uint8 tensor" do
    space = %Box{shape: {2, 2, 3}, low: 0, high: 255, dtype: :u8}
    {:ok, tensor} = Spaces.sample(space)
    assert Nx.shape(tensor) == {2, 2, 3}
    assert Nx.type(tensor) == {:u, 8}
    assert Spaces.contains?(space, tensor)
    refute Spaces.contains?(space, {0, 0})
    refute Spaces.contains?(space, Nx.tensor([[0, 1], [2, 3]], type: :u8))
  end

  test "1-D Box still samples a float tuple and also accepts a tensor" do
    space = %Box{shape: {2}, low: 0.0, high: 1.0}
    {:ok, {a, b} = point} = Spaces.sample(space)
    assert Spaces.contains?(space, point)
    assert a >= 0.0 and a <= 1.0
    assert b >= 0.0 and b <= 1.0
    assert Spaces.contains?(space, Nx.tensor([0.25, 0.75], type: :f32))
  end

  test "Tuple samples each subspace" do
    space = %Tuple{spaces: [%Discrete{n: 32}, %Discrete{n: 11}, %Discrete{n: 2}]}
    {:ok, {x, y, z} = point} = Spaces.sample(space)
    assert Spaces.contains?(space, point)
    assert x in 0..31
    assert y in 0..10
    assert z in 0..1
    refute Spaces.contains?(space, {0, 0})
  end
end
