defmodule Gyx.Session do
  @moduledoc """
  An interactive environment handle.

  The Mix CLI and the optional `ui/` app both drive envs through this
  module instead of calling `Gyx.make/2` / `step/2` ad hoc.
  """

  defstruct id: nil,
            env: nil,
            obs: nil,
            info: %{},
            return: 0.0,
            terminated: false,
            truncated: false,
            last_exp: nil

  @type t :: %__MODULE__{
          id: String.t(),
          env: Gyx.env(),
          obs: term(),
          info: map(),
          return: float(),
          terminated: boolean(),
          truncated: boolean(),
          last_exp: Gyx.Core.Exp.t() | nil
        }

  @spec start(Gyx.id(), keyword()) :: {:ok, t()} | {:error, term()}
  def start(id, opts \\ []) do
    id = to_string(id)
    {seed, opts} = Keyword.pop(opts, :seed)
    reset_opts = if seed == nil, do: [], else: [seed: seed]

    case Gyx.make(id, opts) do
      {:ok, env} ->
        {:ok, reset(%__MODULE__{id: id, env: env, return: 0.0}, reset_opts)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec reset(t(), keyword()) :: t()
  def reset(%__MODULE__{} = session, opts \\ []) do
    {env, obs, info} = Gyx.reset(session.env, opts)

    %{
      session
      | env: env,
        obs: obs,
        info: info,
        return: 0.0,
        terminated: false,
        truncated: false,
        last_exp: nil
    }
  end

  @spec step(t(), term()) :: {:ok, t()} | {:error, :invalid_action}
  def step(%__MODULE__{} = session, action) do
    case Gyx.step(session.env, action) do
      {:ok, env, exp} ->
        {:ok,
         %{
           session
           | env: env,
             obs: exp.next_observation,
             last_exp: exp,
             return: session.return + exp.reward,
             terminated: exp.terminated,
             truncated: exp.truncated
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec render(t(), atom()) :: {:ok, term()} | {:error, term()}
  def render(%__MODULE__{} = session, mode \\ :svg), do: Gyx.render(session.env, mode)

  @spec spec(t()) :: map()
  def spec(%__MODULE__{env: env}), do: Gyx.spec(env)

  @spec params(t()) :: [Gyx.Env.param()]
  def params(%__MODULE__{env: env}), do: Gyx.params(env)

  @spec configure(t(), keyword()) :: t()
  def configure(%__MODULE__{} = session, opts) when is_list(opts) do
    %{session | env: Gyx.configure(session.env, opts)}
  end

  @spec done?(t()) :: boolean()
  def done?(%__MODULE__{terminated: terminated, truncated: truncated}),
    do: terminated or truncated
end
