defmodule Gyx.Agents.ActorCritic do
  @moduledoc """
  Discrete-action actor-critic.

  Vector observations use an Axon MLP. Pixel observations (`vision:
  {h, w, c}`) use a small conv net. One shared trunk, a softmax policy
  head, and a scalar value head. `algo: :a2c` does a single on-policy
  update per episode. `algo: :ppo` reuses the episode for several
  clipped epochs.
  """

  alias Gyx.Agents.ActorCritic.Train
  alias Gyx.Core.{Exp, Spaces}
  alias Gyx.Nx.{Features, Pixels}

  defstruct model: nil,
            predict: nil,
            predict_defn: nil,
            params: nil,
            opt_state: nil,
            update_fn: nil,
            algo: :a2c,
            obs_dim: nil,
            vision: nil,
            n_actions: nil,
            encode: nil,
            gamma: 0.99,
            gae_lambda: 0.95,
            entropy_coef: 0.01,
            vf_coef: 0.5,
            clip: 0.2,
            epochs: 4,
            deterministic: false,
            trajectory: []

  @type t :: %__MODULE__{}

  def new(opts) do
    n_actions = Keyword.fetch!(opts, :n_actions)
    hidden = Keyword.get(opts, :hidden, 64)
    lr = Keyword.get(opts, :lr, 3.0e-3)
    vision = Keyword.get(opts, :vision)
    {model, template, obs_dim} = backbone(opts, vision, n_actions, hidden)
    {init_fn, predict} = Axon.build(model)
    {_init, predict_defn} = Axon.Compiler.build(model, [])
    params = init_fn.(template, Axon.ModelState.empty())
    {opt_init, opt_update} = Polaris.Optimizers.adam(learning_rate: lr)
    opt_state = opt_init.(params)

    struct!(
      __MODULE__,
      Keyword.merge(
        [
          model: model,
          predict: predict,
          predict_defn: predict_defn,
          params: params,
          opt_state: opt_state,
          update_fn: opt_update,
          obs_dim: obs_dim,
          vision: vision,
          n_actions: n_actions
        ],
        Keyword.take(opts, [
          :algo,
          :encode,
          :gamma,
          :gae_lambda,
          :entropy_coef,
          :vf_coef,
          :clip,
          :epochs,
          :deterministic
        ])
      )
    )
  end

  defp backbone(_opts, {h, w, c}, n_actions, hidden) do
    {
      cnn({h, w, c}, n_actions, hidden),
      %{"obs" => Nx.template({1, h, w, c}, :f32)},
      h * w * c
    }
  end

  defp backbone(opts, _vision, n_actions, hidden) do
    obs_dim = Keyword.fetch!(opts, :obs_dim)

    {
      mlp(obs_dim, n_actions, hidden),
      %{"obs" => Nx.template({1, obs_dim}, :f32)},
      obs_dim
    }
  end

  @spec act(t(), term(), Spaces.space() | [term()]) :: term()
  def act(agent, observation, %Spaces.Discrete{n: n}),
    do: act(agent, observation, Enum.to_list(0..(n - 1)))

  def act(%__MODULE__{} = agent, observation, actions) when is_list(actions) do
    obs = features(agent, observation)
    %{logits: logits} = agent.predict.(agent.params, %{"obs" => obs})
    idx = select_index(logits, agent.deterministic)
    Enum.at(actions, idx)
  end

  @spec learn(t(), Exp.t(), [term()]) :: t()
  def learn(%__MODULE__{} = agent, %Exp{} = exp, actions) do
    obs = features(agent, exp.observation)
    next = features(agent, exp.next_observation)
    %{logits: logits, value: value} = agent.predict.(agent.params, %{"obs" => obs})
    idx = action_index(exp.action, actions)
    logprob = log_prob_at(logits, idx)

    step = %{
      obs: obs,
      next_obs: next,
      action: idx,
      reward: exp.reward * 1.0,
      terminated: exp.terminated,
      logprob: logprob,
      value: Nx.to_number(Nx.reshape(value, {}))
    }

    %{agent | trajectory: [step | agent.trajectory]}
  end

  def finish_episode(%__MODULE__{trajectory: []} = agent), do: agent

  def finish_episode(%__MODULE__{} = agent) do
    steps = Enum.reverse(agent.trajectory)
    {advantages, returns} = gae(steps, agent)
    agent = update(agent, steps, advantages, returns)
    %{agent | trajectory: []}
  end

  def eval(%__MODULE__{} = agent), do: %{agent | deterministic: true, trajectory: []}

  defp update(%{algo: :ppo} = agent, steps, advantages, returns) do
    batch = batch(agent, steps, advantages, returns)

    Enum.reduce(1..agent.epochs, agent, fn _, agent ->
      {params, opt_state, _loss} =
        Train.ppo_step(
          agent.params,
          agent.opt_state,
          agent.predict_defn,
          agent.update_fn,
          batch.obs,
          batch.actions,
          batch.advantages,
          batch.returns,
          batch.logprobs,
          %{clip: agent.clip, entropy_coef: agent.entropy_coef, vf_coef: agent.vf_coef}
        )

      %{agent | params: params, opt_state: opt_state}
    end)
  end

  defp update(agent, steps, advantages, returns) do
    batch = batch(agent, steps, advantages, returns)

    {params, opt_state, _loss} =
      Train.a2c_step(
        agent.params,
        agent.opt_state,
        agent.predict_defn,
        agent.update_fn,
        batch.obs,
        batch.actions,
        batch.advantages,
        batch.returns,
        %{entropy_coef: agent.entropy_coef, vf_coef: agent.vf_coef}
      )

    %{agent | params: params, opt_state: opt_state}
  end

  defp batch(_agent, steps, advantages, returns) do
    %{
      obs: steps |> Enum.map(& &1.obs) |> Nx.concatenate(axis: 0),
      actions: Nx.tensor(Enum.map(steps, & &1.action), type: :s64),
      advantages: Nx.tensor(advantages, type: :f32),
      returns: Nx.tensor(returns, type: :f32),
      logprobs: Nx.tensor(Enum.map(steps, & &1.logprob), type: :f32)
    }
  end

  defp gae(steps, agent) do
    last = List.last(steps)

    bootstrap =
      if last.terminated do
        0.0
      else
        %{value: v} = agent.predict.(agent.params, %{"obs" => last.next_obs})
        Nx.to_number(Nx.reshape(v, {}))
      end

    {adv, _} =
      steps
      |> Enum.reverse()
      |> Enum.reduce({[], bootstrap}, fn step, {acc, next_value} ->
        delta = step.reward + agent.gamma * next_value * done_mask(step) - step.value
        a = delta + agent.gamma * agent.gae_lambda * done_mask(step) * hd_or(acc, 0.0)
        {[a | acc], step.value}
      end)

    returns = Enum.zip_with(adv, steps, fn a, step -> a + step.value end)
    {normalize(adv), returns}
  end

  defp done_mask(%{terminated: true}), do: 0.0
  defp done_mask(_), do: 1.0

  defp hd_or([], default), do: default
  defp hd_or([h | _], _), do: h

  defp normalize(xs) do
    n = length(xs)
    mean = Enum.sum(xs) / n
    var = Enum.reduce(xs, 0.0, fn x, acc -> acc + (x - mean) * (x - mean) end) / n
    std = :math.sqrt(var + 1.0e-8)
    Enum.map(xs, fn x -> (x - mean) / std end)
  end

  defp mlp(obs_dim, n_actions, hidden) do
    obs = Axon.input("obs", shape: {nil, obs_dim})
    shared = obs |> Axon.dense(hidden) |> Axon.tanh() |> Axon.dense(hidden) |> Axon.tanh()
    Axon.container(%{logits: Axon.dense(shared, n_actions), value: Axon.dense(shared, 1)})
  end

  defp cnn({h, w, c}, n_actions, hidden) do
    obs = Axon.input("obs", shape: {nil, h, w, c})

    shared =
      obs
      |> Axon.conv(16, kernel_size: 8, strides: 4, activation: :relu)
      |> Axon.conv(32, kernel_size: 4, strides: 2, activation: :relu)
      |> Axon.flatten()
      |> Axon.dense(hidden, activation: :relu)

    Axon.container(%{logits: Axon.dense(shared, n_actions), value: Axon.dense(shared, 1)})
  end

  defp features(%{vision: {h, w, c}}, obs), do: Pixels.to_batch(obs, {h, w, c})

  defp features(%{encode: encode, obs_dim: obs_dim}, obs) do
    Features.to_tensor(obs, encode: encode, obs_dim: obs_dim)
  end

  defp select_index(logits, true) do
    logits |> Nx.reshape({:auto}) |> Nx.argmax() |> Nx.to_number()
  end

  defp select_index(logits, false) do
    xs = logits |> Nx.reshape({:auto}) |> Nx.to_flat_list()
    m = Enum.max(xs)
    exps = Enum.map(xs, fn x -> :math.exp(x - m) end)
    z = Enum.sum(exps)
    sample(Enum.map(exps, fn e -> e / z end))
  end

  defp sample(probs) do
    u = :rand.uniform()
    fallback = length(probs) - 1

    Enum.reduce_while(Enum.with_index(probs), {0.0, fallback}, fn {p, i}, {acc, _last} ->
      acc = acc + p
      if u <= acc, do: {:halt, i}, else: {:cont, {acc, i}}
    end)
    |> case do
      {_, i} -> i
      i -> i
    end
  end

  defp action_index(action, actions) do
    case Enum.find_index(actions, &(&1 == action)) do
      nil ->
        # Pendulum stores the decoded torque on the experience.
        Enum.find_index(actions, &close?(&1, action)) || 0

      idx ->
        idx
    end
  end

  defp close?(a, b) when is_number(a) and is_number(b), do: abs(a - b) < 1.0e-6
  defp close?(_, _), do: false

  defp log_prob_at(logits, idx) do
    log_probs = log_softmax_list(logits)
    Enum.at(log_probs, idx)
  end

  defp log_softmax_list(logits) do
    xs = logits |> Nx.reshape({:auto}) |> Nx.to_flat_list()
    m = Enum.max(xs)
    exps = Enum.map(xs, fn x -> :math.exp(x - m) end)
    z = :math.log(Enum.sum(exps))
    Enum.map(xs, fn x -> x - m - z end)
  end
end

defimpl Gyx.Agent, for: Gyx.Agents.ActorCritic do
  def act(agent, observation, actions),
    do: Gyx.Agents.ActorCritic.act(agent, observation, actions)

  def learn(agent, exp, actions), do: Gyx.Agents.ActorCritic.learn(agent, exp, actions)
  def finish_episode(agent), do: Gyx.Agents.ActorCritic.finish_episode(agent)
  def eval(agent), do: Gyx.Agents.ActorCritic.eval(agent)
end
