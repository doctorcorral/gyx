defmodule Gyx.Synthex.Scorer do
  @moduledoc """
  A `Synthex.Scoring` function that rolls out native GYX environments.

  Drop-in replacement for `Synthex.Scoring.LocalPython` on envs GYX
  implements (CartPole, MountainCar, …):

      scorer = Gyx.Synthex.Scorer.new("CartPole-v1")
      scorer.(%{"cmd" => "collect_states", "default" => 0, "seeds" => [0, 1]})

  Commands: `collect_states`, `score`.
  """

  alias Gyx.Core.Exp
  alias Gyx.Policy

  @landing %{
    "CartPole-v1" => 475.0,
    "CartPole-v0" => 195.0,
    "MountainCar-v0" => -199.0
  }

  @spec new(String.t() | atom(), keyword()) :: (map() -> {:ok, map()} | {:error, term()})
  def new(env_id, opts \\ []) do
    fn request -> call(env_id, request, opts) end
  end

  @spec call(String.t() | atom(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  def call(env_id, request, opts \\ []) do
    case Map.get(request, "cmd", Map.get(request, :cmd)) do
      "collect_states" -> {:ok, collect_states(env_id, request, opts)}
      "score" -> {:ok, score(env_id, request, opts)}
      other -> {:error, {:unknown_cmd, other}}
    end
  end

  defp collect_states(env_id, request, opts) do
    chain = decode_chain(Map.get(request, "chain", []))
    default = Map.fetch!(request, "default")
    seeds = Map.get(request, "seeds", Enum.to_list(0..9))
    max_steps = Map.get(request, "max_steps", default_horizon(env_id))
    landing = landing_threshold(env_id, opts)

    {states, wins} =
      Enum.reduce(seeds, {[], 0}, fn seed, {states, wins} ->
        {ep_states, ret} = rollout(env_id, chain, default, seed, max_steps, opts)
        {states ++ ep_states, wins + if(ret >= landing, do: 1, else: 0)}
      end)

    %{"states" => states, "n_landings" => wins, "n_episodes" => length(seeds)}
  end

  defp score(env_id, request, opts) do
    candidates = Map.fetch!(request, "candidates")
    stage_action = Map.fetch!(request, "stage_action")
    default = Map.fetch!(request, "default")
    chain_so_far = decode_chain(Map.get(request, "chain_so_far", []))
    chain_after = decode_chain(Map.get(request, "chain_after", []))
    seeds = Map.get(request, "seeds", Enum.to_list(0..9))
    max_steps = Map.get(request, "max_steps", default_horizon(env_id))
    landing = landing_threshold(env_id, opts)

    {baseline_reward, baseline_wins} =
      run_episodes(env_id, chain_so_far ++ chain_after, default, seeds, max_steps, landing, opts)

    scores =
      candidates
      |> Enum.with_index()
      |> Enum.map(fn {candidate, idx} ->
        chain = chain_so_far ++ [{candidate, stage_action}] ++ chain_after
        {reward, wins} = run_episodes(env_id, chain, default, seeds, max_steps, landing, opts)
        %{"idx" => idx, "reward" => reward, "landings" => wins}
      end)

    %{
      "scores" => scores,
      "baseline_reward" => baseline_reward,
      "baseline_landings" => baseline_wins
    }
  end

  defp run_episodes(env_id, chain, default, seeds, max_steps, landing, opts) do
    Enum.reduce(seeds, {0.0, 0}, fn seed, {total, wins} ->
      {_states, ret} = rollout(env_id, chain, default, seed, max_steps, opts)
      {total + ret, wins + if(ret >= landing, do: 1, else: 0)}
    end)
  end

  defp rollout(env_id, chain, default, seed, max_steps, opts) do
    {:ok, env} = Gyx.make(env_id, Keyword.drop(opts, [:landing_threshold]))
    {env, obs, _} = Gyx.reset(env, seed: seed)
    step_loop(env, chain, default, obs, [], 0.0, max_steps)
  end

  defp step_loop(_env, _chain, _default, _obs, states, ret, 0), do: {Enum.reverse(states), ret}

  defp step_loop(env, chain, default, obs, states, ret, left) do
    action = Policy.chain_action(chain, default, obs)

    case Gyx.step(env, action) do
      {:ok, env, %Exp{} = exp} ->
        states = [obs_list(obs) | states]
        ret = ret + exp.reward

        if Exp.done?(exp) do
          {Enum.reverse(states), ret}
        else
          step_loop(env, chain, default, exp.next_observation, states, ret, left - 1)
        end

      {:error, _} ->
        {Enum.reverse(states), ret}
    end
  end

  defp decode_chain(chain) do
    Enum.map(chain, fn
      {pred, action} -> {pred, action}
      [pred, action] -> {pred, action}
      %{"pred" => pred, "action" => action} -> {pred, action}
    end)
  end

  defp obs_list(obs) when is_tuple(obs), do: Tuple.to_list(obs)
  defp obs_list(obs) when is_list(obs), do: obs
  defp obs_list(obs) when is_number(obs), do: [obs]
  defp obs_list(obs), do: [obs]

  defp default_horizon(id) do
    spec = Gyx.spec(id)
    spec[:max_episode_steps] || 200
  end

  defp landing_threshold(id, opts) do
    Keyword.get(opts, :landing_threshold) || Map.get(@landing, to_string(id)) || 0.0
  end
end
