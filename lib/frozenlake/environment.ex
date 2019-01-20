defmodule Gyx.FrozenLake.Environment do
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

  @impl Env
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_env_state = %{state | row: 0, col: 0}
    {:reply, %Exp{}, new_env_state}
  end
end
