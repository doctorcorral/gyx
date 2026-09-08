defprotocol Gyx.Core.Spaces do
  @moduledoc """
  Sampling and membership for action / observation spaces.
  """

  alias Gyx.Core.Spaces.{Box, Discrete, Tuple}

  @type space :: Discrete.t() | Box.t() | Tuple.t()
  @type point :: term()

  @spec sample(space()) :: {:ok, point()}
  def sample(space)

  @spec contains?(space(), point()) :: boolean()
  def contains?(space, point)

  Kernel.defdelegate(set_seed(space), to: Gyx.Core.Spaces.Shared)
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Discrete do
  def sample(%{n: n}) when is_integer(n) and n > 0 do
    {:ok, :rand.uniform(n) - 1}
  end

  def contains?(%{n: n}, point) when is_integer(point) and is_integer(n) do
    point >= 0 and point < n
  end

  def contains?(_space, _point), do: false
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Box do
  alias Gyx.Core.Spaces.Box

  def sample(%Box{} = space) do
    if Box.tensor?(space) do
      {:ok, sample_tensor(space)}
    else
      {:ok, sample_shape(Tuple.to_list(space.shape), space.low, space.high)}
    end
  end

  def contains?(%Box{} = space, %Nx.Tensor{} = tensor) do
    Nx.shape(tensor) == space.shape and type_matches?(tensor, space.dtype) and
      tensor_in_bounds?(tensor, space)
  end

  def contains?(%Box{} = space, point) do
    not Box.tensor?(space) and matches_shape?(point, Tuple.to_list(space.shape)) and
      within_bounds?(point, space.low, space.high)
  end

  defp sample_tensor(%Box{shape: shape, dtype: dtype, low: low, high: high}) do
    n = shape |> Tuple.to_list() |> Enum.product()
    lo = bound_num(low)
    hi = bound_num(high)

    case dtype do
      :u8 ->
        span = max(trunc(hi) - trunc(lo) + 1, 1)

        1..n
        |> Enum.map(fn _ -> trunc(lo) + :rand.uniform(span) - 1 end)
        |> :erlang.list_to_binary()
        |> Nx.from_binary(:u8)
        |> Nx.reshape(shape)

      _ ->
        1..n
        |> Enum.map(fn _ -> uniform(lo, hi) end)
        |> Nx.tensor(type: Box.nx_type(dtype))
        |> Nx.reshape(shape)
    end
  end

  defp type_matches?(tensor, dtype) do
    Nx.type(tensor) == Box.nx_type(dtype)
  end

  defp tensor_in_bounds?(_tensor, %Box{dtype: :u8}), do: true

  defp tensor_in_bounds?(tensor, %Box{low: low, high: high})
       when is_number(low) and is_number(high) do
    Nx.to_number(Nx.reduce_min(tensor)) >= low and Nx.to_number(Nx.reduce_max(tensor)) <= high
  end

  defp tensor_in_bounds?(_tensor, _space), do: true

  defp bound_num(bound) when is_number(bound), do: bound * 1.0
  defp bound_num(bound) when is_tuple(bound), do: elem(bound, 0) * 1.0

  defp sample_shape([n], low, high) when is_integer(n) do
    List.to_tuple(Enum.map(0..(n - 1), fn i -> uniform(bound_at(low, i), bound_at(high, i)) end))
  end

  defp sample_shape([n | rest], low, high) do
    List.to_tuple(Enum.map(1..n, fn _ -> sample_shape(rest, low, high) end))
  end

  defp matches_shape?(point, [1]) when is_number(point), do: true
  defp matches_shape?(point, [n]) when is_tuple(point), do: tuple_size(point) == n
  defp matches_shape?(point, [n]) when is_list(point), do: length(point) == n

  defp matches_shape?(point, [n | rest]) when is_tuple(point) and tuple_size(point) == n do
    point |> Tuple.to_list() |> Enum.all?(&matches_shape?(&1, rest))
  end

  defp matches_shape?(point, [n | rest]) when is_list(point) and length(point) == n do
    Enum.all?(point, &matches_shape?(&1, rest))
  end

  defp matches_shape?(_, _), do: false

  defp within_bounds?(point, low, high) when is_number(point) do
    value_in?(point, bound_at(low, 0), bound_at(high, 0))
  end

  defp within_bounds?(point, low, high) when is_tuple(point) do
    point
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.all?(fn {v, i} -> value_in?(v, bound_at(low, i), bound_at(high, i)) end)
  end

  defp within_bounds?(point, low, high) when is_list(point) do
    point
    |> Enum.with_index()
    |> Enum.all?(fn {v, i} -> value_in?(v, bound_at(low, i), bound_at(high, i)) end)
  end

  defp value_in?(v, low, high) when is_number(v), do: v >= low and v <= high
  defp value_in?(v, low, high), do: within_bounds?(v, low, high)

  defp bound_at(bound, _i) when is_number(bound), do: bound
  defp bound_at(bound, i) when is_tuple(bound), do: elem(bound, i)

  defp uniform(low, high), do: low + :rand.uniform() * (high - low)
end

defimpl Gyx.Core.Spaces, for: Gyx.Core.Spaces.Tuple do
  alias Gyx.Core.Spaces

  def sample(%{spaces: spaces}) when is_list(spaces) do
    {:ok, List.to_tuple(Enum.map(spaces, fn space -> elem(Spaces.sample(space), 1) end))}
  end

  def contains?(%{spaces: spaces}, point) when is_tuple(point) and is_list(spaces) do
    tuple_size(point) == length(spaces) and
      spaces
      |> Enum.with_index()
      |> Enum.all?(fn {space, i} -> Spaces.contains?(space, elem(point, i)) end)
  end

  def contains?(_space, _point), do: false
end
