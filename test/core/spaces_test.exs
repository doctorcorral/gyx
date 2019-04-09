defmodule Gyx.Core.SpacesTest do
  use ExUnit.Case

  alias Gyx.Core.Spaces
  alias Spaces.{Discrete, Box}

  test "Spaces | Discrete | contains?" do
    discrete_space1 = %Discrete{n: 7}
    assert Spaces.contains?(discrete_space1, 8) == false
    assert Spaces.contains?(discrete_space1, 6) == true
  end

  test "Spaces | Box | contains?" do
    box_space = %Box{shape: {1, 2}}
    {:ok, box_point} = Spaces.sample(box_space)
    assert Spaces.contains?(box_space, box_point) == true
    assert Spaces.contains?(box_space, [[0.5]]) == false
    assert Spaces.contains?(box_space, [[0.5], [0.5, 5.0]]) == false
  end
end
