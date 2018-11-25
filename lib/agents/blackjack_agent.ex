defmodule Agents.BlackjackAgent do
  use GenServer
  alias Env.Blackjack.Abstraction
  defstruct state_value_table: %{}, action_space: [0, 1]

  def init(_) do
    {:ok, %Agents.BlackjackAgent{}}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %Agents.BlackjackAgent{}, name: __MODULE__)
  end

  def q_get(env_state = %Abstraction{}, action) do
    GenServer.call(__MODULE__, {:q_get, {env_state, action}})
  end

  def q_set(env_state = %Abstraction{}, action, value) do
    GenServer.call(__MODULE__, {:q_set, {env_state, action, value}})
  end

  def get_action(env_state = %Abstraction{}) do
    GenServer.call(__MODULE__, {:get_action, env_state})
  end

  def handle_call(
        {:q_get, {env_state = %Abstraction{}, action}},
        _from,
        state = %Agents.BlackjackAgent{}
      ) do
    {:reply, state.state_value_table[inspect(env_state)][inspect(action)], state}
  end

  def handle_call(
        {:q_set, {env_state = %Abstraction{}, action, value}},
        _from,
        state = %Agents.BlackjackAgent{state_value_table: Q}
      ) do
        k_state = inspect(env_state)
    new_state = Map.put(Q, k_state, %{Q[k_state] | action => value})
    {:reply, new_state, %{state | state_value_table: new_state}}
  end

  def handle_call(
        {:get_action, env_state},
        _from,
        state = %Agents.BlackjackAgent{state_value_table: Q}
      ) do
    [{action, __}] =
      Q[inspect(env_state)] |> Enum.sort_by(fn {_, v} -> v end, &>=/2) |> Enum.take(1)

    {:reply, action, state}
  end
end
