defmodule Gyx.FrozenLake.Game do
  alias Gyx.Framework.Env
  @behaviour Env
  use GenServer
  alias Experience.Exp

  defstruct map: nil, x: nil, y: nil
  @type t :: %__MODULE__{map: string, x: integer, y: integer}

  @actions = %{0 => :left, 1 => :down, 2 => :right, 3 => :up}
  @action_space = Map.keys(@actions)

  @maps = %{
    "4x4" => [
      "SFFF",
      "FHFH",
      "FFFH",
      "HFFG"
    ],
    "8x8" => [
      "SFFFFFFF",
      "FFFFFFFF",
      "FFFHFFFF",
      "FFFFFHFF",
      "FFFHFFFF",
      "FHHFFFHF",
      "FHFFHFHF",
      "FFFHFFFG"
    ]
  }
end
