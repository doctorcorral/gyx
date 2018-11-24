defmodule Trainer.Single do
  use GenServer

  defstruct environment: nil, agent: nil, reward_sum: 0, experience: nil

  @env_module Env.Blackjack

  def init(env_module \\ @env_module) do
    env_module.start_link()
    {:ok,
     %Trainer.Single{
       environment: env_module,
       agent: nil,
       experience: %Experience.Exp{}
     }}
  end

  def start_link do
    GenServer.start_link(__MODULE__,  @env_module , name: __MODULE__)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %Trainer.Single{experience: exp}) do
    t.environment.reset()
    {:reply, run_episode(exp.done, t), t}
  end

  defp run_episode(true, _) do
    IO.puts("> Finished")
    42
  end

  defp run_episode(false, t = %Trainer.Single{}) do
    exp = %Experience.Exp{done: done} = t.environment.step(Enum.random([0, 1]))
    t = %{t | experience: exp}
    IO.inspect(exp)
    run_episode(done, t)
  end
end
