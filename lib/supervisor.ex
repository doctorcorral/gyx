defmodule Gyx.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_args) do
    supervise(children(), strategy: :one_for_one)
  end

  defp children do
    [
      worker(Gyx.Environments.Blackjack, [[], [name: Gyx.Environments.Blackjack]]),
      worker(Gyx.Environments.FrozenLake, [[], [name: Gyx.Environments.FrozenLake]]),
      worker(Gyx.Qstorage.QGenServer, [[], [name: Gyx.Qstorage.QGenServer]]),
      worker(Gyx.Gym.Environment, [[], [name: Gyx.Gym.Environment]]),
      worker(Gyx.Agents.SARSA.Agent, [[], [name: Gyx.Agents.SARSA.Agent]]),
      worker(Gyx.Trainers.TrainerSarsa, [[], [name: Gyx.Trainers.TrainerSarsa]]),
      worker(Gyx.Experience.ReplayBuffer, [[], [name: Gyx.Experience.ReplayBuffer]])
    ]
  end
end
