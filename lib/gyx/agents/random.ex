defmodule Gyx.Agents.Random do
  @moduledoc """
  Samples uniformly from an environment action space.
  """

  alias Gyx.Core.Spaces

  defstruct []

  @type t :: %__MODULE__{}

  def new(_opts \\ []), do: %__MODULE__{}

  @spec act(t(), term(), Spaces.space()) :: term()
  def act(_agent, _observation, action_space) do
    {:ok, action} = Spaces.sample(action_space)
    action
  end
end
