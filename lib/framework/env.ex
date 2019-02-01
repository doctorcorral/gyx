defmodule Gyx.Framework.Env do
  @callback reset() :: any()
  @callback get_state() :: any()
  @callback step(any()) :: any()

  defmacro __using__(_params) do
    quote do
      @behaviour Env
      def get_state(), do: __MODULE__.__struct__
      defoverridable [get_state: 0]
    end
  end

end
