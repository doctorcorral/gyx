defmodule Env.Blackjack.Abstraction do
  defstruct player_sum: 0, dealer_sum: 0
end

defmodule Env.Blackjack do
  use GenServer
  alias Experience.Exp

  defstruct player: [], dealer: []
  # card values
  @deck [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]
  # STICK, HIT
  @action_space [0, 1]

  def init(_) do
    {:ok, %Env.Blackjack{player: draw_hand(), dealer: draw_hand()}}
  end

  def start_link do
    GenServer.start_link(__MODULE__, %Env.Blackjack{}, name: __MODULE__)
  end

  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def get_state() do
    GenServer.call(__MODULE__, :get_state)
  end

  def get_state_abstraction() do
    GenServer.call(__MODULE__, :get_state_abstraction)
  end

  def step(action) when action not in @action_space, do: {:reply, :error, "Invalid action"}

  def step(action) do
    GenServer.call(__MODULE__, {:act, action})
  end

  def handle_call(:get_state, _from, state = %Env.Blackjack{}) do
    IO.inspect(state)
    {:reply, state, state}
  end

  def handle_call(:get_state_abstraction, _from, state = %Env.Blackjack{player: p, dealer: d}) do
    IO.inspect(state)
    {:reply, %Env.Blackjack.Abstraction{player_sum: Enum.sum(p), dealer_sum: Enum.sum(d)}, state}
  end

  def handle_call({:act, action = 0}, _from, state = %Env.Blackjack{}) do
    next_state = %{state | dealer: get_until(state.dealer)}
    experience = %Exp{
      state: env_state_transformer(state),
      action: action,
      next_state: env_state_transformer(next_state),
      reward: 0,
      done: true,
      info: %{}
    }
    reward = cmp(score(next_state.player), score(next_state.dealer)) + is_natural(state.player)
    case is_bust(next_state.dealer) do
       true -> {:reply, %{experience | reward: 1.0}, next_state}
       false -> {:reply, %{experience | reward: reward}, next_state}
    end

  end

  def handle_call({:act, action = 1}, _from, state = %Env.Blackjack{}) do
    next_state = %{state | player: [draw_card() | state.player]}

    case is_bust(next_state.player) do
      true ->
        {:reply,
         %Exp{
           state: env_state_transformer(state),
           action: action,
           next_state: env_state_transformer(next_state),
           reward: -1,
           done: true,
           info: %{}
         }, next_state}

      _ ->
        {:reply,
         %Exp{
           state: env_state_transformer(state),
           action: action,
           next_state: env_state_transformer(next_state),
           reward: 0,
           done: false,
           info: %{}
         }, next_state}
    end
  end

  def handle_call(:reset, _from, _state) do
    new_env_state = %Env.Blackjack{player: draw_hand(), dealer: draw_hand()}
    {:reply, %Exp{}, new_env_state}
  end

  defp env_state_transformer(%Env.Blackjack{player: p, dealer: d}) do
    %Env.Blackjack.Abstraction{player_sum: Enum.sum(p), dealer_sum: Enum.sum(d)}
  end

  defp draw_card(), do: @deck |> Enum.random()

  defp draw_hand(), do: [draw_card(), draw_card()]

  defp get_until(hand, v \\ 17) do
    new_card = draw_card()

    case Enum.sum(hand ++ [new_card]) < v do
      true -> get_until([new_card | hand])
      _ -> [new_card | hand]
    end
  end

  defp cmp(a, b) do
    case a > b do
      true -> 1.0
      _ -> -1.0
    end
  end

  defp is_bust(hand), do: Enum.sum(hand) > 21

  defp score(hand) do
    case is_bust(hand) do
      true -> 0
      false -> Enum.sum(hand)
    end
  end

  defp is_natural(hand, plus \\ 0.5) do
    case Enum.sort(hand) == [1, 10] do
      true -> plus
      _ -> 0.0
    end
  end
end
