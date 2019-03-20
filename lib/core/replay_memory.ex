defmodule ReplayMemory do
  @type experience :: Gyx.Core.Exp.t()

  @callback add(experience()) :: any()

  @callback get_random_batch(integer()) :: list(experience())

  defmacro __using__(_params) do
    quote do
      @behaviour Gyx.Core.ReplayMemory

      @enforce_keys [:replay_capacity]
    end
  end
end
