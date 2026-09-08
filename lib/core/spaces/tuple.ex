defmodule Gyx.Core.Spaces.Tuple do
  @moduledoc """
  Product of simpler spaces. Observations and actions are Elixir tuples.
  """

  defstruct spaces: nil, seed: {1, 2, 3}, random_algorithm: :exsplus

  @type t :: %__MODULE__{
          spaces: [Gyx.Core.Spaces.space()],
          random_algorithm: atom(),
          seed: {integer(), integer(), integer()}
        }
end
