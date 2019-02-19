defmodule Gyx.Agents.SARSA.Agent do
  defstruct Q: nil, lr_rate: nil

  @type t :: %__MODULE__{
          Q: any(),
          lr_rate: Float.t()
        }

  alias Gyx.Qstorage.QGenServer

  def init(_) do
    {:ok,
     %__MODULE__{
       Q: QGenServer,
       lr_rate: 0.81
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
  end

  def act_greedy(observation) do
    GenServer.call(__MODULE__, {:act_greedy, observation})
  end

  def act_epsilon_greedy(observation, epsilon \\ 0.9) do
    GenServer.call(__MODULE__, {:act_epsilon_greedy, observation, epsilon})
  end

  def td_learn(sarsa) do
    GenServer.call(__MODULE__, {:td_learn, sarsa})
  end

  def handle_call({:td_learn, {s, a, r, ss, aa}}, _from, %{Q: qtable, lr_rate: lr_rate} = state) do
    predict = qtable.q_get(s, a)
    target = r + 0.01 * qtable.q_get(ss, aa)
    expected_return = predict + lr_rate * (target - predict)
    qtable.q_set(s, a, expected_return)
    {:reply, expected_return, state}
  end

  def handle_call({:act_epsilon_greedy, observation, epsilon},
                  _from,
                  %{Q: qtable} = state) do
    {:reply, if(:rand.uniform() < epsilon,
                do: qtable.get_max_action(observation),
                else:  Enum.random([0, 1])), state}
  end

  def handle_call({:act_greedy, observation}, _from, %{Q: qtable} = state) do
    {:reply, qtable.get_max_action(observation), state}
  end

end
