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
      worker(Gyx.Blackjack.Game, [[], [name: Gyx.Blackjack.Game]]),
      worker(Gyx.FrozenLake.Environment, [[], [name: Gyx.FrozenLake.Environment]]),
      worker(Gyx.Blackjack.IAgent, [[], [name: Gyx.Blackjack.IAgent]]),
      worker(Gyx.Qstorage.QGenServer, [[], [name: Gyx.Qstorage.QGenServer]]),
      worker(Gyx.Gym.Environment, [[], [name: Gyx.Gym.Environment]]),
      worker(Gyx.Agents.SARSA.Agent, [[], [name: Gyx.Agents.SARSA.Agent]]),
      worker(Gyx.Trainers.TrainerSarsa, [[], [name: Gyx.Trainers.TrainerSarsa]])
    ]
  end
end
