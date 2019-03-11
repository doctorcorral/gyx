defmodule Gyx.Qstorage.QGenServer do
  use ExUnit.Case

  setup do
    Gyx.Qstorage.QGenServer.q_set(%{a: 1}, 1, 13)
    Gyx.Qstorage.QGenServer.q_set(%{a: 2}, 2, 42)
    Gyx.Qstorage.QGenServer.q_set(%{a: 2}, 1, 11)
  end

  test "Q table | get | GenSerer process" do
    assert Gyx.Qstorage.QGenServer.q_get(%{a: 1}, 1) == 13
  end

  test "Q table | get_action | GenSerer process" do
    assert Gyx.Qstorage.QGenServer.get_max_action(%{a: 2}) == {:ok, 2}
  end
end
