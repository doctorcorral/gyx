defmodule Gyx.Envs.FrozenLake do
  @moduledoc """
  FrozenLake-v1, matching Gymnasium's grid, actions, and slip model.

  Actions: `0` left, `1` down, `2` right, `3` up. Observation is the
  flattened cell index `row * ncol + col`. When `is_slippery` is true
  (the default), the agent slips to a perpendicular direction with
  probability `1/3` each.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Discrete
  alias Gyx.RNG

  @maps %{
    "4x4" => [
      ~c"SFFF",
      ~c"FHFH",
      ~c"FFFH",
      ~c"HFFG"
    ],
    "8x8" => [
      ~c"SFFFFFFF",
      ~c"FFFFFFFF",
      ~c"FFFHFFFF",
      ~c"FFFFFHFF",
      ~c"FFFHFFFF",
      ~c"FHHFFFHF",
      ~c"FHFFHFHF",
      ~c"FFFHFFFG"
    ]
  }

  defstruct map: nil,
            map_name: "4x4",
            row: 0,
            col: 0,
            nrow: 4,
            ncol: 4,
            is_slippery: true,
            steps: 0,
            last_action: nil,
            last_applied: nil,
            rng: nil,
            max_episode_steps: 100,
            action_space: %Discrete{n: 4},
            observation_space: %Discrete{n: 16}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "FrozenLake-v1",
      observation_space: %Discrete{n: 16},
      action_space: %Discrete{n: 4},
      max_episode_steps: 100,
      reward_threshold: 0.7
    }
  end

  @impl true
  def new(opts \\ []) do
    map_name = opts |> Keyword.get(:map_name, "4x4") |> to_string()
    grid = opts |> Keyword.get(:map) |> Kernel.||(Map.fetch!(@maps, map_name)) |> normalize_map()
    nrow = length(grid)
    ncol = length(hd(grid))
    max_steps = Keyword.get(opts, :max_episode_steps, if(nrow == 8, do: 200, else: 100))

    env = %__MODULE__{
      map: grid,
      map_name: map_name,
      row: 0,
      col: 0,
      nrow: nrow,
      ncol: ncol,
      is_slippery: Keyword.get(opts, :is_slippery, true),
      steps: 0,
      last_action: nil,
      max_episode_steps: max_steps,
      action_space: %Discrete{n: 4},
      observation_space: %Discrete{n: nrow * ncol}
    }

    env |> reset(opts) |> elem(0)
  end

  @impl true
  def reset(env, opts \\ []) do
    rng = next_rng(env, opts)
    {srow, scol} = start_cell(env.map)
    env = %{env | row: srow, col: scol, steps: 0, last_action: nil, last_applied: nil, rng: rng}
    {env, observe(env), %{prob: 1.0}}
  end

  @impl true
  def observe(%__MODULE__{row: row, col: col, ncol: ncol}), do: row * ncol + col

  @impl true
  def step(env, action) do
    if Gyx.Core.Spaces.contains?(env.action_space, action) do
      do_step(env, action)
    else
      {:error, :invalid_action}
    end
  end

  @impl true
  def params(%__MODULE__{} = env) do
    [
      %{key: :is_slippery, type: :boolean, value: env.is_slippery},
      %{key: :map_name, type: :choice, value: env.map_name, choices: ["4x4", "8x8"]}
    ]
  end

  @impl true
  def configure(%__MODULE__{} = env, opts) do
    slippery? = Keyword.get(opts, :is_slippery, env.is_slippery)
    map_name = opts |> Keyword.get(:map_name, env.map_name) |> to_string()

    if map_name != env.map_name do
      new(Keyword.merge(opts, is_slippery: slippery?, map_name: map_name))
    else
      %{env | is_slippery: slippery?}
    end
  end

  @impl true
  def render(env, :svg), do: {:ok, Gyx.Render.FrozenLake.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.FrozenLake.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  @doc "Cell character at the agent position: ?S, ?F, ?H, or ?G."
  def cell(%__MODULE__{map: map, row: row, col: col}), do: enum_at2(map, row, col)

  defp do_step(env, action) do
    obs = observe(env)
    {applied, rng} = slipped_action(env, action)
    {row, col} = move(env.row, env.col, env.nrow, env.ncol, applied)

    env = %{
      env
      | row: row,
        col: col,
        steps: env.steps + 1,
        last_action: action,
        last_applied: applied,
        rng: rng
    }

    tile = cell(env)
    terminated = tile in [?H, ?G]
    reward = if tile == ?G, do: 1.0, else: 0.0
    truncated = not terminated and env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: action,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{
         prob: if(env.is_slippery, do: 1 / 3, else: 1.0),
         tile: tile,
         applied_action: applied
       }
     }}
  end

  defp normalize_map(rows) do
    Enum.map(rows, fn
      row when is_binary(row) -> String.to_charlist(row)
      row when is_list(row) -> row
    end)
  end

  defp next_rng(env, opts) do
    case Keyword.fetch(opts, :seed) do
      {:ok, seed} -> RNG.seed(seed)
      :error -> env.rng || RNG.seed(nil)
    end
  end

  defp slipped_action(%{is_slippery: false, rng: rng}, action), do: {action, rng}

  defp slipped_action(%{is_slippery: true, rng: rng}, action) do
    {k, rng} = RNG.int(rng, 0, 2)
    {rem(action + k + 3, 4), rng}
  end

  @doc false
  def action_name(0), do: "Left"
  def action_name(1), do: "Down"
  def action_name(2), do: "Right"
  def action_name(3), do: "Up"
  def action_name(_), do: "?"

  # 0 left, 1 down, 2 right, 3 up
  defp move(row, col, _nrow, _ncol, 0), do: {row, max(col - 1, 0)}
  defp move(row, col, nrow, _ncol, 1), do: {min(row + 1, nrow - 1), col}
  defp move(row, col, _nrow, ncol, 2), do: {row, min(col + 1, ncol - 1)}
  defp move(row, col, _nrow, _ncol, 3), do: {max(row - 1, 0), col}

  defp start_cell(map) do
    map
    |> Enum.with_index()
    |> Enum.find_value(fn {line, row} ->
      case Enum.find_index(line, &(&1 == ?S)) do
        nil -> nil
        col -> {row, col}
      end
    end) || {0, 0}
  end

  defp enum_at2(map, row, col), do: map |> Enum.at(row) |> Enum.at(col)
end
