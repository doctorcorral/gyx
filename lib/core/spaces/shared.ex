defmodule Gyx.Core.Spaces.Shared do
  @moduledoc false

  def set_seed(%{random_algorithm: algo, seed: seed}) do
    :rand.seed(algo, seed)
  end
end
