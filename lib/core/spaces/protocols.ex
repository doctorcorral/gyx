defprotocol Gyx.Core.Spaces do
  @moduledoc """
  This protocol defines basic functions to interact with
  action and observation spaces.
  """
  alias Gyx.Core.Spaces.{Discrete, Box}

  @type space :: Discrete.t() | Box.t()
  @type discrete_point :: integer()
  @type box_point :: list(float())

  @doc """
  Samples a random point from a space.
  Note that sampled points are very different in nature
  depending on the underlying space.
  This sampling is pretty important for an agent, as
  it is the way the agent might decide which actions to take
  from an action space defined on the environment the agent is
  interacting with.
  ## Parameters

    - space: Any module representing a space.

  ## Examples
      iex> discrete_space = %Gyx.Core.Spaces.Discrete{n: 42}
      %Gyx.Core.Spaces.Discrete{n: 42, random_algorithm: :exsplus, seed: {1,2,3}}

      iex> Gyx.Core.Spaces.set_seed(discrete_space)
      {%{
        jump: #Function<16.10897371/1 in :rand.ml_alg/1>
        max: 288230376151711743,
        next: #Function<15.1089737/1 in :rand.mk_alg/1>
        type: :explus
      }, [72022415603679006 | 144185572652843231]}

      iex> Gyx.Core.Spaces.sample(discrete_space)
      {:ok, 35}

      iex> Gyx.Core.Spaces.sample(%Gyx.Core.Spaces.Box{shape: {2}, high: 7}
      {:ok, [[3.173570417347619, 0.286615818442874]]}
  """
  @spec sample(space()) :: any()
  def sample(space)

  @spec contains(space(), discrete_point()) :: bool()
  def contains(space, discrete_point)

  @doc """
  Sets the random generator used by `sample/1` with the
  space defined seed.
  """
  defdelegate set_seed(space), to: Gyx.Core.Spaces.Shared
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Discrete do
  def sample(discrete_space) do
    {:ok, :rand.uniform(discrete_space.n) - 1}
  end

  def contains(discrete_space, discrete_point) do
    discrete_point in 0..(discrete_space.n - 1)
  end
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Box do
  def sample(box_space) do
    random_action =
      box_space.shape
      |> Tuple.to_list()
      |> Enum.map(&get_rands(&1, box_space))

    {:ok, random_action}
  end

  def contains(_), do: true

  defp get_rands(n, box_space) do
    Enum.map(1..n, fn _ -> :rand.uniform() * (box_space.high - box_space.low) + box_space.low end)
  end
end

defmodule Gyx.Core.Spaces.Shared do
  def set_seed(%{random_algorithm: algo, seed: seed}) do
    :rand.seed(algo, seed)
  end
end
