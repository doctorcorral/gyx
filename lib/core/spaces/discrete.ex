defmodule Gyx.Core.Spaces.Discrete do
  use Agent

  defstruct n: 42, seed: nil

  @type t :: %__MODULE__{
          n: integer(),
          seed: {integer(), integer(), integer()}
        }

  def start_link(n) do
    Agent.start_link(fn -> %__MODULE__{n: n, seed: {1, 2, 3}} end, name: __MODULE__)
  end

  def n() do
    Agent.get(__MODULE__, &Map.get(&1, :n))
  end

  def seed(seed) do
    Agent.update(__MODULE__, &Map.put(&1, :seed, seed))
  end
end
