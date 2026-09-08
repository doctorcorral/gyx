defmodule Gyx.Trainers.TrainerSarsa do
  @moduledoc """
  This module describes an entire training process,
  tune accordingly to your particular environment and agent
  """
  use GenServer
  alias Gyx.Core.Exp
  require Logger

  @enforce_keys [:environment, :agent]

  defstruct env_name: nil, environment: nil, agent: nil, trajectory: nil, rewards: nil

  @type t :: %__MODULE__{
          env_name: String.t(),
          environment: any(),
          agent: any(),
          trajectory: list(Exp),
          rewards: list(number())
        }

  @env_module Gyx.Environments.Gym
  @q_storage_module Gyx.Qstorage.QGenServer
  @agent_module Gyx.Agents.SARSA.Agent

  def init(env_name) do
    {:ok, environment} = @env_module.start_link([], [])
    {:ok, qgenserver} = @q_storage_module.start_link([], [])
    {:ok, agent} = @agent_module.start_link(qgenserver, [])

    {:ok,
     %__MODULE__{
       env_name: env_name,
       environment: environment,
       agent: agent,
       trajectory: [],
       rewards: []
     }, {:continue, :link_gym_environment}}
  end

  def start_link(envname, opts) do
    GenServer.start_link(__MODULE__, envname, opts)
  end

  def train(trainer, episodes) do
    GenServer.call(trainer, {:train, episodes})
  end

  def handle_call({:train, episodes}, _from, t = %__MODULE__{}) do
    {:reply, trainer(t, episodes), t}
  end

  def handle_continue(
        :link_gym_environment,
        state = %{env_name: env_name, environment: environment}
      ) do
    Gyx.Environments.Gym.make(environment, env_name)

    {:noreply, state}
  end

  @spec trainer(__MODULE__.t(), integer) :: __MODULE__.t()
  defp trainer(t, 0), do: t

  defp trainer(t, num_episodes) do
    Gyx.Environments.Gym.reset(t.environment)

    t
    |> initialize_trajectory()
    # |> IO.inspect(label: "Trajectory initialized")
    |> run_episode(false)
    # |> IO.inspect(label: "Episode finished")
    |> log_stats()
    |> trainer(num_episodes - 1)
  end

  defp run_episode(t = %__MODULE__{}, true), do: t

  defp run_episode(t = %__MODULE__{}, false) do
    next_action =
      @agent_module.act_epsilon_greedy(t.agent, %{
        current_state: observe(t.environment),
        action_space: action_space(t.environment)
      })

    exp =
      %Exp{done: done, state: s, action: a, reward: r, next_state: ss} =
      t.environment
      |> @env_module.step(next_action)

    aa =
      @agent_module.act_epsilon_greedy(t.agent, %{
        current_state: ss,
        action_space: action_space(t.environment)
      })

    @agent_module.td_learn(t.agent, {s, a, r, ss, aa})
    t = %{t | trajectory: [exp | t.trajectory]}
    run_episode(t, done)
  end

  defp initialize_trajectory(t), do: %{t | trajectory: []}

  defp log_stats(t) do
    reward_sum = t.trajectory |> Enum.map(& &1.reward) |> Enum.sum()
    t = %{t | rewards: [reward_sum | t.rewards]}
    k = 100
    Logger.info("Reward: " <> to_string((t.rewards |> Enum.take(k) |> Enum.sum()) / k))
    # Gyx.Qstorage.QGenServer.print_q_matrix()
    t
  end

  defp observe(environment), do: :sys.get_state(environment).current_state

  defp action_space(environment), do: :sys.get_state(environment).action_space
end
