defmodule Gyx.Core.SpacesTest do
  use ExUnit.Case

  alias Gyx.Core.Spaces
  alias Spaces.{Discrete, Box}

  test "Spaces | Discrete | contains" do
    discrete_space1 = %Discrete{n: 7}
    assert Spaces.contains(discrete_space1, 8) == false
    assert Spaces.contains(discrete_space1, 6) == true
  end
end
