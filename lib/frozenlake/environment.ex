defmodule Gyx.FrozenLake.Environment do
  alias Gyx.Framework.Env
  @behaviour Env
  use GenServer
  alias Experience.Exp

  defstruct map: nil, x: nil, y: nil
  @type t :: %__MODULE__{map: charlist, x: integer, y: integer}

  @actions  %{0 => :left, 1 => :down, 2 => :right, 3 => :up}
  @action_space  Map.keys(@actions)

  @maps  %{
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
  def init(map \\ "4x4") do
    {:ok, %__MODULE__{map: map, x: 0, y: 0}}
  end

  @impl Env
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  @impl true
  def handle_call(:reset, _from, state) do
    new_env_state = %{state | x: 0, y: 0}
    {:reply, %Exp{}, new_env_state}
  end
end
