defmodule Agents.BlackjackAgent do
  use GenServer
  defstruct state_value_table: %{}, action_space: [0, 1]

  def init(_) do
    {:ok, %Agents.BlackjackAgent{}}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %Agents.BlackjackAgent{}, name: __MODULE__)
  end

  def q_get(env_state = %Env.Blackjack{}, action) do
    GenServer.call(__MODULE__, {:q_get, {env_state, action}})
  end

  def q_set(env_state = %Env.Blackjack{}, action, value) do
    GenServer.call(__MODULE__, {:q_set, {env_state, action, value}})
  end

  def handle_call({:q_get, {env_state = %Env.Blackjack{}, action}}, _from, state) do
    {:reply, state.state_value_table[inspect(env_state)][inspect(action)], state}
  end

  def handle_call({:q_set, {env_state = %Env.Blackjack{}, action, value}}, _from, state) do
    new_state = %{
      state.state_value_table
      | inspect(env_state) => %{
          state.state_value_table[inspect(env_state)]
          | inspect(action) => value
        }
    }

    {:reply, new_state, %{state | state_value_table: new_state}}
  end
end
