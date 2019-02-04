defmodule Gyx.Framework.Env do
  @moduledoc """
  This behaviour is intended to be followed for any `Environment` implementation
  The most critical function to be exposed is `step/1` , which serves as a direct bridge
  between the environment and any agent.

  Here, an important design question to address is the fundamental difference between
  the environment state (its internal representation) and an _observation_ of such state.

  In principle, the environment returns an observation as part of step/1 response.

  Should it be a way to obtain an evironment state abstraction as suposed to be shown
  to an agent? i.e. an indirect observation.
  """
  @callback reset() :: any()
  @callback get_state() :: any()
  @callback step(any()) :: Gyx.Experience.Exp.t()

  defmacro __using__(_params) do
    quote do
      @behaviour Gyx.Framework.Env
      def get_state(), do: __MODULE__.__struct__
      defoverridable [get_state: 0]
    end
  end

end
