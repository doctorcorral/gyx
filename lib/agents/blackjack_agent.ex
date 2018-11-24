defmodule Agents.BlackjackAgent do
  use GenServer
  defstruct state_value_table: nil, action_space: [0, 1]

  def init(_) do
    {:ok, %Agents.BlackjackAgent{state_value_table: :ets.new(__MODULE__, [:set, :protected])}}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %Agents.BlackjackAgent{}, name: __MODULE__)
  end

  def q_get(state = %Env.Blackjack{}, action ) do
    GenServer.call(__MODULE__,{:q_get, {state, action}} )
  end
  def q_set(state = %Env.Blackjack{}, action, value) do
    :ets.insert(__MODULE__, {inspect(state) <> inspect(action), value})
  end

  def handle_call({:q_get, {state = %Env.Blackjack{}, action}}, _from, state) do
    case :ets.lookup(__MODULE__, inspect(state) <> inspect(action)) do
      [value] -> value
      [] -> nil
    end
  end

end

