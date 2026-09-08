defmodule Gyx.Envs.Mujoco do
  @moduledoc """
  Shared helpers for Gymnasium-shaped MuJoCo-style environments.

  Dynamics run in `Gyx.Physics.Tree` (native rigid-body tree + contacts),
  not the MuJoCo C library. Observation and reward layouts follow the
  Farama v4/v5 contracts so trainers and papers can transfer.
  """

  alias Gyx.Physics.Tree
  alias Gyx.Render.Scene

  def decode_action(action, n, lo, hi) when is_integer(action) and n == 1 do
    case action do
      0 -> {:ok, {lo * 1.0}}
      1 -> {:ok, {0.0}}
      2 -> {:ok, {hi * 1.0}}
      _ -> :error
    end
  end

  def decode_action(action, n, lo, hi) when is_integer(action) do
    grid = discrete_grid(n, [lo * 1.0, 0.0, hi * 1.0])

    if action >= 0 and action < length(grid) do
      {:ok, List.to_tuple(Enum.at(grid, action))}
    else
      :error
    end
  end

  def decode_action(action, n, lo, hi) do
    list = to_list(action)

    if length(list) == n and Enum.all?(list, &is_number/1) do
      {:ok, list |> Enum.map(&clip(&1 * 1.0, lo, hi)) |> List.to_tuple()}
    else
      :error
    end
  end

  def discrete_actions(n, lo, hi) when n == 1, do: [lo * 1.0, 0.0, hi * 1.0]

  def discrete_actions(n, lo, hi) do
    discrete_grid(n, [lo * 1.0, 0.0, hi * 1.0])
    |> Enum.map(&List.to_tuple/1)
  end

  @doc """
  Discrete actions for playground trainers.

  Full 3-level grids when `n <= 3`. Larger boxes use a sparse set:
  all-zero plus one joint at a time at the limits.
  """
  def train_actions(n, lo, hi) when n <= 3, do: discrete_actions(n, lo, hi)

  def train_actions(n, lo, hi) when n > 3 do
    zero = zeros(n)

    tagged =
      Enum.flat_map(0..(n - 1), fn i ->
        [put_elem(zero, i, lo * 1.0), put_elem(zero, i, hi * 1.0)]
      end)

    [zero | tagged]
  end

  def discrete_grid(1, values), do: Enum.map(values, &[&1])

  def discrete_grid(n, values) when n > 1 do
    for rest <- discrete_grid(n - 1, values), v <- values, do: [v | rest]
  end

  def zeros(n), do: List.duplicate(0.0, n) |> List.to_tuple()

  def noise(rng, n, scale) do
    Enum.map_reduce(1..n, rng, fn _, rng ->
      Gyx.RNG.uniform_range(rng, -scale, scale)
    end)
    |> then(fn {xs, rng} -> {List.to_tuple(xs), rng} end)
  end

  def add(a, b) do
    for i <- 0..(tuple_size(a) - 1) do
      elem(a, i) + elem(b, i)
    end
    |> List.to_tuple()
  end

  def clip(x, lo, hi), do: min(max(x, lo), hi)

  def integrate(q, qd, tau, model, dt, nsub) do
    Tree.step(q, qd, tau, model, dt, nsub)
  end

  def render_scene(q, model, opts), do: {:ok, Scene.from_tree(q, model, opts)}
  def render_svg(q, model, title), do: {:ok, Scene.svg(q, model, title)}

  def tip(q, model, name, offset \\ {0.0, 0.0, 0.0}) do
    poses = Tree.fk(q, model)
    Tree.world_point(poses[name], offset)
  end

  def com(q, model, name) do
    poses = Tree.fk(q, model)
    pose = poses[name]
    Tree.world_point(pose, pose.body.com)
  end

  defp to_list(x) when is_tuple(x), do: Tuple.to_list(x)
  defp to_list(x) when is_list(x), do: x
  defp to_list(x) when is_number(x), do: [x]
end
