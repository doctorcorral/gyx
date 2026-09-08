defmodule Gyx.Env.Server do
  @moduledoc """
  GenServer wrapper around a functional `Gyx.Env` struct.

  Useful when a LiveView, trainer, or remote node should share one env.
  """

  use GenServer

  alias Gyx.Core.Exp

  @type state :: %{env: Gyx.Env.t()}

  def start_link(env, opts \\ []) when is_struct(env) do
    GenServer.start_link(__MODULE__, env, Keyword.take(opts, [:name]))
  end

  def reset(pid, opts \\ []), do: GenServer.call(pid, {:reset, opts})
  def step(pid, action), do: GenServer.call(pid, {:step, action})
  def observe(pid), do: GenServer.call(pid, :observe)
  def render(pid, mode \\ :svg), do: GenServer.call(pid, {:render, mode})
  def get(pid), do: GenServer.call(pid, :get)

  @impl true
  def init(env), do: {:ok, %{env: env}}

  @impl true
  def handle_call({:reset, opts}, _from, %{env: %mod{} = env}) do
    {env, obs, info} = mod.reset(env, opts)
    {:reply, {env, obs, info}, %{env: env}}
  end

  def handle_call({:step, action}, _from, %{env: %mod{} = env}) do
    case mod.step(env, action) do
      {:ok, env, %Exp{} = exp} -> {:reply, {:ok, env, exp}, %{env: env}}
      {:error, reason} -> {:reply, {:error, reason}, %{env: env}}
    end
  end

  def handle_call(:observe, _from, %{env: %mod{} = env} = state) do
    {:reply, mod.observe(env), state}
  end

  def handle_call({:render, mode}, _from, %{env: %mod{} = env} = state) do
    {:reply, mod.render(env, mode), state}
  end

  def handle_call(:get, _from, %{env: env} = state), do: {:reply, env, state}
end
