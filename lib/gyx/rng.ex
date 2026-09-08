defmodule Gyx.RNG do
  @moduledoc false

  @type t :: :rand.state()

  @spec seed(term()) :: t()
  def seed(nil), do: :rand.seed_s(:exsss)

  def seed(n) when is_integer(n) do
    :rand.seed_s(
      :exsss,
      {n, rem(n * 1_103_515_245 + 12_345, 268_435_455),
       rem(n * 1_664_525 + 1_013_904_223, 268_435_455)}
    )
  end

  def seed({_, _, _} = triple), do: :rand.seed_s(:exsss, triple)
  def seed(other), do: seed(:erlang.phash2(other))

  @spec uniform(t()) :: {float(), t()}
  def uniform(rng), do: :rand.uniform_s(rng)

  @spec uniform(t(), pos_integer()) :: {pos_integer(), t()}
  def uniform(rng, n) when n > 0, do: :rand.uniform_s(n, rng)

  @spec uniform_range(t(), number(), number()) :: {float(), t()}
  def uniform_range(rng, low, high) do
    {u, rng} = uniform(rng)
    {low + u * (high - low), rng}
  end

  @spec int(t(), integer(), integer()) :: {integer(), t()}
  def int(rng, min, max) when max >= min do
    {n, rng} = uniform(rng, max - min + 1)
    {n + min - 1, rng}
  end

  @spec normal(t()) :: {float(), t()}
  def normal(rng) do
    {u1, rng} = uniform(rng)
    {u2, rng} = uniform(rng)
    u1 = max(u1, 1.0e-12)
    {:math.sqrt(-2.0 * :math.log(u1)) * :math.cos(2.0 * :math.pi() * u2), rng}
  end
end
