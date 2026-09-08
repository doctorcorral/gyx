defmodule Gyx do
  @moduledoc """
  Native Elixir reinforcement learning.

  Environments follow a Gymnasium-shaped contract:

      {:ok, env} = Gyx.make("CartPole-v1")
      {env, obs, info} = Gyx.reset(env, seed: 0)
      {:ok, env, exp} = Gyx.step(env, 1)
      {:ok, scene} = Gyx.render(env, :scene)

  `exp` is a `Gyx.Core.Exp` with `next_observation`, `reward`,
  `terminated`, `truncated`, and `info`.

  Interactive loops use `Gyx.Session`. Learning runs use `Gyx.Experiment`
  (`mix gyx.train`, `mix gyx.experiment`). The optional playground is
  the `ui/` app and is not part of this library.
  """

  alias Gyx.{Env, Envs}

  @type env :: Env.t() | pid()
  @type id :: String.t() | atom()

  @doc "Lists registered environment ids."
  @spec envs() :: [String.t()]
  def envs, do: Envs.ids()

  @doc """
  Builds a new environment.

  Pass `server: true` to wrap it in a `Gyx.Env.Server` process.
  """
  @spec make(id(), keyword()) :: {:ok, env()} | {:error, {:unknown_env, term()}}
  def make(id, opts \\ []) do
    {server?, opts} = Keyword.pop(opts, :server, false)

    case Envs.fetch(id) do
      {:ok, mod} ->
        env = mod.new(opts)
        if server?, do: Env.Server.start_link(env, opts), else: {:ok, env}

      :error ->
        {:error, {:unknown_env, id}}
    end
  end

  @spec reset(env(), keyword()) :: {env(), term(), map()}
  def reset(env, opts \\ [])
  def reset(%mod{} = env, opts), do: mod.reset(env, opts)
  def reset(pid, opts) when is_pid(pid), do: Env.Server.reset(pid, opts)

  @spec step(env(), term()) :: {:ok, env(), Gyx.Core.Exp.t()} | {:error, :invalid_action}
  def step(%mod{} = env, action), do: mod.step(env, action)
  def step(pid, action) when is_pid(pid), do: Env.Server.step(pid, action)

  @spec observe(env()) :: term()
  def observe(%mod{} = env), do: mod.observe(env)
  def observe(pid) when is_pid(pid), do: Env.Server.observe(pid)

  @spec render(env(), atom()) :: {:ok, term()} | {:error, term()}
  def render(env, mode \\ :svg)
  def render(%mod{} = env, mode), do: mod.render(env, mode)
  def render(pid, mode) when is_pid(pid), do: Env.Server.render(pid, mode)

  @spec spec(env() | id()) :: map()
  def spec(%mod{}), do: mod.spec()
  def spec(id) when is_binary(id) or is_atom(id), do: Envs.fetch!(id).spec()

  @spec params(env()) :: [Env.param()]
  def params(%mod{} = env), do: mod.params(env)

  @spec configure(env(), keyword()) :: env()
  def configure(%mod{} = env, opts) when is_list(opts), do: mod.configure(env, opts)
end
