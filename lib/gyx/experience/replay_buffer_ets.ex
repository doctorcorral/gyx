defmodule Gyx.Experience.ReplayBufferETS do
  @moduledoc """
  ETS-backed replay buffer implementing `Gyx.Core.ReplayMemory`.
  """

  use GenServer
  @behaviour Gyx.Core.ReplayMemory

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, Keyword.take(opts, [:name]))
  end

  @impl Gyx.Core.ReplayMemory
  def add(buffer, experience), do: GenServer.cast(buffer, {:add, experience})

  @impl Gyx.Core.ReplayMemory
  def get_batch(buffer, {n, strategy}), do: GenServer.call(buffer, {:get_batch, {n, strategy}})

  def size(buffer), do: GenServer.call(buffer, :size)

  @impl true
  def init(opts) do
    capacity = Keyword.get(opts, :capacity, 10_000)
    tid = :ets.new(__MODULE__, [:ordered_set, :public])
    {:ok, %{tid: tid, seq: 0, capacity: capacity}}
  end

  @impl true
  def handle_cast({:add, experience}, %{tid: tid, seq: seq, capacity: capacity} = state) do
    :ets.insert(tid, {seq, experience})

    if seq >= capacity do
      :ets.delete(tid, seq - capacity)
    end

    {:noreply, %{state | seq: seq + 1}}
  end

  @impl true
  def handle_call({:get_batch, {n, :random}}, _from, %{tid: tid} = state) do
    {:reply, tid |> all() |> Enum.shuffle() |> Enum.take(n), state}
  end

  def handle_call({:get_batch, {n, :latest}}, _from, %{tid: tid} = state) do
    {:reply, tid |> all() |> Enum.take(-n), state}
  end

  def handle_call(:size, _from, %{tid: tid} = state) do
    {:reply, :ets.info(tid, :size), state}
  end

  defp all(tid) do
    :ets.select(tid, [{{:"$1", :"$2"}, [], [:"$2"]}])
  end
end
