defmodule GyxTest do
  use ExUnit.Case
  #doctest Gyx

  test "Q table | get set | GenSerer process" do
    Gyx.Qstorage.QGenServer.q_set(%{a: 1}, 1, 13)
    Gyx.Qstorage.QGenServer.q_set(%{a: 2}, 2, 42)
    Gyx.Qstorage.QGenServer.q_set(%{a: 2}, 1, 11)
    assert Gyx.Qstorage.QGenServer.q_get(%{a: 1}, 1) == 13
  end
end
