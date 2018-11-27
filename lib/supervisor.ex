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
      worker(Env.Blackjack.Abstraction, [[], [name: Env.Blackjack.Abstraction]]),
      worker(Env.Blackjack, [[], [name: Env.Blackjack]]),
      worker(Agents.BlackjackAgent, [[], [name: Agents.BlackjackAgent]])
    ]
  end
end
