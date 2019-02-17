defmodule Gyx.Agents.SARSA.Agent do
  defstruct Q: nil

  @type t :: %__MODULE__{
          Q: any()
        }

  alias Gyx.Qstorage.QGenServer

  def init(_) do
    {:ok,
     %__MODULE__{
       Q: QGenServer
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
  end

  def act_greedy(observation) do
    GenServer.call(__MODULE__, {:act_greedy, observation})
  end

  def handle_call({:act_greedy, observation}, _from, %{Q: qtable} = state) do
    {:reply, qtable.get_max_action(observation), state}
  end
end
