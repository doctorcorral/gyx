defmodule Gyx.Blackjack.Trainer do
  @moduledoc """
  This module describes an entire training process,
  tune accordingly to your particular environment and agent
  """
  use GenServer
  alias Gyx.Experience.Exp
  require Logger

  @enforce_keys [:environment, :agent]

  defstruct environment: nil, agent: nil, trajectory: nil

  @type t :: %__MODULE__{
          environment: any(),
          agent: any(),
          trajectory: list(Exp)
        }

  @env_module Gyx.Blackjack.Game
  @agent Gyx.Blackjack.IAgent

  def init(_) do
    {:ok,
     %Gyx.Blackjack.Trainer{
       environment: Gyx.Gym.Environment,
       agent: Gyx.Qstorage.QGenServer,
       trajectory: []
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %{env: @env_module, agent: @agent}, opts)
  end

  def train() do
    GenServer.call(__MODULE__, :train)
  end

  def handle_call(:train, _from, t = %__MODULE__{}) do
    {:reply, trainer(t, 3), t}
  end

  defp trainer(t = %__MODULE__{}, 0), do: t

  defp trainer(t = %__MODULE__{}, num_episodes) do
    Logger.info("\n*** Episodes remaining: " <> inspect(num_episodes))
    t.environment.reset()
    t = %{t | trajectory: []}

    t
    |> run_episode(false)
    |> trainer(num_episodes - 1)
  end

  defp run_episode(t = %__MODULE__{}, true), do: t

  defp run_episode(t = %__MODULE__{}, false) do
    exp = %Exp{done: done} =
      t.environment.get_state()
      |> t.agent.get_max_action()
      |> t.environment.step
    t = %{t | trajectory: [exp | t.trajectory]}
    run_episode(t, done)
  end
end
