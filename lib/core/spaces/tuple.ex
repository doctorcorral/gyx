defmodule Gyx.Core.Spaces.Tuple do
  @moduledoc  """
  This space allows to glue together `Discrete` and `Box` spaces.
  """
  alias Gyx.Core.Spaces.{Discrete, Box}

  defstruct spaces: nil, seed: {1,2,3}, random_algorithm: :exsplus

  @type space :: Discrete.t() | Box.t()

  @type t :: %__MODULE__{
          spaces: list(space()),
          random_algorithm: :exrop | :exs1024 | :exs1024s | :exs64 | :exsp | :exsplus,
          seed: {integer(), integer(), integer()}
        }
end
