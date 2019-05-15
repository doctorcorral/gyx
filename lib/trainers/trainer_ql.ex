defmodule Gyx.Trainers.TrainerQL do
  @moduledoc """
  This module describes an entire training process,
  tune accordingly to your particular environment and agent
  """
  use GenServer
  alias Gyx.Core.Exp
  require Logger

  @enforce_keys [:environment, :agent]

  defstruct environment: nil, agent: nil, trajectory: nil, rewards: nil, total_reward: nil

  @type t :: %__MODULE__{
          environment: any(),
          agent: any(),
          trajectory: list(Exp),
          rewards: list(number()),
          total_reward: number()
        }

  @env_module Gyx.Gym.Environment
  #@env_module Gyx.Environments.Blackjack
  @agent Gyx.Agents.QL.Agent

  def init(_) do
    {:ok,
     %__MODULE__{
       environment: @env_module,
       agent: @agent,
       trajectory: [],
       rewards: [],
       total_reward: 0
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %__MODULE__{}) do
    {:reply, trainer(t, 10_000), t}
  end

  @spec trainer(__MODULE__.t(), integer) :: __MODULE__.t()
  defp trainer(t, 0), do: t

  defp trainer(t, num_episodes) do
    t.environment.reset()

    t
    |> initialize_trajectory()
    |> run_episode(false)
    |> log_stats()
    |> log_reward()
    |> trainer(num_episodes - 1)
  end

  defp run_episode(t = %__MODULE__{}, true), do: t

  defp run_episode(t = %__MODULE__{}, false) do
    exp =
      %Exp{done: done, state: s, action: a, reward: r, next_state: ss} =
      %{
        observation: t.environment.observe(),
        action_space: t.environment.get_state().action_space
      }
      |> t.agent.act_greedy()
      |> t.environment.step

    aa =
      t.agent.act_greedy(%{
        observation: ss,
        action_space: t.environment.get_state().action_space
      })

    t.agent.td_learn({s, a, r, ss, aa})
    t = %{t | trajectory: [exp | t.trajectory]}
    run_episode(t, done)
  end

  defp initialize_trajectory(t), do: %{t | trajectory: []}

  defp log_stats(t) do
    reward_sum = t.trajectory |> Enum.map(& &1.reward) |> Enum.sum()
    t = %{t | rewards: [reward_sum | t.rewards]}
    k = 100
    Logger.info("Reward: " <> to_string((t.rewards |> Enum.take(k) |> Enum.sum()) / k))
    t
  end

  defp log_reward(t) do
    Logger.info("Total Reward: " <> to_string(t.total_reward))
    t
  end

end
