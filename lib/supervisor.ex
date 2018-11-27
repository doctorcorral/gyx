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
      worker(Env.Blackjack.Game, [[], [name: Env.Blackjack.Game]]),
      worker(Gyx.Blackjack.IAgent, [[], [name: Gyx.Blackjack.IAgent]]),
      worker(Gyx.Blackjack.Trainer, [[], [name: Gyx.Blackjack.Trainer]])
    ]
  end
end
