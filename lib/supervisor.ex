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
      worker(Gyx.Qstorage.QGenServer, [[], [name: Gyx.Qstorage.QGenServer]]),
      worker(Gyx.Environments.Gym, [[], [name: Gyx.Environments.Gym]]),
      worker(Gyx.Agents.SARSA.Agent, [[], [name: Gyx.Agents.SARSA.Agent]]),
      worker(Gyx.Trainers.TrainerSarsa, [[], [name: Gyx.Trainers.TrainerSarsa]]),
      worker(Gyx.Experience.ReplayBufferETS, [[], [name: Gyx.Experience.ReplayBufferETS]])
    ]
  end
end
