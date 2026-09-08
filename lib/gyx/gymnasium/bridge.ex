defmodule Gyx.Gymnasium.Bridge do
  @moduledoc """
  Long-lived Python port that owns real Gymnasium envs.

  Used by `gymnasium/*` ids (MuJoCo C and `ALE/*` Atari) so Elixir
  trainers see the same transitions as `gymnasium.make` in Python.
  """

  use GenServer

  @script "priv/python/gymnasium_bridge.py"

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def ensure_started do
    case Process.whereis(__MODULE__) do
      nil ->
        case GenServer.start(__MODULE__, [], name: __MODULE__) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end

      pid ->
        {:ok, pid}
    end
  end

  def available? do
    match?(%{"ok" => true}, ping())
  end

  def capabilities do
    case ping() do
      %{"ok" => true} = reply ->
        %{mujoco: reply["mujoco"] == true, atari: reply["atari"] == true}

      _ ->
        %{mujoco: false, atari: false}
    end
  end

  defp ping do
    case ensure_started() do
      {:ok, _} -> request(%{op: "ping"}, 5_000)
      _ -> {:error, :unavailable}
    end
  end

  def make(gym_id, opts \\ []) do
    render? = Keyword.get(opts, :render, false)
    request(%{op: "make", id: gym_id, render: render?})
  end

  def reset(handle, seed) do
    req = %{op: "reset", handle: handle}
    req = if seed == nil, do: req, else: Map.put(req, :seed, seed)
    request(req)
  end

  def step(handle, action) when is_list(action) or is_integer(action) or is_float(action) do
    request(%{op: "step", handle: handle, action: action})
  end

  def render(handle), do: request(%{op: "render", handle: handle})
  def close(handle), do: request(%{op: "close", handle: handle})

  def replay(gym_id, seed, actions) do
    request(%{op: "replay", id: gym_id, seed: seed, actions: actions}, 30_000)
  end

  defp request(map, timeout \\ 30_000) do
    {:ok, _} = ensure_started()
    GenServer.call(__MODULE__, {:req, map}, timeout + 200)
  end

  @impl true
  def init(_opts) do
    python = System.find_executable("python3") || System.find_executable("python")
    script = script_path()

    cond do
      python == nil ->
        {:stop, :no_python}

      not File.exists?(script) ->
        {:stop, :missing_bridge}

      true ->
        port =
          Port.open(
            {:spawn_executable, python},
            [
              :binary,
              :exit_status,
              :use_stdio,
              :hide,
              {:packet, 4},
              {:args, [script]}
            ]
          )

        case await_data(port, 20_000) do
          {:ok, %{"ok" => true, "op" => "ready"}} ->
            {:ok, %{port: port, pending: nil}}

          {:ok, %{"ok" => false, "error" => err}} ->
            Port.close(port)
            {:stop, {:import_failed, err}}

          other ->
            Port.close(port)
            {:stop, {:bridge_boot, other}}
        end
    end
  end

  @impl true
  def handle_call({:req, map}, from, %{pending: nil} = state) do
    true = Port.command(state.port, Jason.encode!(map))
    {:noreply, %{state | pending: from}, 30_000}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port, pending: from} = state) when from != nil do
    GenServer.reply(from, decode(data))
    {:noreply, %{state | pending: nil}}
  end

  def handle_info({port, {:exit_status, code}}, %{port: port} = state) do
    if state.pending, do: GenServer.reply(state.pending, {:error, {:bridge_exit, code}})
    {:stop, {:port_exit, code}, %{state | pending: nil}}
  end

  def handle_info(:timeout, state) do
    if state.pending, do: GenServer.reply(state.pending, {:error, :timeout})
    {:noreply, %{state | pending: nil}}
  end

  @impl true
  def terminate(_reason, %{port: port}) do
    Port.close(port)
    :ok
  end

  defp decode(data) do
    case Jason.decode(data) do
      {:ok, map} -> map
      {:error, _} -> {:error, :bad_json}
    end
  end

  defp await_data(port, timeout) do
    receive do
      {^port, {:data, data}} -> {:ok, decode(data)}
      {^port, {:exit_status, code}} -> {:error, {:exit, code}}
    after
      timeout -> {:error, :timeout}
    end
  end

  defp script_path do
    case :code.priv_dir(:gyx) do
      {:error, _} -> Path.expand(@script)
      dir -> Path.join(dir, "python/gymnasium_bridge.py")
    end
  end
end
