defmodule Gyx.Core.ReplayMemory do
  @moduledoc """
  Behaviour for experience replay buffers.
  """

  @type experience :: Gyx.Core.Exp.t()
  @type experiences :: [experience]
  @type sampling_type :: :random | :latest
  @type batch_size :: pos_integer()
  @type memory_process :: pid()

  @callback add(memory_process(), experience()) :: :ok
  @callback get_batch(memory_process(), {batch_size(), sampling_type()}) :: experiences()
end
