defmodule Gyx.Agents.ActorCritic.Train do
  @moduledoc false
  import Nx.Defn

  defn a2c_step(params, opt_state, predict, update_fn, obs, actions, advantages, returns, opts) do
    {loss, grads} =
      value_and_grad(params, fn params ->
        a2c_loss(params, predict, obs, actions, advantages, returns, opts)
      end)

    {updates, opt_state} = update_fn.(grads, opt_state, params)
    {Polaris.Updates.apply_updates(params, updates), opt_state, loss}
  end

  defn ppo_step(
         params,
         opt_state,
         predict,
         update_fn,
         obs,
         actions,
         advantages,
         returns,
         old_logprob,
         opts
       ) do
    {loss, grads} =
      value_and_grad(params, fn params ->
        ppo_loss(params, predict, obs, actions, advantages, returns, old_logprob, opts)
      end)

    {updates, opt_state} = update_fn.(grads, opt_state, params)
    {Polaris.Updates.apply_updates(params, updates), opt_state, loss}
  end

  defnp a2c_loss(params, predict, obs, actions, advantages, returns, opts) do
    %{logits: logits, value: value} = predict.(params, %{"obs" => obs})
    {log_pi, entropy} = logpi_and_entropy(logits, actions)
    values = Nx.squeeze(value, axes: [-1])

    policy = Nx.negate(Nx.mean(log_pi * advantages))
    value_loss = Nx.mean((values - returns) ** 2)
    entropy_bonus = Nx.mean(entropy)

    policy + opts.vf_coef * value_loss - opts.entropy_coef * entropy_bonus
  end

  defnp ppo_loss(params, predict, obs, actions, advantages, returns, old_logprob, opts) do
    %{logits: logits, value: value} = predict.(params, %{"obs" => obs})
    {log_pi, entropy} = logpi_and_entropy(logits, actions)
    values = Nx.squeeze(value, axes: [-1])

    ratio = Nx.exp(log_pi - old_logprob)
    unclipped = ratio * advantages
    clipped = Nx.clip(ratio, 1.0 - opts.clip, 1.0 + opts.clip) * advantages
    policy = Nx.negate(Nx.mean(Nx.min(unclipped, clipped)))
    value_loss = Nx.mean((values - returns) ** 2)

    policy + opts.vf_coef * value_loss - opts.entropy_coef * Nx.mean(entropy)
  end

  defnp logpi_and_entropy(logits, actions) do
    log_probs = log_softmax(logits)
    n = Nx.axis_size(logits, 1)
    oh = Nx.equal(Nx.reshape(actions, {:auto, 1}), Nx.iota({1, n})) |> Nx.as_type({:f, 32})
    log_pi = Nx.sum(log_probs * oh, axes: [1])
    probs = Nx.exp(log_probs)
    entropy = Nx.negate(Nx.sum(probs * log_probs, axes: [1]))
    {log_pi, entropy}
  end

  defnp log_softmax(logits) do
    max = Nx.reduce_max(logits, axes: [1], keep_axes: true)
    log_z = max + Nx.log(Nx.sum(Nx.exp(logits - max), axes: [1], keep_axes: true))
    logits - log_z
  end
end
