defmodule Gyx.Experience.ReplayBuffer do
  use GenServer
  alias Gyx.Core.Exp

  def start_link do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    :ets.new(:replay_buffer, [:duplicate_bag, :protected, :named_table])
    {:ok, state}
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def add(exp = %Exp{}) do
    GenServer.cast(__MODULE__, {:add, exp})
  end

  def handle_cast({:add, exp}, state) do
    {:ok, timestamp_key} = DateTime.now("Etc/UTC")
    :ets.insert(:replay_buffer, {timestamp_key, exp})
    {:noreply, state}
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(:replay_buffer, key)
    {:noreply, state}
  end

  def handle_call({:get, key}, _from, state) do
    reply =
      case :ets.lookup(:replay_buffer, key) do
        [] -> nil
        [{_timestamp, experience}] -> experience
      end

    {:reply, reply, state}
  end

end
