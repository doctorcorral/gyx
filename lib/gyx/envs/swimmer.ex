defmodule Gyx.Envs.Swimmer do
  @moduledoc """
  Farama Swimmer-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "Swimmer-v4",
    xml: "swimmer.xml",
    frame_skip: 4,
    obs: 8,
    act: 2,
    max_steps: 1000,
    track: "torso",
    distance: 3.0,
    view: :xy,
    water: true,
    ground: false

  def observe(%{data: %{qpos: q, qvel: v}}) do
    [_x, _y | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(v))
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.1)
    {nv, rng} = noise_list(rng, model.nv, 0.1)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(_env, before, after_d, u) do
    dt = 0.04
    x_vel = (elem(after_d.qpos, 0) - elem(before.qpos, 0)) / dt
    ctrl = 1.0e-4 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    {x_vel - ctrl, %{x_velocity: x_vel, reward_ctrl: -ctrl}}
  end

  def terminated?(_), do: false
end
