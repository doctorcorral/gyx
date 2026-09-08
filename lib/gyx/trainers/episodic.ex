defmodule Gyx.Trainers.Episodic do
  @moduledoc """
  Generic episodic trainer for agents that implement `Gyx.Agent`.
  """

  alias Gyx.Agent
  alias Gyx.Core.{Exp, Spaces}

  @spec train(module() | String.t(), struct(), keyword()) :: %{
          agent: struct(),
          returns: [float()],
          episodes: non_neg_integer()
        }
  def train(env_mod_or_id, agent, opts \\ []) do
    env_mod = resolve(env_mod_or_id)
    episodes = Keyword.get(opts, :episodes, 500)
    max_steps = Keyword.get(opts, :max_steps, 200)
    seed = Keyword.get(opts, :seed)
    env_opts = Keyword.get(opts, :env, [])

    env = env_mod.new(env_opts)
    actions = actions_for(env, opts)
    reward = Keyword.get(opts, :reward)
    on_progress = Keyword.get(opts, :on_progress)

    {_, agent, returns} =
      Enum.reduce(1..episodes, {env, agent, []}, fn episode, {env, agent, returns} ->
        reset_opts = if seed, do: [seed: seed + episode], else: []
        {env, _obs, _info} = env_mod.reset(env, reset_opts)

        {env, agent, ret, _obs} =
          run_episode(env_mod, env, agent, actions, 0.0, max_steps, reward, true)

        agent = Agent.finish_episode(agent)
        returns = [ret | returns]
        report_progress(on_progress, episode, episodes, ret, returns)
        {env, agent, returns}
      end)

    %{agent: agent, returns: Enum.reverse(returns), episodes: episodes}
  end

  @spec evaluate(module() | String.t(), struct(), keyword()) :: float()
  def evaluate(env_mod_or_id, agent, opts \\ []) do
    env_mod = resolve(env_mod_or_id)
    episodes = Keyword.get(opts, :episodes, 20)
    env = env_mod.new(Keyword.get(opts, :env, []))
    actions = actions_for(env, opts)
    greedy = Agent.eval(agent)

    1..episodes
    |> Enum.map(fn i ->
      {env, _obs, _} = env_mod.reset(env, seed: Keyword.get(opts, :seed, 10_000) + i)

      {_env, agent, ret, _} =
        run_episode(
          env_mod,
          env,
          greedy,
          actions,
          0.0,
          Keyword.get(opts, :max_steps, 200),
          nil,
          false
        )

      _ = Agent.finish_episode(agent)
      ret
    end)
    |> then(fn xs -> Enum.sum(xs) / length(xs) end)
  end

  defp run_episode(_mod, env, agent, _actions, ret, 0, _reward, _learn?),
    do: {env, agent, ret, env}

  defp run_episode(mod, env, agent, actions, ret, left, reward, learn?) do
    action = Agent.act(agent, mod.observe(env), actions)

    case mod.step(env, action) do
      {:ok, env, %Exp{} = exp} ->
        agent = if learn?, do: Agent.learn(agent, shaped(exp, reward), actions), else: agent
        ret = ret + exp.reward

        if Exp.done?(exp) do
          {env, agent, ret, exp.next_observation}
        else
          run_episode(mod, env, agent, actions, ret, left - 1, reward, learn?)
        end

      {:error, _} ->
        {env, agent, ret, mod.observe(env)}
    end
  end

  defp report_progress(fun, episode, episodes, ret, returns) when is_function(fun, 1) do
    fun.(%{episode: episode, episodes: episodes, return: ret, returns: returns})
  end

  defp report_progress(_, _, _, _, _), do: :ok

  defp shaped(exp, nil), do: exp
  defp shaped(exp, fun) when is_function(fun, 1), do: %{exp | reward: fun.(exp)}

  defp actions_for(env, opts) do
    Keyword.get_lazy(opts, :actions, fn -> action_list(env.action_space) end)
  end

  defp resolve(mod) when is_atom(mod) do
    Code.ensure_loaded(mod)

    if function_exported?(mod, :new, 1) do
      mod
    else
      Gyx.Envs.fetch!(mod)
    end
  end

  defp resolve(id), do: Gyx.Envs.fetch!(id)

  defp action_list(%Spaces.Discrete{n: n}), do: Enum.to_list(0..(n - 1))

  defp action_list(%Spaces.Box{}),
    do: raise(ArgumentError, "Box action spaces need an explicit :actions list")
end
