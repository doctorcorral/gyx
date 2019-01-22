defmodule Gyx.Framework.Runner do
  # Bridge function for running agent's `begin_episode`
  @callback initialize_episode() :: any()
end
