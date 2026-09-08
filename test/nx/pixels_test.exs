defmodule Gyx.Nx.PixelsTest do
  use ExUnit.Case, async: true

  test "RGB frames become a batched grayscale 84×84 tensor" do
    frame =
      Nx.concatenate(
        [
          Nx.broadcast(Nx.tensor(255, type: :u8), {4, 6, 1}),
          Nx.broadcast(Nx.tensor(0, type: :u8), {4, 6, 1}),
          Nx.broadcast(Nx.tensor(0, type: :u8), {4, 6, 1})
        ],
        axis: 2
      )

    batch = Gyx.Nx.Pixels.to_batch(frame, {2, 3, 1})
    assert Nx.shape(batch) == {1, 2, 3, 1}
    assert Nx.type(batch) == {:f, 32}
    assert_in_delta Nx.to_number(batch[[0, 0, 0, 0]]), 0.299, 1.0e-5
  end
end
