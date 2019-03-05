defprotocol Gyx.Core.Spaces do
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
