defmodule Gyx.Environments.Gridworld do
  alias Gyx.Core.{Env, Exp}
  alias Gyx.Core.Spaces.Discrete

  use Env
  use GenServer

  defstruct row: nil,
            col: nil,
            action_space: nil,
            observation_space: nil

  @type t :: %__MODULE__{
    row: integer(),
    col: integer(),
    action_space: Discrete.t(),
    observation_space: any()
  }

  @actions %{0 => :left, 1 => :down, 2 => :right, 3 => :up}
  @action_space Map.keys(@actions)

  @map [
      "_a_b_",
      "_____",
      "___B_",
      "_____",
      "_A___"
    ]

  @impl true
  def init(_) do
    {:ok,
     %__MODULE__{
       row: 0,
       col: 0,
       action_space: %Discrete{n: 4},
       observation_space: %Discrete{n: 0},
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

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
    printEnv(state)
    {:reply, {:ok, position: {state.row, state.col}}, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_env_state = %{state | row: 0, col: 0}
    {:reply, %Exp{next_state: new_env_state}, new_env_state}
  end


  defp reply(action, state, reward, next_state) do
    {:reply,
     %Exp{
       state: state,
       action: action,
       next_state: next_state,
       reward: reward,
       done: false,
       info: %{}
     }, next_state}
  end

  # a -> A
  def handle_call({:act, action = _}, _from, state = %{row: 0, col: 1}),
    do: reply(action, state, 10.0, %{state | row: 4, col: 1})

  # b -> B
  def handle_call({:act, action = _}, _from, state = %{row: 0, col: 3}),
    do: reply(action, state, 5.0, %{state | row: 3, col: 3})

  def handle_call({:act, action = :left}, _from, state = %{col: 0}),
    do: reply(action, state, -1.0, state)

  def handle_call({:act, action = :up}, _from, state = %{row: 0}),
    do: reply(action, state, -1.0, state)

  def handle_call({:act, action = :right}, _from, state = %{col: 4}),
    do: reply(action, state, -1.0, state)

  def handle_call({:act, action = :down}, _from, state = %{row: 4}),
    do: reply(action, state, -1.0, state)

  def handle_call({:act, action = :down}, _from, state = %{row: row, col: col}),
    do: reply(action, state, 0.0, %{state | row: row + 1, col: col})

  def handle_call({:act, action = :up}, _from, state = %{row: row, col: col}),
    do: reply(action, state, 0.0, %{state | row: row - 1, col: col})

  def handle_call({:act, action = :left}, _from, state = %{row: row, col: col}),
    do: reply(action, state, 0.0, %{state | row: row, col: col - 1})

  def handle_call({:act, action = :right}, _from, state = %{row: row, col: col}),
    do: reply(action, state, 0.0, %{state | row: row, col: col + 1})


  defp printEnv(state = %{row: row, col: col}) do
    Enum.with_index(@map)
    |> Enum.map(fn
      {line, line_idx} when line_idx == row ->
        mark_agent_position(line, col)
      {line, line_idx} -> line
    end)
    |> Enum.join("\n")
    |> IO.puts
  end

  defp mark_agent_position(string_line, col) do
    chars_line = String.graphemes(string_line)
    agent_string = "x" # TODO COLORS

    chars_lines
    |> List.update_at(col, fn _ -> agent_string end)
    |> to_string
  end
end
