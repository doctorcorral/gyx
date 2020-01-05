defmodule Gyx.Qstorage.QGenServer do
  @moduledoc """
  This module is intended to be used as a Q table representation.
  It is based on a single GenServer process, using a Map to hold Q table data
  as part of process state.
  Note that this is a hand made version of an Agent OTP implementation,
  which would be preferable that this.
  """
  use GenServer

  @heatmap_color :color8

  defstruct state_value_table: %{}, actions: nil
  @type t :: %__MODULE__{state_value_table: %{}, actions: MapSet.t()}

  def init(_) do
    {:ok, %__MODULE__{state_value_table: %{}, actions: MapSet.new()}}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def q_get(qgenserver, env_state, action) do
    GenServer.call(qgenserver, {:q_get, {env_state, action}})
  end

  def q_set(qgenserver, env_state, action, value) do
    GenServer.call(qgenserver, {:q_set, {env_state, action, value}})
  end

  def get_q(qgenserver) do
    GenServer.call(qgenserver, :get_q)
  end

  def get_q_matrix(qgenserver) do
    GenServer.call(qgenserver, :get_q_matrix)
  end

  def print_q_matrix(qgenserver) do
    GenServer.call(qgenserver, :print_q_matrix)
  end

  def get_max_action(qgenserver, env_state) do
    GenServer.call(qgenserver, {:get_max_action, env_state})
  end

  def handle_call(:get_q, _from, state = %__MODULE__{}),
    do: {:reply, state.state_value_table, state}

  def handle_call(:get_q_matrix, _from, state = %__MODULE__{}) do
    {:reply,
     map_to_matrix(
       state.state_value_table,
       MapSet.size(state.actions)
     ), state}
  end

  def handle_call(:print_q_matrix, _from, state = %__MODULE__{}) do
    map_to_matrix(
      state.state_value_table,
      MapSet.size(state.actions)
    )

    @heatmap_color
    |> Matrex.heatmap()
    |> (fn _ -> :ok end).()

    {:reply, :ok, state}
  end

  def handle_call(
        {:q_get, {env_state, action}},
        _from,
        state = %__MODULE__{}
      ) do
    expected_reward = state.state_value_table[inspect(env_state)][action]
    {:reply, if(expected_reward, do: expected_reward, else: 0.0), state}
  end

  def handle_call(
        {:q_set, {env_state, action, value}},
        _from,
        state = %__MODULE__{actions: actions}
      ) do
    k_state = inspect(env_state)

    state = %{
      state
      | state_value_table: Map.put_new_lazy(state.state_value_table, k_state, fn -> %{} end),
        actions: MapSet.put(actions, action)
    }

    new_state =
      Map.put(
        state.state_value_table,
        k_state,
        Map.put(state.state_value_table[k_state], action, value)
      )

    {:reply, new_state,
     %{
       state
       | state_value_table: new_state,
         actions: MapSet.put(actions, action)
     }}
  end

  def handle_call(
        {:get_max_action, env_state},
        _from,
        state = %__MODULE__{}
      ) do
    k_state = inspect(env_state)

    state = %{
      state
      | state_value_table: Map.put_new_lazy(state.state_value_table, k_state, fn -> %{} end)
    }

    with [{action, _}] <-
           state.state_value_table[k_state]
           |> Enum.sort_by(fn {_, v} -> v end, &>=/2)
           |> Enum.take(1) do
      {:reply, {:ok, action}, state}
    else
      _ -> {:reply, {:error, "Environment state has not been observed."}, state}
    end
  end

  defp map_to_matrix(_, actions_size) when actions_size < 2 do
    Matrex.new([[0, 0], [0, 0]])
  end

  defp map_to_matrix(map_state_value_table, actions_size) do
    map_state_value_table
    |> Map.values()
    |> Enum.map(fn vs -> Map.values(vs) end)
    |> Enum.filter(&(length(&1) == actions_size))
    |> (fn l ->
          if length(l) < actions_size do
            [[0, 0], [0, 0]]
          else
            l
          end
        end).()
    |> Matrex.new()
  end
end
