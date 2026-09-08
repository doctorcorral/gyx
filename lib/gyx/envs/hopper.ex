defmodule Gyx.Envs.Hopper do
  @moduledoc """
  Farama Hopper-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "Hopper-v4",
    xml: "hopper.xml",
    frame_skip: 4,
    obs: 11,
    act: 3,
    max_steps: 1000,
    reward_threshold: 3800.0,
    track: "torso",
    distance: 3.2

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
    # Gymnasium always adds healthy_reward when terminate_when_unhealthy is true.
    alive = 1.0
    {alive + x_vel - ctrl, %{x_velocity: x_vel, reward_survive: alive}}
  end

  def terminated?(%{data: data}), do: not healthy?(data)

  defp healthy?(data) do
    z = elem(data.qpos, 1)
    angle = elem(data.qpos, 2)
    state = Tuple.to_list(data.qpos) |> Enum.drop(2) |> Kernel.++(Tuple.to_list(data.qvel))
    z > 0.7 and abs(angle) < 0.2 and Enum.all?(state, fn x -> x > -100.0 and x < 100.0 end)
  end
end
