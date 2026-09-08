defmodule Gyx.Nx.Pixels do
  @moduledoc false

  @doc """
  Turn an RGB `uint8` frame into a batched grayscale tensor `{1, h, w, c}`.
  """
  @spec to_batch(term(), {pos_integer(), pos_integer(), pos_integer()}) :: Nx.Tensor.t()
  def to_batch(obs, {h, w, c}) do
    obs
    |> to_hwc()
    |> grayscale()
    |> resize(h, w)
    |> Nx.reshape({1, h, w, c})
    |> Nx.as_type(:f32)
  end

  defp to_hwc(%Nx.Tensor{} = tensor) do
    case Nx.shape(tensor) do
      {_h, _w, 3} ->
        Nx.as_type(tensor, :f32)

      {h, w} ->
        tensor |> Nx.as_type(:f32) |> Nx.reshape({h, w, 1})

      {h, w, 1} ->
        tensor |> Nx.as_type(:f32) |> Nx.reshape({h, w, 1})

      shape ->
        raise ArgumentError, "expected HxW or HxWx3 frame, got #{inspect(shape)}"
    end
  end

  defp grayscale(tensor) do
    case Nx.shape(tensor) do
      {h, w, 1} ->
        tensor |> Nx.reshape({h, w}) |> Nx.divide(255.0)

      {_h, _w, 3} ->
        weights = Nx.tensor([0.299, 0.587, 0.114], type: :f32)
        tensor |> Nx.divide(255.0) |> Nx.dot(weights)
    end
  end

  defp resize(tensor, height, width) do
    {src_h, src_w} = Nx.shape(tensor)
    ys = Nx.tensor(nn_index(src_h, height), type: :s64)
    xs = Nx.tensor(nn_index(src_w, width), type: :s64)

    tensor
    |> Nx.take(ys, axis: 0)
    |> Nx.take(xs, axis: 1)
  end

  defp nn_index(src, dest) do
    Enum.map(0..(dest - 1), fn i -> min(src - 1, div(i * src, dest)) end)
  end
end
