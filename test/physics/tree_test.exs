defmodule Gyx.Physics.TreeTest do
  use ExUnit.Case, async: true

  alias Gyx.Physics.Tree

  test "gravity lowers an unsupported free body" do
    model = %{
      n: 3,
      inertia: {4.0, 4.0, 1.0},
      damping: 0.05,
      gravity: 9.81,
      contacts: [],
      bodies: [
        %{
          name: :ball,
          parent: nil,
          joint: {:free_planar, 0, 1, 2},
          mass: 1.0,
          com: {0.0, 0.0, 0.0},
          geoms: [{:sphere, {0.0, 0.0, 0.0}, 0.05, "#000"}]
        }
      ]
    }

    q0 = {0.0, 1.0, 0.0}
    qd0 = {0.0, 0.0, 0.0}
    tau = {0.0, 0.0, 0.0}
    {_q, qd} = Tree.step(q0, qd0, tau, model, 0.01, 8)
    {_, vz, _} = qd
    assert vz < 0.0
  end

  test "ground contact supports a resting body" do
    model = %{
      n: 3,
      inertia: {4.0, 2.0, 1.0},
      damping: 0.2,
      gravity: 9.81,
      contact_k: 4000.0,
      contact_c: 80.0,
      friction: 1.0,
      auto_contacts: true,
      contacts: [],
      bodies: [
        %{
          name: :ball,
          parent: nil,
          joint: {:free_planar, 0, 1, 2},
          mass: 1.0,
          com: {0.0, 0.0, 0.0},
          geoms: [{:sphere, {0.0, 0.0, 0.0}, 0.05, "#000"}]
        }
      ]
    }

    q0 = {0.0, 0.0, 0.0}
    qd0 = {0.0, -0.4, 0.0}
    {q, qd} = Tree.step(q0, qd0, {0.0, 0.0, 0.0}, model, 0.002, 20)
    {_, z, _} = q
    {_, vz, _} = qd
    assert z >= 0.04
    assert vz > -0.4
  end
end
