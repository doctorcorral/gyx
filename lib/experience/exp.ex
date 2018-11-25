defmodule Experience.Exp do
  defstruct state: nil, action: nil, reward: 0, next_state: nil, done: false, info: %{}
end
