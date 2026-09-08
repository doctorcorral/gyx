defmodule Gyx.Envs.Reacher do
  @moduledoc """
  Farama Reacher-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "Reacher-v4",
    xml: "reacher.xml",
    frame_skip: 2,
    obs: 11,
    act: 2,
    max_steps: 50,
    reward_threshold: -3.75,
    track: "body0",
    distance: 1.4,
    view: :xy

  alias Gyx.Physics.Mj

  def observe(%{data: data, model: model}) do
    th1 = elem(data.qpos, 0)
    th2 = elem(data.qpos, 1)
    poses = Mj.fk(model, data.qpos)
    {fx, fy, fz} = Mj.com_at(model, poses, "fingertip")
    {tx, ty, tz} = Mj.com_at(model, poses, "target")

    {:math.cos(th1), :math.cos(th2), :math.sin(th1), :math.sin(th2), elem(data.qpos, 2), elem(data.qpos, 3),
     elem(data.qvel, 0), elem(data.qvel, 1), fx - tx, fy - ty, fz - tz}
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.1)
    qpos = add_noise(model.init_qpos, nq)
    {goal, rng} = goal(rng)
    qpos = qpos |> put_elem(2, elem(goal, 0)) |> put_elem(3, elem(goal, 1))
    {nv, rng} = noise_list(rng, model.nv, 0.005)
    qvel = add_noise(model.init_qvel, nv) |> put_elem(2, 0.0) |> put_elem(3, 0.0)
    {qpos, qvel, %{goal: goal}, rng}
  end

  def reward(%{model: model}, before, _after, {u1, u2}) do
    poses = Mj.fk(model, before.qpos)
    {fx, fy, fz} = Mj.com_at(model, poses, "fingertip")
    {tx, ty, tz} = Mj.com_at(model, poses, "target")
    dist = :math.sqrt((fx - tx) ** 2 + (fy - ty) ** 2 + (fz - tz) ** 2)
    ctrl = u1 * u1 + u2 * u2
    {-dist - ctrl, %{reward_dist: -dist, reward_ctrl: -ctrl}}
  end

  def terminated?(_), do: false

  defp goal(rng) do
    {tx, rng} = Gyx.RNG.uniform_range(rng, -0.2, 0.2)
    {ty, rng} = Gyx.RNG.uniform_range(rng, -0.2, 0.2)
    if :math.sqrt(tx * tx + ty * ty) < 0.2, do: {{tx, ty}, rng}, else: goal(rng)
  end
end
