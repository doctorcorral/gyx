defmodule Gyx.Render.PngTest do
  use ExUnit.Case, async: true

  test "uint8 HxWx3 tensor encodes as a PNG" do
    tensor = Nx.broadcast(Nx.tensor(128, type: :u8), {2, 3, 3})
    assert {:ok, png} = Gyx.Render.Png.from_tensor(tensor)
    assert binary_part(png, 0, 8) == <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
  end

  test "non-image tensors are rejected" do
    assert :error = Gyx.Render.Png.from_tensor(Nx.tensor([1, 2, 3], type: :u8))
    assert :error = Gyx.Render.Png.from_tensor({1, 2, 3})
  end
end
