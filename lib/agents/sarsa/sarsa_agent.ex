defmodule Gyx.Agents.SARSA.Agent do
  defstruct Q: nil

  @type t :: %__MODULE__{
          Q: any()
        }

  def init(_) do
    {:ok,
      %__MODULE__{
        Q: Gyx.Qstorage.QGenServer,
      }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
  end

end
