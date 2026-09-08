defmodule Gyx.Env do
  @moduledoc """
  Functional environment behaviour.

  Implementations are structs. `Gyx.Env.Server` wraps one in a process
  when you want a named, shareable env (LiveView, distributed actors).
  """

  alias Gyx.Core.{Exp, Spaces}

  @type t :: struct()
  @type observation :: term()
  @type action :: term()
  @type info :: map()

  @type spec :: %{
          required(:id) => String.t(),
          required(:observation_space) => Spaces.space(),
          required(:action_space) => Spaces.space(),
          optional(:max_episode_steps) => pos_integer() | nil,
          optional(:reward_threshold) => number() | nil
        }

  @callback spec() :: spec()
  @callback new(keyword()) :: t()
  @callback reset(t(), keyword()) :: {t(), observation(), info()}
  @callback step(t(), action()) :: {:ok, t(), Exp.t()} | {:error, :invalid_action}
  @callback observe(t()) :: observation()
  @callback render(t(), atom()) :: {:ok, term()} | {:error, term()}
  @callback params(t()) :: [param()]
  @callback configure(t(), keyword()) :: t()

  @type param :: %{
          required(:key) => atom(),
          required(:type) => :boolean | :choice,
          required(:value) => term(),
          optional(:choices) => [term()]
        }

  @optional_callbacks render: 2, params: 1, configure: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Gyx.Env

      @impl Gyx.Env
      def render(_env, _mode), do: {:error, :unsupported_render_mode}

      @impl Gyx.Env
      def params(_env), do: []

      @impl Gyx.Env
      def configure(env, _opts), do: env

      defoverridable render: 2, params: 1, configure: 2
    end
  end
end
