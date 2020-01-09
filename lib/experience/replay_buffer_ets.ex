defmodule Gyx.Experience.ReplayBufferETS do
  @moduledoc """
  Implements ReplayMemory behaviour relying on ETS
  """
  alias Gyx.Core.ReplayMemory
  use GenServer
  use ReplayMemory

  @compile {:parse_transform, :ms_transform}
  @ets_name :__MODULE__

  def start_link(_, ops) do
    GenServer.start_link(__MODULE__, %{}, ops)
  end

  @impl true
  def init(_) do
    experiences =
      :ets.new(@ets_name, [:ordered_set, :public, :named_table, write_concurrency: true])

    {:ok, experiences}
  end

  def delete(replay_buffer, key) do
    GenServer.cast(replay_buffer, {:delete, key})
  end

  def get(replay_buffer, key) do
    GenServer.call(replay_buffer, {:get, key})
  end

  @doc """
  Adds a new experience to the reppay buffer
  """
  @impl true
  def add(replay_buffer, experience) do
    GenServer.cast(replay_buffer, {:add, experience})
  end

  @impl true
  def get_batch(replay_buffer, {n, sampling_strategy}) do
    GenServer.call(replay_buffer, {:get_batch, {n, sampling_strategy}})
  end

  def delete(replay_buffer), do: GenServer.cast(replay_buffer, :delete)

  @impl true
  def handle_cast(:delete, state) do
    :ets.delete(:__MODULE__)
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(:__MODULE__, key)
    {:noreply, state}
  end

  def handle_cast({:add, exp}, _state) do
    {:ok, timestamp_key} = DateTime.now("Etc/UTC")
    :ets.insert(@ets_name, {timestamp_key, exp})
    {:noreply, timestamp_key}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    reply =
      case :ets.lookup(@ets_name, key) do
        [] -> nil
        [{_timestamp, experience}] -> experience
      end

    {:reply, reply, state}
  end

  def handle_call({:get_batch, {n, :random}}, _from, state) do
    reply =
      @ets_name
      |> :ets.select(all_match_specification())
      |> Enum.shuffle()
      |> Enum.take(n)

    {:reply, reply, state}
  end

  def handle_call({:get_batch, {n, :latest}}, _from, state) do
    reply =
      @ets_name
      |> :ets.select(all_match_specification())
      |> Enum.sort_by(fn {d, _exp} -> {d.year, d.month, d.day, d.second, d.microsecond} end)
      |> Enum.take(-n)

    {:reply, reply, state}
  end

  defp all_match_specification, do: :ets.fun2ms(fn {k, v} -> {k, v} end)
end
