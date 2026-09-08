defmodule Gyx.Envs.HalfCheetah do
  @moduledoc """
  Farama HalfCheetah-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "HalfCheetah-v4",
    xml: "half_cheetah.xml",
    frame_skip: 5,
    obs: 17,
    act: 6,
    max_steps: 1000,
    reward_threshold: 4800.0,
    track: "torso",
    distance: 3.8

  def observe(%{data: %{qpos: q, qvel: v}}) do
    [_x | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(v))
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.1)
    {nv, rng} = normal_list(rng, model.nv, 0.1)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(_env, before, after_d, u) do
    dt = 0.05
    x_vel = (elem(after_d.qpos, 0) - elem(before.qpos, 0)) / dt
    ctrl = 0.1 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    {x_vel - ctrl, %{x_velocity: x_vel, reward_run: x_vel, reward_ctrl: -ctrl}}
  end

  def terminated?(_), do: false
end
