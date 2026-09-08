defmodule Gyx.Trainers.Presets do
  @moduledoc false

  alias Gyx.Agents.{ActorCritic, QLearning, Reinforce, Sarsa}
  alias Gyx.Encode
  alias Gyx.Envs.{Mujoco, Pendulum}

  @algorithms [
    {"Q-learning", "q_learning"},
    {"SARSA", "sarsa"},
    {"REINFORCE", "reinforce"},
    {"A2C", "a2c"},
    {"PPO", "ppo"}
  ]

  def algorithms, do: @algorithms

  def trainable?(id), do: match?({_, _}, q_learning(id))

  def available?(algo, id), do: match?({_, _}, build(algo, id))

  def policy_actions(id) do
    case build("a2c", id) || build("reinforce", id) || build("q_learning", id) do
      {_, opts} -> Keyword.get(opts, :actions)
      _ -> nil
    end
  end

  def build(algo, id) do
    case algo do
      "q_learning" -> q_learning(id)
      "sarsa" -> sarsa(id)
      "reinforce" -> reinforce(id)
      "a2c" -> a2c(id)
      "ppo" -> ppo(id)
      _ -> nil
    end
  end

  def q_learning("FrozenLake-v1") do
    {
      QLearning.new(alpha: 0.2, gamma: 0.99, epsilon: 0.2, epsilon_decay: 0.999),
      [episodes: 1500, seed: 1, env: [is_slippery: false]]
    }
  end

  def q_learning("MountainCar-v0") do
    {
      QLearning.new(
        alpha: 0.2,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.9992,
        epsilon_min: 0.05,
        encode: Encode.for_env("MountainCar-v0")
      ),
      [episodes: 4000, seed: 1, max_steps: 200, reward: &mountain_car_reward/1]
    }
  end

  def q_learning("CartPole-v1") do
    {
      QLearning.new(
        alpha: 0.15,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.997,
        epsilon_min: 0.02,
        encode: Encode.for_env("CartPole-v1")
      ),
      [episodes: 2500, seed: 1, max_steps: 500]
    }
  end

  def q_learning("Blackjack-v1") do
    {
      QLearning.new(
        alpha: 0.1,
        gamma: 1.0,
        epsilon: 0.3,
        epsilon_decay: 0.9995,
        epsilon_min: 0.05
      ),
      [episodes: 4000, seed: 1]
    }
  end

  def q_learning("Acrobot-v1") do
    {
      QLearning.new(
        alpha: 0.2,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.999,
        epsilon_min: 0.05,
        encode: Encode.for_env("Acrobot-v1")
      ),
      [episodes: 2000, seed: 1, max_steps: 500]
    }
  end

  def q_learning("Pendulum-v1") do
    {
      QLearning.new(
        alpha: 0.2,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.999,
        epsilon_min: 0.05,
        encode: Encode.for_env("Pendulum-v1")
      ),
      [episodes: 2500, seed: 1, max_steps: 200, actions: Pendulum.discrete_actions()]
    }
  end

  def q_learning("InvertedPendulum-v4") do
    {
      QLearning.new(
        alpha: 0.2,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.997,
        epsilon_min: 0.02,
        encode: Encode.for_env("InvertedPendulum-v4")
      ),
      [episodes: 2000, seed: 1, max_steps: 1000, actions: Gyx.Envs.InvertedPendulum.discrete_actions()]
    }
  end

  def q_learning("InvertedDoublePendulum-v4") do
    {
      QLearning.new(
        alpha: 0.15,
        gamma: 0.99,
        epsilon: 1.0,
        epsilon_decay: 0.997,
        epsilon_min: 0.05,
        encode: Encode.bins([
          {-1.0, 1.0, 4},
          {-1.0, 1.0, 4},
          {-1.0, 1.0, 4},
          {-1.0, 1.0, 4},
          {-1.0, 1.0, 4},
          {-3.0, 3.0, 4},
          {-8.0, 8.0, 4},
          {-8.0, 8.0, 4},
          {-1.0, 1.0, 2},
          {-1.0, 1.0, 2},
          {-1.0, 1.0, 2}
        ])
      ),
      [
        episodes: 1500,
        seed: 1,
        max_steps: 1000,
        actions: Gyx.Envs.InvertedDoublePendulum.discrete_actions()
      ]
    }
  end

  def q_learning(id), do: generic_tabular(id)

  def sarsa(id) do
    case q_learning(id) do
      {agent, opts} -> {to_sarsa(agent), opts}
      nil -> nil
    end
  end

  def reinforce("CartPole-v1") do
    {
      Reinforce.new(lr: 0.02, gamma: 0.99),
      [episodes: 1500, seed: 1, max_steps: 500]
    }
  end

  def reinforce("MountainCar-v0") do
    {
      Reinforce.new(lr: 0.01, gamma: 0.99),
      [episodes: 2000, seed: 1, max_steps: 200, reward: &mountain_car_reward/1]
    }
  end

  def reinforce("FrozenLake-v1") do
    {
      Reinforce.new(lr: 0.2, gamma: 1.0, baseline: false, encode: Encode.one_hot(16)),
      [episodes: 3000, seed: 2, env: [is_slippery: false]]
    }
  end

  def reinforce("Acrobot-v1") do
    {
      Reinforce.new(lr: 0.01, gamma: 0.99),
      [episodes: 1500, seed: 1, max_steps: 500]
    }
  end

  def reinforce("Pendulum-v1") do
    {
      Reinforce.new(lr: 0.01, gamma: 0.99),
      [episodes: 2000, seed: 1, max_steps: 200, actions: Pendulum.discrete_actions()]
    }
  end

  def reinforce("Blackjack-v1") do
    {
      Reinforce.new(lr: 0.05, gamma: 1.0),
      [episodes: 3000, seed: 1]
    }
  end

  def reinforce("InvertedPendulum-v4") do
    {
      Reinforce.new(lr: 0.02, gamma: 0.99),
      [episodes: 1500, seed: 1, max_steps: 1000, actions: Gyx.Envs.InvertedPendulum.discrete_actions()]
    }
  end

  def reinforce("Reacher-v4") do
    {
      Reinforce.new(lr: 0.01, gamma: 0.95),
      [episodes: 800, seed: 1, max_steps: 50, actions: Gyx.Envs.Reacher.discrete_actions()]
    }
  end

  def reinforce("Swimmer-v4") do
    {
      Reinforce.new(lr: 0.01, gamma: 0.99),
      [episodes: 800, seed: 1, max_steps: 200, actions: Gyx.Envs.Swimmer.discrete_actions()]
    }
  end

  def reinforce(id), do: generic_reinforce(id)

  def a2c(id), do: neural(id, :a2c)
  def ppo(id), do: neural(id, :ppo)

  defp neural("CartPole-v1", algo) do
    {actor_critic(algo, obs_dim: 4, n_actions: 2, hidden: 64, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 400), seed: 1, max_steps: 500]}
  end

  defp neural("MountainCar-v0", algo) do
    {actor_critic(algo, obs_dim: 2, n_actions: 3, hidden: 64, lr: 3.0e-3),
     [
       episodes: neural_episodes(algo, 600),
       seed: 1,
       max_steps: 200,
       reward: &mountain_car_reward/1
     ]}
  end

  defp neural("FrozenLake-v1", algo) do
    {actor_critic(algo,
       obs_dim: 16,
       n_actions: 4,
       hidden: 32,
       lr: 5.0e-3,
       encode: Encode.one_hot(16)
     ), [episodes: neural_episodes(algo, 800), seed: 1, env: [is_slippery: false]]}
  end

  defp neural("Acrobot-v1", algo) do
    {actor_critic(algo, obs_dim: 6, n_actions: 3, hidden: 64, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 400), seed: 1, max_steps: 500]}
  end

  defp neural("Pendulum-v1", algo) do
    {actor_critic(algo, obs_dim: 3, n_actions: 3, hidden: 64, lr: 3.0e-3),
     [
       episodes: neural_episodes(algo, 500),
       seed: 1,
       max_steps: 200,
       actions: Pendulum.discrete_actions()
     ]}
  end

  defp neural("Blackjack-v1", algo) do
    {actor_critic(algo, obs_dim: 3, n_actions: 2, hidden: 32, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 800), seed: 1]}
  end

  defp neural("InvertedPendulum-v4", algo) do
    {actor_critic(algo, obs_dim: 4, n_actions: 3, hidden: 64, lr: 3.0e-3),
     [
       episodes: neural_episodes(algo, 400),
       seed: 1,
       max_steps: 1000,
       actions: Gyx.Envs.InvertedPendulum.discrete_actions()
     ]}
  end

  defp neural("InvertedDoublePendulum-v4", algo) do
    {actor_critic(algo, obs_dim: 11, n_actions: 3, hidden: 64, lr: 3.0e-3),
     [
       episodes: neural_episodes(algo, 300),
       seed: 1,
       max_steps: 1000,
       actions: Gyx.Envs.InvertedDoublePendulum.discrete_actions()
     ]}
  end

  defp neural("Reacher-v4", algo) do
    {actor_critic(algo, obs_dim: 11, n_actions: 9, hidden: 64, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 400), seed: 1, max_steps: 50, actions: Gyx.Envs.Reacher.discrete_actions()]}
  end

  defp neural("Swimmer-v4", algo) do
    {actor_critic(algo, obs_dim: 8, n_actions: 9, hidden: 64, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 400), seed: 1, max_steps: 200, actions: Gyx.Envs.Swimmer.discrete_actions()]}
  end

  defp neural("Hopper-v4", algo) do
    {actor_critic(algo, obs_dim: 11, n_actions: 27, hidden: 64, lr: 3.0e-3),
     [episodes: neural_episodes(algo, 250), seed: 1, max_steps: 400, actions: Gyx.Envs.Hopper.discrete_actions()]}
  end

  defp neural("gymnasium/ALE/" <> _ = id, algo) do
    actions = ale_actions!(id)

    {
      actor_critic(algo, vision: {84, 84, 1}, n_actions: length(actions), hidden: 128, lr: 2.5e-4),
      [
        episodes: if(algo == :ppo, do: 20, else: 30),
        seed: 1,
        max_steps: 200,
        actions: actions
      ]
    }
  end

  defp neural("tree/" <> id, algo), do: neural(id, algo)

  defp neural(id, algo), do: generic_neural(id, algo)

  defp actor_critic(algo, opts) do
    ActorCritic.new(
      Keyword.merge(
        [algo: algo, gamma: 0.99, gae_lambda: 0.95, entropy_coef: 0.01, vf_coef: 0.5],
        opts
      )
    )
  end

  defp neural_episodes(:ppo, n), do: max(div(n, 2), 150)
  defp neural_episodes(:a2c, n), do: n

  def eval_opts("FrozenLake-v1"), do: [episodes: 30, env: [is_slippery: false], seed: 9_000]
  def eval_opts("MountainCar-v0"), do: [episodes: 20, seed: 9_000, max_steps: 200]
  def eval_opts("CartPole-v1"), do: [episodes: 20, seed: 9_000, max_steps: 500]
  def eval_opts("Blackjack-v1"), do: [episodes: 40, seed: 9_000]
  def eval_opts("Acrobot-v1"), do: [episodes: 15, seed: 9_000, max_steps: 500]

  def eval_opts("Pendulum-v1"),
    do: [episodes: 15, seed: 9_000, max_steps: 200, actions: Pendulum.discrete_actions()]

  def eval_opts("InvertedPendulum-v4"),
    do: [episodes: 15, seed: 9_000, max_steps: 1000, actions: Gyx.Envs.InvertedPendulum.discrete_actions()]

  def eval_opts("InvertedDoublePendulum-v4"),
    do: [
      episodes: 10,
      seed: 9_000,
      max_steps: 1000,
      actions: Gyx.Envs.InvertedDoublePendulum.discrete_actions()
    ]

  def eval_opts("Reacher-v4"),
    do: [episodes: 15, seed: 9_000, max_steps: 50, actions: Gyx.Envs.Reacher.discrete_actions()]

  def eval_opts("Swimmer-v4"),
    do: [episodes: 10, seed: 9_000, max_steps: 200, actions: Gyx.Envs.Swimmer.discrete_actions()]

  def eval_opts("Hopper-v4"),
    do: [episodes: 8, seed: 9_000, max_steps: 400, actions: Gyx.Envs.Hopper.discrete_actions()]

  def eval_opts("gymnasium/ALE/" <> _ = id),
    do: [episodes: 3, seed: 9_000, max_steps: 200, actions: ale_actions!(id)]

  def eval_opts(id) do
    case box_profile(id) do
      nil ->
        [episodes: 20, seed: 9_000]

      profile ->
        [
          episodes: 8,
          seed: 9_000,
          max_steps: train_horizon(profile),
          actions: profile.actions
        ]
    end
  end

  def algo_label(algo) do
    case Enum.find(@algorithms, fn {_label, id} -> id == algo end) do
      {label, _} -> label
      nil -> algo
    end
  end

  defp to_sarsa(%QLearning{} = agent) do
    Sarsa.new(
      alpha: agent.alpha,
      gamma: agent.gamma,
      epsilon: agent.epsilon,
      epsilon_min: agent.epsilon_min,
      epsilon_decay: agent.epsilon_decay,
      encode: agent.encode
    )
  end

  defp generic_tabular(id) do
    case box_profile(id) do
      %{act_n: 1, obs_dim: n} = profile when n <= 11 ->
        {
          QLearning.new(
            alpha: 0.15,
            gamma: 0.99,
            epsilon: 1.0,
            epsilon_decay: 0.997,
            epsilon_min: 0.05,
            encode: Encode.bins(List.duplicate({-2.0, 2.0, 5}, n))
          ),
          [
            episodes: 800,
            seed: 1,
            max_steps: train_horizon(profile),
            actions: profile.actions
          ]
        }

      _ ->
        nil
    end
  end

  defp generic_reinforce(id) do
    case box_profile(id) do
      nil ->
        nil

      profile ->
        {
          Reinforce.new(lr: 0.01, gamma: 0.99),
          [
            episodes: train_episodes(profile, 200),
            seed: 1,
            max_steps: train_horizon(profile),
            actions: profile.actions
          ]
        }
    end
  end

  defp generic_neural(id, algo) do
    case box_profile(id) do
      nil ->
        nil

      profile ->
        n_actions = length(profile.actions)
        hidden = if profile.obs_dim >= 64, do: 128, else: 64

        {
          actor_critic(algo,
            obs_dim: profile.obs_dim,
            n_actions: n_actions,
            hidden: hidden,
            lr: 3.0e-3
          ),
          [
            episodes: neural_episodes(algo, train_episodes(profile, 200)),
            seed: 1,
            max_steps: train_horizon(profile),
            actions: profile.actions
          ]
        }
    end
  end

  defp ale_actions!("gymnasium/" <> gym_id) do
    case Enum.find(Gyx.Envs.Atari.entries(), fn {id, _, _} -> id == gym_id end) do
      {_, n, _} -> Enum.to_list(0..(n - 1))
      nil -> raise ArgumentError, "unknown Atari id gymnasium/#{gym_id}"
    end
  end

  defp box_profile("tree/" <> id), do: box_profile(id)

  defp box_profile("gymnasium/" <> gym_id) do
    case Enum.find(Gyx.Envs.Gymnasium.entries(), fn {id, _, _, _, _, _} -> id == gym_id end) do
      {_, obs, act, lo, hi, maxs} ->
        %{
          obs_dim: obs,
          act_n: act,
          actions: Mujoco.train_actions(act, lo, hi),
          max_steps: maxs,
          slow?: false
        }

      nil ->
        nil
    end
  end

  defp box_profile("Walker2d-v4") do
    %{obs_dim: 17, act_n: 6, actions: Mujoco.train_actions(6, -1.0, 1.0), max_steps: 1000, slow?: true}
  end

  defp box_profile("HalfCheetah-v4") do
    %{obs_dim: 17, act_n: 6, actions: Mujoco.train_actions(6, -1.0, 1.0), max_steps: 1000, slow?: true}
  end

  defp box_profile("Ant-v4") do
    %{obs_dim: 27, act_n: 8, actions: Mujoco.train_actions(8, -1.0, 1.0), max_steps: 1000, slow?: true}
  end

  defp box_profile(_), do: nil

  defp train_horizon(%{slow?: true}), do: 120
  defp train_horizon(%{max_steps: m}), do: min(m, 400)

  defp train_episodes(%{slow?: true}, _n), do: 40
  defp train_episodes(%{obs_dim: d}, n) when d >= 50, do: max(div(n, 3), 40)
  defp train_episodes(_, n), do: n

  # Potential-based shaping so tabular methods can climb the valley.
  # Evaluation still uses the true -1-per-step Gymnasium reward.
  defp mountain_car_reward(%{observation: {x0, v0}, next_observation: {x, v}, terminated: term}) do
    phi = fn pos, vel -> :math.sin(3 * pos) + 10.0 * abs(vel) end
    shaped = -1.0 + 0.99 * phi.(x, v) - phi.(x0, v0)
    if term, do: shaped + 10.0, else: shaped
  end
end
