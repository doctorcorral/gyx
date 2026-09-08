defmodule Gyx.Render.Png do
  @moduledoc false

  @spec from_tensor(term()) :: {:ok, binary()} | :error
  def from_tensor(%Nx.Tensor{} = tensor) do
    case Nx.shape(tensor) do
      {height, width, 3} ->
        rgb =
          tensor
          |> Nx.backend_copy(Nx.BinaryBackend)
          |> Nx.as_type(:u8)
          |> Nx.to_binary()

        {:ok, encode_rgb(width, height, rgb)}

      _ ->
        :error
    end
  end

  def from_tensor(_), do: :error

  @spec encode_rgb(pos_integer(), pos_integer(), binary()) :: binary()
  def encode_rgb(width, height, rgb)
      when is_integer(width) and is_integer(height) and is_binary(rgb) do
    row = width * 3

    raw =
      for <<pixels::binary-size(row) <- rgb>>, into: <<>> do
        <<0, pixels::binary>>
      end

    ihdr = <<width::32, height::32, 8, 2, 0, 0, 0>>

    signature() <>
      chunk("IHDR", ihdr) <>
      chunk("IDAT", :zlib.compress(raw)) <>
      chunk("IEND", "")
  end

  defp signature, do: <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>

  defp chunk(type, data) do
    crc = :erlang.crc32(type <> data)
    <<byte_size(data)::32, type::binary, data::binary, crc::32>>
  end
end
