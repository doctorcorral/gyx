defmodule Gyx.Core.Exp do
  @moduledoc """
  One environment transition, shaped after Gymnasium's `step` return.

  Trainers store these in a replay buffer. Use `info` for metadata
  (legal actions, hands, debug traces, timestamps).
  """

  @enforce_keys [:observation, :action, :next_observation]
  defstruct observation: nil,
            action: nil,
            reward: 0.0,
            next_observation: nil,
            terminated: false,
            truncated: false,
            info: %{}

  @type t :: %__MODULE__{
          observation: term(),
          action: term(),
          reward: float(),
          next_observation: term(),
          terminated: boolean(),
          truncated: boolean(),
          info: map()
        }

  @doc "True when the episode should stop (terminal state or time limit)."
  @spec done?(t()) :: boolean()
  def done?(%__MODULE__{terminated: terminated, truncated: truncated}),
    do: terminated or truncated
end
