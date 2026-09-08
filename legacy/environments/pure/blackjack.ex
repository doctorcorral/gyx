defmodule Gyx.Environments.Pure.Blackjack do
  @moduledoc """
  This is an environment implementation of the game of
  [Blackjack](https://en.wikipedia.org/wiki/Blackjack) as
  described in [Sutton and Barto RL book](http://incompleteideas.net/book/RLbook2018.pdf)
  ***Example 5.1*** cited below.

  ![](http://www.gamblingsupport.org/wp-content/uploads/2014/11/Playing-Blackjack-To-Win.png)

  ***Exctract from [Sutton and Barto RL book](http://incompleteideas.net/book/RLbook2018.pdf):***
  The object of the popular casino card game of *blackjack* is toobtain
  cards the sum of whose numerical values is as great as possible without
  exceeding `21`.
  All face cards count as `10`, and an ace can count either
  as `1` or as `11`. We considerthe version in which each player competes
  independently against the dealer. The gamebegins with two cards dealt
  to both dealer and player. One of the dealer’s cards is faceup
  and the other is face down. If the player has `21` immediately
  (an ace and a 10-card),it is called anatural. He then wins unless
  the dealer also has a natural, in which case thegame is a draw. If
  the player does not have a natural, then he can request
  additionalcards, one by one (hits), until he either stops (sticks)
  or exceeds `21` (goes bust). If he goesbust, he loses; if he sticks,
  then it becomes the dealer’s turn. The dealer hits or sticksaccording
  to a fixed strategy without choice: he sticks on any sum of 17 or
  greater, andhits otherwise. If the dealer goes bust, then the
  player wins; otherwise, the outcome -win,lose, or draw- is
  determined by whose final sum is closer to `21`.

  Playing blackjack is naturally formulated as an episodic finite MDP. Each game
  ofblackjack is an episode. Rewards of `+1`,`-1`, and `0` are given
  for winning, losing, anddrawing, respectively. All rewards
  within a game are zero, and we do not discount (`gamma = 1`); therefore
  these terminal rewards are also the returns. The player’s actions
  are to hit orto stick. The states depend on the player’s cards
  and the dealer’s showing card. Weassume that cards are dealt from an
  infinite deck (i.e., with replacement) so that there isno advantage
  to keeping track of the cards already dealt. If the player
  holds an ace thathe could count as `11` without going bust, then
  the ace is said to beusable. In this caseit is always counted as
  11 because counting it as 1 would make the sum `11` or less, in
  which case there is no decision to be made because, obviously,
  the player should alwayshit. Thus, the player makes decisions
  on the basis of three variables: his current sum(12–21),
  the dealer’s one showing card (ace–10), and whether or not he
  holds a usableace. This makes for a total of `200` states.

  > This implementation must behave as
  [OpenAI Gym Blackjack-v0 implementation](https://github.com/openai/gym/blob/master/gym/envs/toy_text/blackjack.py).

  """
  alias Gyx.Core.{Env, Exp}
  alias Gyx.Core.Spaces.{Discrete, Tuple}
  use Env
  use GenServer
  require Logger

  defstruct player: [],
            dealer: [],
            player_sum: nil,
            dealer_sum: nil,
            action_space: nil,
            observation_space: nil,
            done: nil

  @type t :: %__MODULE__{
          player: list(),
          dealer: list(),
          action_space: Discrete.t(),
          observation_space: Tuple.t(),
          done: bool()
        }

  # card values
  @deck [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

  @impl true
  def init(_) do
    {:ok,
     %__MODULE__{
       player: draw_hand(),
       dealer: draw_hand(),
       action_space: %Discrete{n: 2},
       observation_space: %Tuple{
         spaces: [%Discrete{n: 32}, %Discrete{n: 11}, %Discrete{n: 2}]
       },
       done: false
     }}
  end

  def start_link(_, opts) do
    Logger.info("Starting Environment: " <> inspect(__MODULE__), ansi_color: :magenta)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def reset(environment) do
    GenServer.call(environment, :reset)
  end

  def get_state_abstraction(environment) do
    GenServer.call(environment, :get_state_abstraction)
  end

  def handle_call(:get_state_abstraction, _from, state = %__MODULE__{player: p, dealer: d}) do
    Logger.debug(inspect(state))
    {:reply, %{state | player_sum: Enum.sum(p), dealer_sum: Enum.sum(d)}, state}
  end

  def handle_call({:act, action = 0}, _from, state = %__MODULE__{}) do
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

  def handle_call({:act, action = 1}, _from, state = %__MODULE__{}) do
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

  @impl true
  def handle_call(:reset, _from, _state) do
    new_env_state = %__MODULE__{
      player: draw_hand(),
      dealer: draw_hand(),
      action_space: %Discrete{n: 2},
      observation_space: %Tuple{
        spaces: [%Discrete{n: 32}, %Discrete{n: 11}, %Discrete{n: 2}]
      }
    }

    {:reply, %Exp{}, new_env_state}
  end

  def handle_call(:observe, _from, state), do: {:reply, env_state_transformer(state), state}

  defp env_state_transformer(%__MODULE__{player: p, dealer: d}) do
    {Enum.sum(p), Enum.sum(d)}
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
