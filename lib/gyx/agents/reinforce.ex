defmodule Gyx.Agents.Reinforce do
  @moduledoc """
  Episodic REINFORCE with a linear softmax policy.

  Features are the observation numbers plus a bias, unless `encode` is
  set (use `Gyx.Encode.one_hot/1` for discrete grids).
  """

  alias Gyx.Core.{Exp, Spaces}

  defstruct weights: %{},
            lr: 0.02,
            gamma: 0.99,
            baseline: true,
            encode: nil,
            deterministic: false,
            trajectory: []

  @type t :: %__MODULE__{
          weights: %{optional({term(), non_neg_integer()}) => float()},
          lr: float(),
          gamma: float(),
          baseline: boolean(),
          encode: nil | (term() -> term()),
          deterministic: boolean(),
          trajectory: [map()]
        }

  def new(opts \\ []) do
    struct!(
      __MODULE__,
      Keyword.take(opts, [:weights, :lr, :gamma, :baseline, :encode, :deterministic, :trajectory])
    )
  end

  @spec act(t(), term(), Spaces.space() | [term()]) :: term()
  def act(agent, observation, %Spaces.Discrete{n: n}),
    do: act(agent, observation, Enum.to_list(0..(n - 1)))

  def act(%__MODULE__{} = agent, observation, actions) when is_list(actions) do
    x = features(agent, observation)
    probs = softmax_probs(agent.weights, x, actions)

    if agent.deterministic do
      {action, _} = Enum.max_by(probs, fn {_action, p} -> p end)
      action
    else
      sample(probs)
    end
  end

  @spec learn(t(), Exp.t(), [term()]) :: t()
  def learn(%__MODULE__{} = agent, %Exp{} = exp, actions) do
    x = features(agent, exp.observation)
    probs = Map.new(softmax_probs(agent.weights, x, actions))

    step = %{
      x: x,
      action: exp.action,
      reward: exp.reward,
      actions: actions,
      probs: probs
    }

    %{agent | trajectory: [step | agent.trajectory]}
  end

  def finish_episode(%__MODULE__{trajectory: []} = agent), do: agent

  def finish_episode(%__MODULE__{} = agent) do
    steps = Enum.reverse(agent.trajectory)
    returns = discounted_returns(Enum.map(steps, & &1.reward), agent.gamma)
    baseline = if agent.baseline, do: mean(returns), else: 0.0

    weights =
      Enum.zip(steps, returns)
      |> Enum.reduce(agent.weights, fn {step, g}, weights ->
        advantage = g - baseline
        update_weights(weights, step, advantage, agent.lr)
      end)

    %{agent | weights: weights, trajectory: []}
  end

  def eval(%__MODULE__{} = agent), do: %{agent | deterministic: true, trajectory: []}

  defp softmax_probs(weights, x, actions) do
    logits = Enum.map(actions, fn action -> {action, logit(weights, action, x)} end)
    softmax(logits)
  end

  defp update_weights(
         weights,
         %{x: x, action: action, actions: actions, probs: probs},
         advantage,
         lr
       ) do
    Enum.reduce(actions, weights, fn action_i, weights ->
      indicator = if action_i == action, do: 1.0, else: 0.0
      grad = indicator - Map.get(probs, action_i, 0.0)

      x
      |> Enum.with_index()
      |> Enum.reduce(weights, fn {xi, i}, weights ->
        key = {action_i, i}
        Map.put(weights, key, Map.get(weights, key, 0.0) + lr * advantage * grad * xi)
      end)
    end)
  end

  defp logit(weights, action, x) do
    x
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {xi, i}, acc -> acc + Map.get(weights, {action, i}, 0.0) * xi end)
  end

  defp softmax(logits) do
    max_z = logits |> Enum.map(&elem(&1, 1)) |> Enum.max()
    exps = Enum.map(logits, fn {action, z} -> {action, :math.exp(z - max_z)} end)
    z = Enum.reduce(exps, 0.0, fn {_action, e}, acc -> acc + e end)
    Enum.map(exps, fn {action, e} -> {action, e / z} end)
  end

  defp sample(probs) do
    u = :rand.uniform()
    {fallback, _} = List.last(probs)

    Enum.reduce_while(probs, {0.0, fallback}, fn {action, p}, {acc, _last} ->
      acc = acc + p
      if u <= acc, do: {:halt, action}, else: {:cont, {acc, action}}
    end)
    |> case do
      {_, action} -> action
      action -> action
    end
  end

  defp discounted_returns(rewards, gamma) do
    rewards
    |> Enum.reverse()
    |> Enum.reduce({[], 0.0}, fn r, {acc, g} ->
      g = r + gamma * g
      {[g | acc], g}
    end)
    |> elem(0)
  end

  defp mean([]), do: 0.0
  defp mean(xs), do: Enum.sum(xs) / length(xs)

  defp features(%{encode: fun}, obs) when is_function(fun, 1) do
    obs |> fun.() |> to_floats()
  end

  defp features(_agent, obs), do: [1.0 | to_floats(obs)]

  defp to_floats(obs) when is_tuple(obs), do: obs |> Tuple.to_list() |> Enum.map(&(&1 * 1.0))
  defp to_floats(obs) when is_list(obs), do: Enum.map(obs, &(&1 * 1.0))
  defp to_floats(obs) when is_number(obs), do: [obs * 1.0]
  defp to_floats(obs), do: [obs]
end

defimpl Gyx.Agent, for: Gyx.Agents.Reinforce do
  def act(agent, observation, actions), do: Gyx.Agents.Reinforce.act(agent, observation, actions)
  def learn(agent, exp, actions), do: Gyx.Agents.Reinforce.learn(agent, exp, actions)
  def finish_episode(agent), do: Gyx.Agents.Reinforce.finish_episode(agent)
  def eval(agent), do: Gyx.Agents.Reinforce.eval(agent)
end
