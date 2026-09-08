defmodule Gyx.Agents.SARSA.Agent do
  @moduledoc """
  This agent implements SARSA, it takes into account the current
  state, action, reward (s<sub>t</sub>, a<sub>t</sub>, r<sub>t</sub>)
  and on policy estimates for the best next action a<sub>t+1</sub> and state s<sub>t+1</sub>.
  <br/>The Q update is given by:
  ![sarsa](https://wikimedia.org/api/rest_v1/media/math/render/svg/4ea76ebe74645baff9d5a67c83eac1daff812d79)
  <br/>
  The Q table process must be referenced on struct `Q` key, which must follow the `Gyx.Qstorage` behaviour
  """
  defstruct Q: nil, learning_rate: nil, gamma: nil, epsilon: nil, epsilon_min: nil

  @type t :: %__MODULE__{
          Q: any(),
          learning_rate: float(),
          gamma: float(),
          epsilon: float(),
          epsilon_min: float()
        }

  alias Gyx.Qstorage.QGenServer
  alias Gyx.Core.Spaces

  def init(process_q) do
    {:ok, qgenserver} =
      case is_pid(process_q) do
        true -> {:ok, process_q}
        false -> QGenServer.start_link([], [])
      end

    IO.puts(inspect(qgenserver))

    {:ok,
     %__MODULE__{
       Q: qgenserver,
       learning_rate: 0.8,
       gamma: 0.9,
       epsilon: 0.8,
       epsilon_min: 0.1
     }}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def start_link(process_q, opts) when is_pid(process_q) do
    GenServer.start_link(__MODULE__, process_q, opts)
  end

  def act_greedy(agent, environment_state) do
    GenServer.call(agent, {:act_greedy, environment_state})
  end

  def act_epsilon_greedy(agent, environment_state) do
    GenServer.call(agent, {:act_epsilon_greedy, environment_state})
  end

  def td_learn(agent, sarsa) do
    GenServer.call(agent, {:td_learn, sarsa})
  end

  def handle_call(
        {:td_learn, {s, a, r, ss, aa}},
        _from,
        state = %{Q: qtable, learning_rate: learning_rate, gamma: gamma}
      ) do
    predict = QGenServer.q_get(qtable, s, a)
    target = r + gamma * QGenServer.q_get(qtable, ss, aa)
    expected_return = predict + learning_rate * (target - predict)
    QGenServer.q_set(qtable, s, a, expected_return)
    {:reply, expected_return, state}
  end

  def handle_call(
        {:act_epsilon_greedy, environment_state},
        _from,
        state = %{Q: qtable, epsilon: epsilon}
      ) do
    {:ok, random_action} = Spaces.sample(environment_state.action_space)

    max_action =
      case QGenServer.get_max_action(qtable, environment_state.current_state) do
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
    {:reply, qtable.get_max_action(environment_state.current_state), state}
  end
end
