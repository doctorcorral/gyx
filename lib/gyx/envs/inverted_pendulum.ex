defmodule Gyx.Envs.InvertedPendulum do
  @moduledoc """
  Farama InvertedPendulum-v4, native MJCF + `Gyx.Physics.Mj`.
  """

  use Gyx.Envs.MjEnv,
    id: "InvertedPendulum-v4",
    xml: "inverted_pendulum.xml",
    frame_skip: 2,
    obs: 4,
    act: 1,
    act_low: -3.0,
    act_high: 3.0,
    max_steps: 1000,
    reward_threshold: 950.0,
    track: "cart",
    distance: 2.4

  def observe(%{data: %{qpos: q, qvel: v}}) do
    {elem(q, 0), elem(q, 1), elem(v, 0), elem(v, 1)}
  end

  def reset_model(rng, model) do
    {nq, rng} = noise_list(rng, model.nq, 0.01)
    {nv, rng} = noise_list(rng, model.nv, 0.01)
    {add_noise(model.init_qpos, nq), add_noise(model.init_qvel, nv), %{}, rng}
  end

  def reward(_env, _before, _after, _u), do: {1.0, %{}}

  def terminated?(%{data: data}) do
    obs = observe(%{data: data})
    not Enum.all?(Tuple.to_list(obs), &isfinite/1) or abs(elem(obs, 1)) > 0.2
  end

  defp isfinite(x) when is_float(x), do: x == x
  defp isfinite(x) when is_integer(x), do: true
  defp isfinite(_), do: false
end
