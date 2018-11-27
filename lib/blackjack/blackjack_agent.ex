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

  def get_q() do
    GenServer.call(__MODULE__, :get_q)
  end

  def handle_call(:get_q, _from, state = %Agents.BlackjackAgent{}),
    do: {:reply, state.state_value_table, state}

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
        state = %Agents.BlackjackAgent{}
      ) do
    k_state = inspect(env_state)

    state = %{
      state
      | state_value_table: Map.put_new_lazy(state.state_value_table, k_state, fn -> %{} end)
    }

    new_state =
      Map.put(
        state.state_value_table,
        k_state,
        Map.put(state.state_value_table[k_state], action, value)
      )

    {:reply, new_state, %{state | state_value_table: new_state}}
  end

  def handle_call(
        {:get_action, env_state},
        _from,
        state = %Agents.BlackjackAgent{}
      ) do
    k_state = inspect(env_state)

    state = %{
      state
      | state_value_table: Map.put_new_lazy(state.state_value_table, k_state, fn -> %{} end)
    }

    with [{action, _}] <-
           state.state_value_table[k_state]
           |> Enum.sort_by(fn {_, v} -> v end, &>=/2)
           |> Enum.take(1) do
      {:reply, action, state}
    else
      _ -> {:reply, Enum.random([0, 1]), state}
    end
  end
end
