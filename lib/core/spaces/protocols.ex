defprotocol Gyx.Core.Spaces do
  @moduledoc """
  This protocol defines basic functions to interact with
  action and observation spaces.
  """
  alias Gyx.Core.Spaces.{Discrete, Box, Tuple}

  @type space :: Discrete.t() | Box.t() | Tuple.t()
  @type discrete_point :: integer
  @type box_point :: Nx.Type.t()
  @type tuple_point :: list(discrete_point | box_point())
  @type point :: box_point | discrete_point | tuple_point
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
  @spec sample(space()) :: {atom(), point()}
  def sample(space)

  @doc """
  Verifies if a particular action or observation point lies inside a given space.

  ## Examples
      iex> box_space = %Box{shape: {1, 2}}
      iex> {:ok, box_point} = Spaces.sample(box_space)
      iex> Spaces.contains(box_space, box_point)
      true
  """
  @spec contains?(space(), point()) :: bool()
  def contains?(space, point)

  @doc """
  Sets the random generator used by `sample/1` with the
  space defined seed.
  """
  Kernel.defdelegate(set_seed(space), to: Gyx.Core.Spaces.Shared)
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Discrete do
  def sample(discrete_space) do
    {:ok, :rand.uniform(discrete_space.n) - 1}
  end

  def contains?(discrete_space, discrete_point) do
    discrete_point in 0..(discrete_space.n - 1)
  end
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Box do
  def sample(box_space = %{shape: shape, high: 1.0, low: 0.0}) do
    random_action = Nx.random_uniform(shape)

    {:ok, random_action}
  end

  def sample(box_space = %{shape: shape, high: h, low: l}) do
    raw_random_action = Nx.random_uniform(shape)
    delta = Nx.add(h, Nx.negate(l))

    random_action =
      raw_random_action
      |> Nx.map([type: {:f, 32}], fn x -> Nx.add(Nx.multiply(x, delta), l) end)

    {:ok, random_action}
  end

  def contains?(box_space = %{high: h, low: l}, box_point) do
    high_eval = (Nx.all(Nx.greater_equal(box_point, l)) ==  Nx.tensor(1, [type: {:u, 8}]))
    low_eval = (Nx.all(Nx.less_equal(box_point, h)) ==  Nx.tensor(1, [type: {:u, 8}]))
    high_eval && low_eval
  end
end
