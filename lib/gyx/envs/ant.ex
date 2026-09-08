defmodule Gyx.Envs.Ant do
  @moduledoc """
  Farama Ant-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "Ant-v4",
    xml: "ant.xml",
    frame_skip: 5,
    obs: 27,
    act: 8,
    max_steps: 1000,
    reward_threshold: 6000.0,
    track: "torso",
    distance: 4.0

  alias Gyx.Physics.Mj

  def observe(%{data: %{qpos: q, qvel: v}}) do
    [_x, _y | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(v))
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.1)
    {nv, rng} = noise_list(rng, model.nv, 0.1)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(%{model: model}, before, after_d, u) do
    dt = 0.05
    {x0, _y0, _} = Mj.body_com(model, before, "torso")
    {x1, y1, _} = Mj.body_com(model, after_d, "torso")
    x_vel = (x1 - x0) / dt
    ctrl = 0.5 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    alive = 1.0
    {x_vel + alive - ctrl, %{x_velocity: x_vel, y_position: y1, reward_survive: alive}}
  end

  def terminated?(%{data: data}), do: not healthy?(data)

  defp healthy?(data) do
    z = elem(data.qpos, 2)
    finite? = Enum.all?(Tuple.to_list(data.qpos) ++ Tuple.to_list(data.qvel), &(is_number(&1) and &1 == &1))
    finite? and z >= 0.2 and z <= 1.0
  end
end
