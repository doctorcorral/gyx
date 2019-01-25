defmodule Gyx.FrozenLake.Environment do
  @moduledoc """
  This module implements the FrozenLake-v0
  environment according to
  OpenAI implementation: https://gym.openai.com/envs/FrozenLake-v0/
  """

  alias Gyx.Framework.Env
  @behaviour Env
  use GenServer
  alias Experience.Exp

  defstruct map: nil, row: nil, col: nil, ncol: nil, nrow: nil

  @type t :: %__MODULE__{
          map: list(charlist),
          row: integer,
          col: integer,
          ncol: integer,
          nrow: integer
        }

  @actions %{0 => :left, 1 => :down, 2 => :right, 3 => :up}
  @action_space Map.keys(@actions)

  @maps %{
    "4x4" => [
      "SFFF",
      "FHFH",
      "FFFH",
      "HFFG"
    ],
    "8x8" => [
      "SFFFFFFF",
      "FFFFFFFF",
      "FFFHFFFF",
      "FFFFFHFF",
      "FFFHFFFF",
      "FHHFFFHF",
      "FHFFHFHF",
      "FFFHFFFG"
    ]
  }

  @impl true
  def init(map_name \\ "4x4") do
    map = @maps[map_name]

    {:ok,
     %__MODULE__{
       map: map,
       row: 0,
       col: 0,
       nrow: length(map),
       ncol: String.length(List.first(map))
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, "4x4", opts)
  end

  def step(action) when action not in @action_space, do: {:reply, :error, "Invalid action"}

  @impl true
  def step(action) do
    GenServer.call(__MODULE__, {:act, @actions[action]})
  end

  @impl Env
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def render() do
    GenServer.call(__MODULE__, :render)
  end

  def handle_call(:render, _from, state) do
    printEnv(state.map, state.row, state.col)
    {:reply, {state.row, state.col}, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_env_state = %{state | row: 0, col: 0}
    {:reply, %Exp{}, new_env_state}
  end

  def handle_call({:act, :left}, _from, state) do
    new_env_state = %{state | col: max(state.col - 1, 0)}
    {:reply, %Exp{}, new_env_state}
  end

  def handle_call({:act, :down}, _from, state) do
    new_env_state = %{state | row: min(state.row + 1, state.nrow - 1)}
    {:reply, %Exp{}, new_env_state}
  end

  def handle_call({:act, :right}, _from, state) do
    new_env_state = %{state | col: min(state.col + 1, state.ncol - 1)}
    {:reply, %Exp{}, new_env_state}
  end

  def handle_call({:act, :up}, _from, state) do
    new_env_state = %{state | row: max(state.row - 1, 0)}
    {:reply, %Exp{}, new_env_state}
  end

  defp printEnv([], _, _), do: IO.puts("yeah")

  defp printEnv([h | t], row, col) do
    printEnvLine(h, col, row == 0)
    printEnv(t, row - 1, col)
  end

  defp printEnvLine(string_line, agent_position, mark) do
    chars_line = String.graphemes(string_line)

    m =
      if mark,
        do: IO.ANSI.format_fragment([:red, :bright, Enum.at(chars_line, agent_position)], true),
        else: Enum.at(chars_line, agent_position)

    p =
      IO.ANSI.format_fragment(
        [:green, :bright, Enum.take(chars_line, agent_position) |> List.to_string()],
        true
      )

    q =
      IO.ANSI.format_fragment(
        [
          :green,
          :bright,
          Enum.take(chars_line, agent_position - length(chars_line) + 1) |> List.to_string()
        ],
        true
      )

    (p ++ m ++ q)
    |> IO.puts()
  end
end
