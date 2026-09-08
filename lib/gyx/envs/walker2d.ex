defmodule Gyx.Envs.Walker2d do
  @moduledoc """
  Farama Walker2d-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "Walker2d-v4",
    xml: "walker2d.xml",
    frame_skip: 4,
    obs: 17,
    act: 6,
    max_steps: 1000,
    reward_threshold: 4000.0,
    track: "torso",
    distance: 3.6

  def observe(%{data: %{qpos: q, qvel: v}}) do
    [_x | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(clip_tuple(v, -10.0, 10.0)))
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 5.0e-3)
    {nv, rng} = noise_list(rng, model.nv, 5.0e-3)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(_env, before, after_d, u) do
    dt = 0.008
    x_vel = (elem(after_d.qpos, 0) - elem(before.qpos, 0)) / dt
    ctrl = 1.0e-3 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    alive = 1.0
    {alive + x_vel - ctrl, %{x_velocity: x_vel}}
  end

  def terminated?(%{data: data}), do: not healthy?(data)

  defp healthy?(data) do
    z = elem(data.qpos, 1)
    angle = elem(data.qpos, 2)
    z > 0.8 and z < 2.0 and angle > -1.0 and angle < 1.0
  end
end
