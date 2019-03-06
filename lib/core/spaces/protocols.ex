defprotocol Gyx.Core.Spaces do
  @moduledoc """
  This protocol defines basic functions to interact with
  action and observation spaces.
  """

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
      iex> Gyx.Core.Spaces.sample(%Gyx.Core.Spaces.Discrete{n: 42})
      {:ok, 13}

      iex> Gyx.Core.Spaces.sample(%Gyx.Core.Spaces.Box{shape: {2}, high: 7}
      {:ok, [[3.173570417347619, 0.286615818442874]]}
  """
  def sample(space)
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Discrete do
  def sample(discrete_space) do
    {:ok, :rand.uniform(discrete_space.n) - 1}
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

  defp get_rands(n, box_space) do
    Enum.map(1..n, fn _ -> :rand.uniform() * (box_space.high - box_space.low) + box_space.low end)
  end
end
