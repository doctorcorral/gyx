defmodule Gyx.Envs.Atari do
  @moduledoc """
  Arcade Learning Environment wrap (`gymnasium/ALE/*` ids).

  Pixel observations are `Box` points as Nx `uint8` tensors. Actions are
  `Discrete`. This is a Port to ALE/Stella — there is no unprefixed or
  `tree/` Atari id, and no native Elixir emulator.

  Requires `python3` with `gymnasium` and `ale-py` (plus the ALE ROMs).
  """

  def entries, do: Gyx.Envs.Gymnasium.atari_entries()
  def ids, do: Gyx.Envs.Gymnasium.atari_ids()
  def registry, do: Gyx.Envs.Gymnasium.atari_registry()
  def available?, do: Gyx.Envs.Gymnasium.atari_available?()
end
