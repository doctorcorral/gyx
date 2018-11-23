defmodule Env.Blackjack do
  use GenServer

  defstruct player: [], dealer: [], face_up_card: 0

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

  def step(action) when action not in @action_space, do: {:reply, :error, "Invalid action"}

  def step(action) do
    GenServer.call(__MODULE__, {:act, action})
  end

  def handle_call(:get_state, _from, state = %Env.Blackjack{}) do
    IO.inspect(state)
    {:reply, :ok, state}
  end

  def handle_call({:act, 0}, _from, state = %Env.Blackjack{}) do
    state = %{state | dealer: get_until(state.dealer)}

    {:reply,
     {state, cmp(score(state.player), score(state.dealer) + is_natural(state.player)), true, %{}},
     state}
  end

  def handle_call({:act, _action}, _from, state = %Env.Blackjack{}) do
    state = %{state | player: [draw_card() | state.player]}

    case is_bust(state.player) do
      true -> {:reply, {state, -1, true, %{}}, state}
      _ -> {:reply, {state, 0, false, %{}}, state}
    end
  end

  def handle_call(:reset, _from, _state) do
    new_state = %Env.Blackjack{player: draw_hand(), dealer: draw_hand()}
    {:reply, new_state, new_state}
  end

  defp draw_card() do
    # FIXME
    # @deck |> Enum.random()
    [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10] |> Enum.random()
  end

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

  defp is_bust(hand) do
    Enum.sum(hand) > 21
  end

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

  defp draw_hand() do
    [draw_card(), draw_card()]
  end
end
