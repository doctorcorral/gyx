defmodule Trainer.Single do
  use GenServer
  alias Env.Blackjack.Abstraction

  defstruct environment: nil, agent: nil, rewards: [], current_state: nil, experiences: []

  @env_module Env.Blackjack
  @agent Agents.BlackjackAgent

  def init(%{env: env, agent: agent}) do
    env.start_link()
    agent.start_link()

    {:ok,
     %Trainer.Single{
       environment: env,
       agent: agent,
       experiences: []
     }}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %{env: @env_module, agent: @agent}, name: __MODULE__)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %Trainer.Single{}) do
    {:reply, trainer(t, 13), t}
  end

  defp trainer(t = %Trainer.Single{}, 0), do: t

  defp trainer(t = %Trainer.Single{}, num_episodes) do
    IO.puts("\n*** Episodes remaining: " <> inspect(num_episodes))
    t.environment.reset()
    t = %{t | experiences: []}
    t
    |> run_episode(false)
    |> trainer(num_episodes - 1)
  end

  defp run_episode(t = %Trainer.Single{}, true), do: t

  defp run_episode(t = %Trainer.Single{}, false) do
    action = t.agent.get_action(t.environment.get_state_abstraction())
    exp = %Experience.Exp{done: done} = t.environment.step(action)
    t = %{t | experiences: [exp | t.experiences]}
    IO.inspect(exp)
    IO.inspect(t.experiences)
    run_episode(t, done)
  end
end
