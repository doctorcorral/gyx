defprotocol Gyx.Core.Spaces do
  def sample(space)
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Discrete do
  def sample(discrete_space) do
    {:ok, :rand.uniform(discrete_space.n) - 1}
  end
end

