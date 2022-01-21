defmodule Gyx.Core.Spaces.Shared do
  @moduledoc """
  This module contains functions to be shared
  across all types considered by all Gyx.Core.Spaces protocols
  """
  def set_seed(%{random_algorithm: algo, seed: seed}) do
    :rand.seed(algo, seed)
  end
end
