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

  defstruct map: nil, row: nil, col: nil
  @type t :: %__MODULE__{map: list(charlist), row: integer, col: integer}

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
    {:ok, %__MODULE__{map: @maps[map_name], row: 0, col: 0}}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
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
    new_env_state = %{state | row: min(state.row + 1, nrow(state.map) - 1)}
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

  defp nrow(map), do: length(map)
  defp ncol([head | rest]), do: length(head)
end
