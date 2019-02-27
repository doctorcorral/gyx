defmodule Gyx.Core.Spaces.Discrete do

  defstruct n: nil, seed: {1,2,3}

  @type t :: %__MODULE__{
          n: integer(),
          seed: {integer(), integer(), integer()}
        }
end
