defmodule Gyx.Envs.Blackjack do
  @moduledoc """
  Blackjack-v1, matching Gymnasium / Sutton & Barto Example 5.1.

  Observation is `{player_sum, dealer_showing, usable_ace}` where
  `usable_ace` is `0` or `1`. Actions: `0` stick, `1` hit.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.{Discrete, Tuple}
  alias Gyx.RNG

  @deck [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10, 10, 10]

  defstruct player: [],
            dealer: [],
            natural: false,
            finished: false,
            steps: 0,
            rng: nil,
            action_space: %Discrete{n: 2},
            observation_space: %Tuple{
              spaces: [%Discrete{n: 32}, %Discrete{n: 11}, %Discrete{n: 2}]
            }

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "Blackjack-v1",
      observation_space: %Tuple{
        spaces: [%Discrete{n: 32}, %Discrete{n: 11}, %Discrete{n: 2}]
      },
      action_space: %Discrete{n: 2},
      max_episode_steps: nil
    }
  end

  @impl true
  def new(opts \\ []) do
    env = %__MODULE__{natural: Keyword.get(opts, :natural, false)}
    env |> reset(opts) |> elem(0)
  end

  @impl true
  def reset(env, opts \\ []) do
    rng =
      case Keyword.fetch(opts, :seed) do
        {:ok, seed} -> RNG.seed(seed)
        :error -> env.rng || RNG.seed(nil)
      end

    {player, rng} = draw_hand(rng)
    {dealer, rng} = draw_hand(rng)
    env = %{env | player: player, dealer: dealer, steps: 0, finished: false, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{player: player, dealer: dealer}) do
    {sum_hand(player), hd(dealer), usable_ace_flag(player)}
  end

  @impl true
  def step(env, action) do
    if Gyx.Core.Spaces.contains?(env.action_space, action) do
      do_step(env, action)
    else
      {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :svg), do: {:ok, Gyx.Render.Blackjack.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.Blackjack.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  defp do_step(env, 1) do
    obs = observe(env)
    {card, rng} = draw_card(env.rng)
    player = env.player ++ [card]
    finished = bust?(player)
    env = %{env | player: player, rng: rng, steps: env.steps + 1, finished: finished}

    if finished do
      {:ok, env, experience(obs, 1, env, -1.0, true)}
    else
      {:ok, env, experience(obs, 1, env, 0.0, false)}
    end
  end

  defp do_step(env, 0) do
    obs = observe(env)
    {dealer, rng} = play_dealer(env.dealer, env.rng)
    env = %{env | dealer: dealer, rng: rng, steps: env.steps + 1, finished: true}
    reward = terminal_reward(env.player, dealer, env.natural)
    {:ok, env, experience(obs, 0, env, reward, true)}
  end

  defp experience(obs, action, env, reward, terminated) do
    %Exp{
      observation: obs,
      action: action,
      reward: reward,
      next_observation: observe(env),
      terminated: terminated,
      truncated: false,
      info: %{player: env.player, dealer: env.dealer}
    }
  end

  defp terminal_reward(player, dealer, natural?) do
    cond do
      bust?(player) ->
        -1.0

      bust?(dealer) ->
        if natural? and natural_hand?(player), do: 1.5, else: 1.0

      natural? and natural_hand?(player) and not natural_hand?(dealer) ->
        1.5

      true ->
        cmp(score(player), score(dealer))
    end
  end

  defp play_dealer(hand, rng) do
    if sum_hand(hand) < 17 do
      {card, rng} = draw_card(rng)
      play_dealer(hand ++ [card], rng)
    else
      {hand, rng}
    end
  end

  defp draw_hand(rng) do
    {a, rng} = draw_card(rng)
    {b, rng} = draw_card(rng)
    {[a, b], rng}
  end

  defp draw_card(rng) do
    {idx, rng} = RNG.int(rng, 0, length(@deck) - 1)
    {Enum.at(@deck, idx), rng}
  end

  defp usable_ace?(hand), do: 1 in hand and Enum.sum(hand) + 10 <= 21
  defp usable_ace_flag(hand), do: if(usable_ace?(hand), do: 1, else: 0)

  defp sum_hand(hand) do
    if usable_ace?(hand), do: Enum.sum(hand) + 10, else: Enum.sum(hand)
  end

  defp bust?(hand), do: sum_hand(hand) > 21
  defp score(hand), do: if(bust?(hand), do: 0, else: sum_hand(hand))
  defp natural_hand?(hand), do: Enum.sort(hand) == [1, 10]

  defp cmp(a, b) when a > b, do: 1.0
  defp cmp(a, b) when a < b, do: -1.0
  defp cmp(_, _), do: 0.0
end
