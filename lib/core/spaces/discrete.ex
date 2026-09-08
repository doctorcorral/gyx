defmodule Gyx.Core.Spaces.Discrete do
  @moduledoc """
  A set of `n` options `{0, 1, ..., n-1}`.
  """

  defstruct n: nil, seed: {1, 2, 3}, random_algorithm: :exsplus

  @type t :: %__MODULE__{
          n: pos_integer(),
          random_algorithm: atom(),
          seed: {integer(), integer(), integer()}
        }
end
