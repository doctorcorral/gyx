defmodule Trainer.Simple do
  use GenServer

  defstruct environment: nil, agent: nil, reward_sum: 0, experience: nil

  def init(_) do
    {:ok,
     %Trainer.Simple{
       environment: Env.Blackjack.start_link(),
       agent: nil,
       experience: %Experience.Exp{}
     }}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %Trainer.Simple{}, name: __MODULE__)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %Trainer.Simple{experience: exp}) do
    {:reply, trainlive(exp.done, t), t}
  end

  defp trainlive(true, _) do
    IO.puts("> Finished")
    42
  end

  defp trainlive(false, t = %Trainer.Simple{}) do
    exp = %Experience.Exp{reward: reward, done: done}= Env.Blackjack.step(Enum.random([1, 2]))
    t = %{t | experience: exp}
    IO.inspect(reward)
    trainlive(done, t)
  end
end
