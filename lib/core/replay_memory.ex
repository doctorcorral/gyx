defmodule Gyx.Core.ReplayMemory do
  @moduledoc """
  This module defines the behaviour for a Replay Memory.
  The role of a Replay Memory is to store experiences coming from
  one or multiple agents when interacting with their environments.
  In this way, an agent can sample experiencess directly from a
  replay memory with different strategies that can improve learning
  convergence.
  """
  @type experience :: Gyx.Core.Exp.t()
  @type experiences :: list(experience)
  @type sampling_type :: :random | :latest
  @type batch_size :: integer()
  @type memory_process :: pid()

  @callback add(memory_process(), experience()) :: :ok

  @callback get_batch(
              memory_process(),
              {batch_size(), sampling_type()}
            ) :: experiences()

  defmacro __using__(_params) do
    quote do
      @behaviour Gyx.Core.ReplayMemory

      @enforce_keys [:replay_capacity]
    end
  end
end
