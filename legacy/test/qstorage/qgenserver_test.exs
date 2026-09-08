defmodule Gyx.Qstorage.QGenServerTest do
  use ExUnit.Case

  setup do
    {:ok, q_pid} = Gyx.Qstorage.QGenServer.start_link([], [])
    Gyx.Qstorage.QGenServer.q_set(q_pid, %{a: 1}, 1, 13)
    Gyx.Qstorage.QGenServer.q_set(q_pid, %{a: 2}, 2, 42)
    Gyx.Qstorage.QGenServer.q_set(q_pid, %{a: 2}, 1, 11)
    {:ok, %{q_pid: q_pid}}
  end

  test "Q table | get | GenSerer process", %{q_pid: q_pid} do
    assert Gyx.Qstorage.QGenServer.q_get(q_pid, %{a: 1}, 1) == 13
  end

  test "Q table | get_action | GenSerer process", %{q_pid: q_pid} do
    assert Gyx.Qstorage.QGenServer.get_max_action(q_pid, %{a: 2}) == {:ok, 2}
  end
end
