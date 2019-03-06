defmodule Gyx.Core.Spaces.Box do
  @moduledoc """
  This space represents a bounded `R^n` space.
  These bounds are `[0.0, 1.0]` by default.
  Such range can be set with `[:low, :high]` keys.
  The shape of such box can be set in `:shape`
  `:random_algorithm` and `:seed` can be used to set a random key
  used for reproducibility in sampling the space.
  """

  defstruct low: 0.0, high: 1.0,
            shape: {1},
            seed: {1, 2, 3}, random_algorithm: :exsplus

  @type t :: %__MODULE__{
          low: float(),
          high: float(),
          shape: tuple(),
          random_algorithm: atom(),
          seed: {integer(), integer(), integer()}
        }
end
