defmodule Gyx.Trainers.ActorCriticTest do
  use ExUnit.Case, async: false

  alias Gyx.Agents.ActorCritic
  alias Gyx.Trainers.Episodic

  test "A2C samples a valid CartPole action" do
    agent = ActorCritic.new(obs_dim: 4, n_actions: 2, hidden: 8, seed: 1)
    assert ActorCritic.act(agent, {0.0, 0.0, 0.0, 0.0}, [0, 1]) in [0, 1]
  end

  test "finish_episode updates Axon parameters" do
    agent = ActorCritic.new(algo: :a2c, obs_dim: 4, n_actions: 2, hidden: 8, lr: 1.0e-2)
    before = param_sum(agent)

    %{agent: agent} =
      Episodic.train("CartPole-v1", agent, episodes: 2, seed: 1, max_steps: 20)

    refute param_sum(agent) == before
  end

  test "PPO finish_episode updates Axon parameters" do
    agent =
      ActorCritic.new(algo: :ppo, obs_dim: 4, n_actions: 2, hidden: 8, lr: 1.0e-2, epochs: 2)

    before = param_sum(agent)

    %{agent: agent} =
      Episodic.train("CartPole-v1", agent, episodes: 2, seed: 1, max_steps: 20)

    refute param_sum(agent) == before
  end

  @tag timeout: 180_000
  test "A2C improves CartPole-v1 over a random start" do
    :rand.seed(:exsss, {1, 2, 3})
    {agent, opts} = Gyx.Trainers.Presets.a2c("CartPole-v1")
    %{agent: agent} = Episodic.train("CartPole-v1", agent, Keyword.put(opts, :episodes, 250))

    avg = Episodic.evaluate("CartPole-v1", agent, episodes: 10, seed: 9_000, max_steps: 500)
    assert avg >= 30.0
  end

  defp param_sum(%{params: %Axon.ModelState{data: data}}), do: tree_sum(data)

  defp tree_sum(%Nx.Tensor{} = t), do: Nx.to_number(Nx.sum(t))

  defp tree_sum(map) when is_map(map),
    do: map |> Map.values() |> Enum.map(&tree_sum/1) |> Enum.sum()
end
