defmodule Gyx.Core.Spaces.Discrete do
  @moduledoc  """
  This space represents a set of `n` discrete options.
  Thus, this space is represented by the number `n` of
  available enumerable options.
  Such options are assumed to be {0,1,...,n-1}.
  """

  defstruct n: nil, seed: {1,2,3}, random_algorithm: :exsplus

  @type t :: %__MODULE__{
          n: integer(),
          random_algorithm: :exrop | :exs1024 | :exs1024s | :exs64 | :exsp | :exsplus,
          seed: {integer(), integer(), integer()}
        }
end
