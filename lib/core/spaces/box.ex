defmodule Gyx.Core.Spaces.Box do

  defstruct low: 0.0, high: 1.0, shape: {1,}, seed: {1,2,3}

  @type t :: %__MODULE__{
          low: float(),
          high: float(),
          shape: tuple(),
          seed: {integer(), integer(), integer()}
        }
end
