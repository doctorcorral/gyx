defmodule Gyx.Agents.SARSA.Agent do
  defstruct Q: nil, lr_rate: nil

  @type t :: %__MODULE__{
          Q: any(),
          lr_rate: Float.t()
        }

  alias Gyx.Qstorage.QGenServer
  alias Gyx.Core.Spaces

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

  def act_greedy(environment_state) do
    GenServer.call(__MODULE__, {:act_greedy, environment_state})
  end

  def act_epsilon_greedy(environment_state, epsilon \\ 0.2) do
    GenServer.call(__MODULE__, {:act_epsilon_greedy, environment_state, epsilon})
  end

  def td_learn(sarsa) do
    GenServer.call(__MODULE__, {:td_learn, sarsa})
  end

  def handle_call({:td_learn, {s, a, r, ss, aa}}, _from, state = %{Q: qtable, lr_rate: lr_rate}) do
    predict = qtable.q_get(s, a)
    target = r + 0.01 * qtable.q_get(ss, aa)
    expected_return = predict + lr_rate * (target - predict)
    qtable.q_set(s, a, expected_return)
    {:reply, expected_return, state}
  end

  def handle_call(
        {:act_epsilon_greedy, environment_state, epsilon},
        _from,
        %{Q: qtable} = state
      ) do
    {:ok, random_action} = Spaces.sample(environment_state.action_space)

    max_action =
      case qtable.get_max_action(environment_state.observation) do
        {:ok, action} -> action
        {:error, _} -> random_action
      end

    final_action =
      case :rand.uniform() < 1 - epsilon do
        true -> max_action
        false -> random_action
      end

    {:reply, final_action, state}
  end

  def handle_call({:act_greedy, environment_state}, _from, state = %{Q: qtable}) do
    {:reply, qtable.get_max_action(environment_state.observation), state}
  end
end
