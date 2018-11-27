defmodule Env do
  @callback reset() :: any()
  @callback get_state() :: any()
  @callback step(any()) :: any()
end
