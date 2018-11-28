defmodule Gyx.Blackjack.Trainer do
  use GenServer

  defstruct environment: nil, agent: nil, rewards: [], current_state: nil, experiences: []

  @env_module Gyx.Blackjack.Game
  @agent Gyx.Blackjack.IAgent

  def init(_) do
    {:ok,
     %Gyx.Blackjack.Trainer{
       environment: Gyx.Blackjack.Game,
       agent: Gyx.Blackjack.IAgent,
       experiences: []
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %{env: @env_module, agent: @agent}, opts)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %__MODULE__{}) do
    {:reply, trainer(t, 13), t}
  end

  defp trainer(t = %__MODULE__{}, 0), do: t

  defp trainer(t = %__MODULE__{}, num_episodes) do
    IO.puts("\n*** Episodes remaining: " <> inspect(num_episodes))
    t.environment.reset()
    t = %{t | experiences: []}

    t
    |> run_episode(false)
    |> trainer(num_episodes - 1)
  end

  defp run_episode(t = %__MODULE__{}, true), do: t

  defp run_episode(t = %__MODULE__{}, false) do
    action = t.agent.get_action(t.environment.get_state_abstraction())
    exp = %Experience.Exp{done: done} = t.environment.step(action)
    t = %{t | experiences: [exp | t.experiences]}
    IO.inspect(exp)
    IO.inspect(t.experiences)
    run_episode(t, done)
  end
end
