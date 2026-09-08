defmodule Gyx.Encode do
  @moduledoc """
  Observation encoders for tabular methods.

  Continuous `Box` observations are bucketed into integer-index tuples
  so `Gyx.Agents.QLearning` can store a finite Q-table.
  """

  @type t :: (term() -> term())
  @type bin_spec :: {low :: number(), high :: number(), bins :: pos_integer()}

  @spec identity() :: t()
  def identity, do: fn obs -> obs end

  @doc "Build an encoder from per-dimension `{low, high, bins}` specs."
  @spec bins([bin_spec()]) :: t()
  def bins(spec) when is_list(spec) do
    fn obs ->
      obs
      |> to_list()
      |> Enum.zip(spec)
      |> Enum.map(fn {x, {low, high, n}} -> bin(x, low, high, n) end)
      |> List.to_tuple()
    end
  end

  @spec for_env(String.t()) :: t()
  def for_env("MountainCar-v0") do
    bins([{-1.2, 0.6, 18}, {-0.07, 0.07, 18}])
  end

  def for_env("CartPole-v1") do
    bins([{-2.4, 2.4, 6}, {-3.0, 3.0, 8}, {-0.2094, 0.2094, 12}, {-3.5, 3.5, 12}])
  end

  def for_env("Pendulum-v1") do
    bins([{-1.0, 1.0, 8}, {-1.0, 1.0, 8}, {-8.0, 8.0, 8}])
  end

  def for_env("InvertedPendulum-v4") do
    bins([{-1.0, 1.0, 8}, {-0.2, 0.2, 12}, {-2.0, 2.0, 8}, {-3.0, 3.0, 8}])
  end

  def for_env("Acrobot-v1") do
    pi = :math.pi()

    bins([
      {-1.0, 1.0, 4},
      {-1.0, 1.0, 4},
      {-1.0, 1.0, 4},
      {-1.0, 1.0, 4},
      {-4 * pi, 4 * pi, 4},
      {-9 * pi, 9 * pi, 4}
    ])
  end

  def for_env(_id), do: identity()

  @doc "One-hot encoder for a Discrete observation in `0..n-1`."
  @spec one_hot(pos_integer()) :: t()
  def one_hot(n) when is_integer(n) and n > 0 do
    fn obs when is_integer(obs) ->
      Enum.map(0..(n - 1), fn i -> if i == obs, do: 1.0, else: 0.0 end)
    end
  end

  defp to_list(obs) when is_tuple(obs), do: Tuple.to_list(obs)
  defp to_list(obs) when is_list(obs), do: obs
  defp to_list(obs), do: [obs]

  defp bin(x, low, high, n) when high > low do
    t = (x - low) / (high - low)
    t = min(max(t, 0.0), 0.999999)
    trunc(t * n)
  end
end
