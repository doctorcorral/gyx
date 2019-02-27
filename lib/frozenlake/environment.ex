defmodule Gyx.FrozenLake.Environment do
  @moduledoc """
  This module implements the FrozenLake-v0
  environment according to
  OpenAI implementation: https://gym.openai.com/envs/FrozenLake-v0/
  """

  alias Gyx.Core.{Env, Exp}
  use Env
  use GenServer

  defstruct map: nil, row: nil, col: nil, ncol: nil, nrow: nil, action_space: nil

  @type t :: %__MODULE__{
          map: list(charlist),
          row: integer,
          col: integer,
          ncol: integer,
          nrow: integer,
          action_space: any
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
  def init(map_name) do
    map = @maps[map_name]

    {:ok,
     %__MODULE__{
       map: map,
       row: 0,
       col: 0,
       nrow: length(map),
       ncol: String.length(List.first(map)),
       action_space: %Gyx.Core.Spaces.Discrete{n: 4}
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
    {:reply, {:ok, position: {state.row, state.col}}, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_env_state = %{state | row: 0, col: 0}
    {:reply, %Exp{next_state: new_env_state}, new_env_state}
  end

  def handle_call({:act, action}, _from, state) do
    new_state = rwo_col_step(state, action)
    current = get_position(new_state.map, new_state.row, new_state.col)

    {:reply,
     %Exp{
       state: env_state_transformer(state),
       action: action,
       next_state: env_state_transformer(new_state),
       reward: if(current == "G", do: 1.0, else: 0.0),
       done: current in ["H", "G"],
       info: %{}
     }, new_state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  defp get_position(map, row, col) do
    Enum.at(String.graphemes(Enum.at(map, row)), col)
  end

  def env_state_transformer(state), do: Map.put(state, :enumerated, state.row * 4 + state.col)

  @spec rwo_col_step(__MODULE__.t(), atom) :: __MODULE__.t()
  defp rwo_col_step(state, action) do
    case action do
      :left -> %{state | col: max(state.col - 1, 0)}
      :down -> %{state | row: min(state.row + 1, state.nrow - 1)}
      :right -> %{state | col: min(state.col + 1, state.ncol - 1)}
      :up -> %{state | row: max(state.row - 1, 0)}
      _ -> state
    end
  end

  defp printEnv([], _, _), do: :ok

  defp printEnv([h | t], row, col) do
    printEnvLine(h, col, row == 0)
    printEnv(t, row - 1, col)
  end

  defp printEnvLine(string_line, agent_position, mark) do
    chars_line = String.graphemes(string_line)

    m =
      if mark,
        do:
          IO.ANSI.format_fragment(
            [:light_magenta, :italic, chars_line |> Enum.at(agent_position)],
            true
          ),
        else: [Enum.at(chars_line, agent_position)]

    p =
      IO.ANSI.format_fragment(
        [:light_blue, :italic, chars_line |> Enum.take(agent_position) |> List.to_string()],
        true
      )

    q =
      IO.ANSI.format_fragment(
        [
          :light_blue,
          :italic,
          chars_line |> Enum.take(agent_position - length(chars_line) + 1) |> List.to_string()
        ],
        true
      )

    (p ++ m ++ q)
    |> IO.puts()
  end
end
