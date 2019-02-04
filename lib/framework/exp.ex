defmodule Gyx.Experience.Exp do
  @moduledoc """
  This is data structure for representing an experience piece.
  This is what is returned to an agent when interacting (calling `step/1`)
  with the environment.

  ### To consider
  Usually, the experience pieces an agent gets from the environment, are
  stored in a *replay buffer*, so the learning method can access to certain
  experiences given a retrieval function.

  These custom sampling techniques are responsability of the replay buffer module.

  Use `info` key to store any additional metadata that could be useful for a
  replay buffer to consider when sampling. For example, a timestamp that could
  guarantee an atomic broadcasted replay buffer.
  """
  defstruct state: nil, action: nil, reward: 0, next_state: nil, done: false, info: %{}

  @type t :: %__MODULE__{
          state: any(),
          action: number(),
          reward: float(),
          next_state: any(),
          done: boolean(),
          info: map()
        }
end
