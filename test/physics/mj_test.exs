defmodule Gyx.Physics.MjTest do
  use ExUnit.Case, async: true

  alias Gyx.Physics.{Mj, Mjcf}

  test "IP mass matrix and one RK4 step match MuJoCo at a probe state" do
    model = Mj.load("inverted_pendulum.xml")
    qpos = {0.1, 0.05}
    qvel = {0.2, -0.1}
    ctrl = {0.3}

    {qacc, act, passive, bias, _c} = Mj.accelerations(model, qpos, qvel, ctrl)
    assert_in_delta elem(act, 0), 30.0, 1.0e-6
    assert_in_delta elem(passive, 0), -0.2, 1.0e-5
    assert_in_delta elem(passive, 1), 0.1, 1.0e-5
    assert_in_delta elem(bias, 1), -0.7627635242579285, 5.0e-3
    assert_in_delta elem(qacc, 0), 2.3222394944097737, 5.0e-3
    assert_in_delta elem(qacc, 1), -4.104915131859885, 5.0e-3

    data = model |> Mj.data(qpos, qvel) |> Mj.set_ctrl(ctrl) |> then(&Mj.step(&1, model, 1))
    assert_in_delta elem(data.qpos, 0), 0.10446360573342055, 5.0e-4
    assert_in_delta elem(data.qpos, 1), 0.04718573497315381, 5.0e-4
    assert_in_delta elem(data.qvel, 0), 0.24632264631904435, 5.0e-3
    assert_in_delta elem(data.qvel, 1), -0.1811329512115771, 5.0e-3
  end

  test "hopper FK at rest matches MuJoCo body xpos" do
    model = Mjcf.load("hopper.xml")
    poses = Mj.fk(model, model.init_qpos)
    torso = Enum.at(poses, 1)
    thigh = Enum.at(poses, 2)
    {_, _, tz} = torso.pos
    {_, _, hz} = thigh.pos
    assert_in_delta tz, 1.25, 1.0e-6
    assert_in_delta hz, 1.05, 1.0e-3
  end
end
