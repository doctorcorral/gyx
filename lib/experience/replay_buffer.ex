defmodule Gyx.Experience.ReplayBufferETS do
  @moduledoc """
  Implements ReplayMemory behaviour relying on ETS
  """
  alias Gyx.Core.ReplayMemory
  use GenServer
  use ReplayMemory

  @compile {:parse_transform, :ms_transform}

  def start_link(_, ops) do
    GenServer.start_link(__MODULE__, %{}, ops)
  end

  def init(_) do
    experiences = :ets.new(:replay_buffer, [:set, :protected, :named_table])
    {:ok, experiences}
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  @doc """
  Adds a new experience to the reppay buffer
  """
  @spec add(Gyx.Core.Exp.t()) :: any()
  def add(experience) do
    GenServer.call(__MODULE__, {:add, experience})
  end

  def get_batch({n, sampling_strategy}) do
    GenServer.call(__MODULE__, {:get_batch, {n, sampling_strategy}})
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(:replay_buffer, key)
    {:noreply, state}
  end

  def handle_call({:add, exp}, _from, state) do
    {:ok, timestamp_key} = DateTime.now("Etc/UTC")
    :ets.insert(:replay_buffer, {timestamp_key, exp})
    {:reply, timestamp_key, state}
  end

  def handle_call({:get, key}, _from, state) do
    reply =
      case :ets.lookup(:replay_buffer, key) do
        [] -> nil
        [{_timestamp, experience}] -> experience
      end

    {:reply, reply, state}
  end

  def handle_call({:get_batch, {n, :random}}, _from, state) do
    fun = :ets.fun2ms(fn {_k, v} -> v end)

    reply =
      :replay_buffer
      |> :ets.select(fun)
      |> Enum.shuffle()
      |> Enum.take(n)

    {:reply, reply, state}
  end
end
