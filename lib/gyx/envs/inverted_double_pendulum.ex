defmodule Gyx.Envs.InvertedDoublePendulum do
  @moduledoc """
  Farama InvertedDoublePendulum-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "InvertedDoublePendulum-v4",
    xml: "inverted_double_pendulum.xml",
    frame_skip: 5,
    obs: 11,
    act: 1,
    act_low: -1.0,
    act_high: 1.0,
    max_steps: 1000,
    reward_threshold: 9100.0,
    track: "cart",
    distance: 3.2

  def observe(%{data: data}) do
    q = data.qpos
    v = clip_tuple(data.qvel, -10.0, 10.0)
    c = clip_tuple(data.qfrc_constraint, -10.0, 10.0)

    {elem(q, 0), :math.sin(elem(q, 1)), :math.sin(elem(q, 2)), :math.cos(elem(q, 1)), :math.cos(elem(q, 2)),
     elem(v, 0), elem(v, 1), elem(v, 2), elem(c, 0), elem(c, 1), elem(c, 2)}
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.1)
    {nv, rng} = normal_list(rng, model.nv, 0.1)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(_env, _before, after_d, _u) do
    {x, _, y} = tip(after_d)
    dist = 0.01 * x * x + (y - 2) * (y - 2)
    v1 = elem(after_d.qvel, 1)
    v2 = elem(after_d.qvel, 2)
    vel = 1.0e-3 * v1 * v1 + 5.0e-3 * v2 * v2
    {10.0 - dist - vel, %{}}
  end

  def terminated?(%{data: data}) do
    {_, _, y} = tip(data)
    y <= 1.0
  end

  defp tip(data) do
    case data.site_xpos do
      [{x, y, z} | _] -> {x, y, z}
      _ -> {elem(data.qpos, 0), 0.0, 1.2}
    end
  end
end
