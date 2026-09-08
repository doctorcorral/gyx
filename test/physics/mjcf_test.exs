defmodule Gyx.Physics.MjcfTest do
  use ExUnit.Case, async: true

  alias Gyx.Physics.Mjcf

  @official %{
    "inverted_pendulum.xml" => %{nq: 2, nv: 2, nu: 1, masses: [0.0, 10.47197551196598, 5.018591641363306]},
    "hopper.xml" => %{nq: 6, nv: 6, nu: 3, masses: [0.0, 3.6651914291880923, 4.057890510886818, 2.7813566959781637, 5.31557476987393]},
    "reacher.xml" => %{nq: 4, nv: 4, nu: 2}
  }

  test "compiled nq/nv/nu and hopper/IP masses match MuJoCo" do
    for {name, expect} <- @official do
      model = Mjcf.load(name)
      assert model.nq == expect.nq
      assert model.nv == expect.nv
      assert model.nu == expect.nu

      if Map.has_key?(expect, :masses) do
        Enum.zip(model.bodies, expect.masses)
        |> Enum.each(fn {body, mass} ->
          assert_in_delta body.mass, mass, 1.0e-3
        end)
      end
    end
  end

  test "hopper actuators use gear 200 on the hinge dofs" do
    model = Mjcf.load("hopper.xml")
    assert Enum.map(model.actuators, & &1.gear) == [200.0, 200.0, 200.0]
    assert Enum.map(model.actuators, & &1.vadr) == [3, 4, 5]
    assert model.integrator == :rk4
    assert_in_delta model.dt, 0.002, 1.0e-9
  end

  test "inverted pendulum motor is gear 100 on the slider" do
    model = Mjcf.load("inverted_pendulum.xml")
    [act] = model.actuators
    assert act.gear == 100.0
    assert act.vadr == 0
    assert act.ctrlrange == {-3.0, 3.0}
  end

  test "leading-dot MJCF numbers parse (IDP tip, hopper solref)" do
    idp = Mjcf.load("inverted_double_pendulum.xml")
    [tip] = idp.sites
    assert tip.name == "tip"
    assert_in_delta elem(tip.pos, 2), 0.6, 1.0e-9

    hopper = Mjcf.load("hopper.xml")
    geom = hd(hopper.geoms)
    assert_in_delta hd(geom.solref), 0.02, 1.0e-9
    assert_in_delta Enum.at(geom.solimp, 0), 0.8, 1.0e-9

    cheetah = Mjcf.load("half_cheetah.xml")
    bthigh = Enum.find(cheetah.bodies, &(&1.name == "bthigh"))
    assert_in_delta elem(bthigh.pos, 0), -0.5, 1.0e-9
  end
end
