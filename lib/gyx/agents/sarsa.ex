defmodule Gyx.Agents.Sarsa do
  @moduledoc """
  Tabular SARSA with ε-greedy action selection.

  The next action chosen for the TD target is reused on the following
  step so the update stays on-policy.
  """

  alias Gyx.Core.{Exp, Spaces}

  defstruct q: %{},
            alpha: 0.1,
            gamma: 0.99,
            epsilon: 0.1,
            epsilon_min: 0.01,
            epsilon_decay: 1.0,
            encode: nil,
            pending: nil

  @type t :: %__MODULE__{
          q: %{optional(term()) => %{optional(term()) => float()}},
          alpha: float(),
          gamma: float(),
          epsilon: float(),
          epsilon_min: float(),
          epsilon_decay: float(),
          encode: nil | (term() -> term()),
          pending: nil | term()
        }

  def new(opts \\ []) do
    struct!(
      __MODULE__,
      Keyword.take(opts, [
        :alpha,
        :gamma,
        :epsilon,
        :epsilon_min,
        :epsilon_decay,
        :q,
        :encode,
        :pending
      ])
    )
  end

  @spec act(t(), term(), Spaces.space() | [term()]) :: term()
  def act(agent, observation, %Spaces.Discrete{n: n}),
    do: act(agent, observation, Enum.to_list(0..(n - 1)))

  def act(%__MODULE__{pending: pending}, _observation, _actions) when pending != nil, do: pending

  def act(%__MODULE__{} = agent, observation, actions) when is_list(actions) do
    pick(agent, encode(agent, observation), actions)
  end

  @spec learn(t(), Exp.t(), [term()]) :: t()
  def learn(%__MODULE__{} = agent, %Exp{} = exp, actions) do
    obs = encode(agent, exp.observation)
    next = encode(agent, exp.next_observation)

    {next_q, pending} =
      if exp.terminated do
        {0.0, nil}
      else
        next_action = pick(agent, next, actions)
        {q_encoded(agent, next, next_action), next_action}
      end

    target = exp.reward + agent.gamma * next_q

    updated =
      q_encoded(agent, obs, exp.action) +
        agent.alpha * (target - q_encoded(agent, obs, exp.action))

    agent
    |> put_q(obs, exp.action, updated)
    |> decay_epsilon()
    |> Map.put(:pending, pending)
  end

  def finish_episode(%__MODULE__{} = agent), do: %{agent | pending: nil}

  def eval(%__MODULE__{} = agent), do: %{agent | epsilon: 0.0, pending: nil}

  @spec q(t(), term(), term()) :: float()
  def q(%__MODULE__{} = agent, observation, action) do
    q_encoded(agent, encode(agent, observation), action)
  end

  defp pick(agent, observation, actions) do
    if :rand.uniform() < agent.epsilon do
      Enum.random(actions)
    else
      greedy_encoded(agent, observation, actions)
    end
  end

  defp greedy_encoded(agent, observation, actions) do
    scored = Enum.map(actions, fn action -> {action, q_encoded(agent, observation, action)} end)
    {_action, best} = Enum.max_by(scored, fn {_action, value} -> value end)

    scored
    |> Enum.filter(fn {_action, value} -> value == best end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.random()
  end

  defp q_encoded(%{q: table}, observation, action) do
    table |> Map.get(observation, %{}) |> Map.get(action, 0.0)
  end

  defp encode(%{encode: nil}, obs), do: obs
  defp encode(%{encode: fun}, obs) when is_function(fun, 1), do: fun.(obs)

  defp put_q(%__MODULE__{q: table} = agent, observation, action, value) do
    row = Map.get(table, observation, %{})
    %{agent | q: Map.put(table, observation, Map.put(row, action, value))}
  end

  defp decay_epsilon(%__MODULE__{} = agent) do
    %{agent | epsilon: max(agent.epsilon_min, agent.epsilon * agent.epsilon_decay)}
  end
end

defimpl Gyx.Agent, for: Gyx.Agents.Sarsa do
  def act(agent, observation, actions), do: Gyx.Agents.Sarsa.act(agent, observation, actions)
  def learn(agent, exp, actions), do: Gyx.Agents.Sarsa.learn(agent, exp, actions)
  def finish_episode(agent), do: Gyx.Agents.Sarsa.finish_episode(agent)
  def eval(agent), do: Gyx.Agents.Sarsa.eval(agent)
end
