defmodule Gyx.Nx.Features do
  @moduledoc false

  @spec to_tensor(term(), keyword()) :: Nx.Tensor.t()
  def to_tensor(obs, opts \\ []) do
    encode = Keyword.get(opts, :encode)
    obs_dim = Keyword.get(opts, :obs_dim)

    values =
      cond do
        is_function(encode, 1) -> flatten(encode.(obs))
        is_integer(obs) and is_integer(obs_dim) -> one_hot(obs, obs_dim)
        true -> flatten(obs)
      end

    Nx.tensor([Enum.map(values, &(&1 * 1.0))], type: :f32)
  end

  defp one_hot(i, n), do: Enum.map(0..(n - 1), fn j -> if j == i, do: 1.0, else: 0.0 end)

  defp flatten(obs) when is_tuple(obs), do: flatten(Tuple.to_list(obs))
  defp flatten(obs) when is_list(obs), do: Enum.flat_map(obs, &flatten/1)
  defp flatten(obs) when is_number(obs), do: [obs]
  defp flatten(%Nx.Tensor{} = t), do: Nx.to_flat_list(t)
  defp flatten(obs), do: [obs]
end
