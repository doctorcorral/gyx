defmodule Gyx.Core.Runner do
  @moduledoc """
  This Behaivour describes necesary interfaces
  between environment and agent(s) to be performed when
  running an experiment
  """

  @doc """
  Bridge function for running agent's `begin_episode`
  """
  @callback initialize_episode() :: any()
end
