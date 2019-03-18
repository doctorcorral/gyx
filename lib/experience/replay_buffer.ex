defmodule Gyx.Experience.ReplayBuffer do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__,%{})
  end

  def init(state) do
    :ets.new(:replay_buffer, [:duplicate_bag, :protected, :named_table])
    {:ok, state}
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  def handle_cast({:delete, key}, state) do
    :ets.delete(:replay_buffer, key)
    {:noreply, state}
  end
end
