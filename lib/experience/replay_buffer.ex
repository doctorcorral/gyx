defmodule Gyx.Experience.ReplayBuffer do
  use GenServer
  alias Gyx.Core.Exp

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

  def add(exp = %Exp{}) do
    GenServer.call(__MODULE__, {:add, exp})
  end

  @spec get_batch(integer()) :: list(Exp.t())
  def get_batch(n) do
    GenServer.call(__MODULE__, {:get_batch, n})
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

  def handle_call({:get_batch, _n}, _from, state) do
    reply = :ets.match(:replay_buffer, {:_, "$2"})
    {:reply, reply, state}
  end
end
