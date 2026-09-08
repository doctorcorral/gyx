defmodule GyxUI.EnvLive do
  @moduledoc false
  use Phoenix.LiveView

  import Phoenix.HTML, only: [raw: 1]

  alias Gyx.{Agent, Experiment, Session}
  alias Gyx.Agents.Random
  alias Gyx.Trainers.Presets

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(
       id: "CartPole-v1",
       backend: backend_info("CartPole-v1"),
       algo: "q_learning",
       playing: false,
       delay: 80,
       last_exp: nil,
       session: nil,
       actions: [],
       atari_pad: nil,
       agent: nil,
       message: nil,
       train_seq: 0,
       mode: :svg,
       scene: nil,
       sliders: [],
       svg: ""
     )
     |> clear_learn()
     |> boot("CartPole-v1")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="app" class="app" phx-hook="Shortcuts">
      <header class="topbar">
        <div class="brand">
          <img src="/images/gyx-mark.png" alt="gyx" class="logo" />
          <div class="brand-copy">
            <span class="product">Playground</span>
            <span class="tag">Reinforcement Learning ▸ Elixir</span>
          </div>
        </div>
        <div class="pickers">
          <label class="field">
            <span>Environment</span>
            <form id="env-select" phx-change="select">
              <select name="id" aria-label="Environment">
                <optgroup :for={{group, items} <- catalog_groups()} label={group}>
                  <option :for={{label, id} <- items} value={id} selected={id == @id}>{label}</option>
                </optgroup>
              </select>
            </form>
          </label>
          <label class="field">
            <span>Algorithm</span>
            <form id="algo-select" phx-change="algo">
              <select name="algo" aria-label="Algorithm">
                <option :for={{label, algo} <- algorithms()} value={algo} selected={algo == @algo}>
                  {label}
                </option>
              </select>
            </form>
          </label>
        </div>
        <div class="top-actions">
          <button type="button" id="theme-toggle" class="icon-btn" phx-hook="Theme">
            <svg class="icon-moon" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M21 14.5A8.5 8.5 0 0 1 9.5 3 7 7 0 1 0 21 14.5z" />
            </svg>
            <svg class="icon-sun" viewBox="0 0 24 24" aria-hidden="true">
              <circle cx="12" cy="12" r="4" />
              <path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6l1.4 1.4M17 17l1.4 1.4M18.4 5.6 17 7M7 17l-1.4 1.4" />
            </svg>
          </button>
        </div>
      </header>

      <div class="workspace">
        <section class="viewport">
          <div class="viewport-chrome">
            <div class="chips">
              <span class={"chip backend-" <> to_string(@backend.kind)}>
                {@backend.short}
              </span>
              <span class="chip">{@backend.engine}</span>
              <span class="chip">{viewport_label(@mode)}</span>
              <span class="chip">{@id}</span>
              <span :if={@agent} class="chip policy">Trained {algo_label(@algo)}</span>
              <span :if={!@agent} class="chip">Random policy</span>
            </div>
            <div class="chips">
              <span class={"chip " <> status_class(@terminated, @truncated)}>
                {status(@terminated, @truncated)}
              </span>
            </div>
          </div>
          <div
            :if={@mode == :scene}
            id="scene3d"
            phx-hook="Scene3D"
            data-scene={Jason.encode!(@scene)}
            class="stage stage-3d"
          >
            <canvas id="scene3d-canvas" phx-update="ignore"></canvas>
          </div>
          <div :if={@mode == :frame} class="stage stage-atari">{raw(@svg)}</div>
          <div :if={@mode == :svg} class="stage stage-2d">{raw(@svg)}</div>
          <p :if={@mode == :scene} class="viewport-hint">Drag to orbit the camera</p>
          <p :if={@mode == :frame} class="viewport-hint">Arcade frame from ALE · sticky actions on</p>
        </section>

        <aside class="rail">
          <section class="card backend-card">
            <h2>Backend</h2>
            <p class="backend-title">{@backend.title}</p>
            <p>{@backend.summary}</p>
            <div class="backend-meta">
              <div><span class="k">Runs</span><span class="v">{@backend.engine}</span></div>
              <div><span class="k">Transfer</span><span class="v">{@backend.transfer}</span></div>
              <div><span class="k">Id</span><span class="v">{@id}</span></div>
            </div>
            <div :if={length(backend_siblings(@id)) > 1} class="backend-switch" role="group" aria-label="Switch physics backend">
              <button
                :for={sib <- backend_siblings(@id)}
                type="button"
                class={if sib.id == @id, do: "btn active", else: "btn"}
                phx-click="select"
                phx-value-id={sib.id}
                aria-pressed={sib.id == @id}
                title={sib.title}
              >
                {sib.short}
              </button>
            </div>
          </section>

          <section class="card">
            <h2>Episode</h2>
            <div class="controls">
              <button class="btn" phx-click="reset">Reset</button>
              <button class="btn" phx-click="random" disabled={@done}>Random</button>
              <button class={if @playing, do: "btn active", else: "btn"} phx-click="toggle">
                {if @playing, do: "Pause", else: "Autoplay"}
              </button>
              <button
                class={if available?(@algo, @id), do: "btn primary", else: "btn"}
                phx-click="train"
                disabled={@training or not available?(@algo, @id)}
                title={
                  if available?(@algo, @id),
                    do: "Train #{algo_label(@algo)} on #{@id}",
                    else: "#{algo_label(@algo)} has no preset for #{@id}"
                }
              >
                {if @training, do: "Training…", else: "Train #{algo_label(@algo)}"}
              </button>
            </div>
            <div :if={@id == "FrozenLake-v1"} class="dpad" style="margin-top:0.65rem">
              <button class="up" phx-click="act" phx-value-action="3" disabled={@done}>Up</button>
              <button class="left" phx-click="act" phx-value-action="0" disabled={@done}>Left</button>
              <button class="right" phx-click="act" phx-value-action="2" disabled={@done}>Right</button>
              <button class="down" phx-click="act" phx-value-action="1" disabled={@done}>Down</button>
            </div>
            <div :if={@atari_pad} class="atari-controls">
              <div :if={@atari_pad.stick?} class="dpad">
                <button :if={@atari_pad.up} class="up" phx-click="act" phx-value-action={@atari_pad.up} disabled={@done}>Up</button>
                <button :if={@atari_pad.left} class="left" phx-click="act" phx-value-action={@atari_pad.left} disabled={@done}>Left</button>
                <button :if={@atari_pad.right} class="right" phx-click="act" phx-value-action={@atari_pad.right} disabled={@done}>Right</button>
                <button :if={@atari_pad.down} class="down" phx-click="act" phx-value-action={@atari_pad.down} disabled={@done}>Down</button>
              </div>
              <button
                :if={@atari_pad.fire}
                class="btn primary"
                phx-click="act"
                phx-value-action={@atari_pad.fire}
                disabled={@done}
              >
                FIRE
              </button>
              <div :if={@atari_pad.extras != []} class="controls">
                <button
                  :for={{label, action} <- @atari_pad.extras}
                  class="btn"
                  phx-click="act"
                  phx-value-action={action}
                  disabled={@done}
                >
                  {label}
                </button>
              </div>
            </div>
            <div :if={@atari_pad == nil and @actions != []} class="controls" style="margin-top:0.65rem">
              <button
                :for={{label, action} <- @actions}
                class="btn"
                phx-click="act"
                phx-value-action={action}
                disabled={@done}
              >
                {label}
              </button>
            </div>
            <p class="kbd"><kbd>R</kbd> reset · <kbd>N</kbd> random · <kbd>Space</kbd> autoplay</p>
          </section>

          <section :if={@sliders != []} class="card">
            <h2>Actuators</h2>
            <form id="act-sliders" class="sliders" phx-change="act_vec">
              <label :for={slider <- @sliders} class="slider">
                <span>{slider.label} <span class="val">{fmt_num(slider.value)}</span></span>
                <input
                  type="range"
                  name={"a#{slider.index}"}
                  min={slider.min}
                  max={slider.max}
                  step="0.05"
                  value={slider.value}
                  disabled={@done}
                />
              </label>
            </form>
          </section>

          <section :if={@params != []} class="card params">
            <h2>Parameters</h2>
            <form id="env-params" phx-change="params">
              <label :for={param <- @params} class="param">
                <span class="key">{param.key}</span>
                <input :if={param.type == :boolean} type="hidden" name={param.key} value="false" />
                <input
                  :if={param.type == :boolean}
                  type="checkbox"
                  name={param.key}
                  value="true"
                  checked={param.value}
                />
                <select :if={param.type == :choice} name={param.key}>
                  <option :for={choice <- param.choices} value={choice} selected={choice == param.value}>
                    {choice}
                  </option>
                </select>
              </label>
            </form>
          </section>

          <section :if={@training or @train_curve != []} class="card learn">
            <div class="learn-head">
              <h2>Learning</h2>
              <span>
                {if @train_episodes > 0, do: "ep #{@train_episode}/#{@train_episodes}", else: "starting"}
                {if @train_mean, do: " · mean #{fmt_num(@train_mean)}", else: ""}
                {if @train_last, do: " · last #{fmt_num(@train_last)}", else: ""}
              </span>
            </div>
            <div
              class="meter"
              role="progressbar"
              aria-label="Training completion"
              aria-valuemin="0"
              aria-valuemax="100"
              aria-valuenow={@train_pct}
            >
              <div class="meter-fill" style={"width: #{@train_pct}%"}></div>
            </div>
            <div :if={@train_curve != []} class="curve">
              {raw(curve_svg(@train_curve, @train_smooth))}
              <div class="learn-legend">
                <span><i class="raw"></i>return</span>
                <span><i class="avg"></i>rolling mean</span>
              </div>
            </div>
          </section>

          <section class="card">
            <h2>Telemetry</h2>
            <div class="stats">
              <div class="stat wide">
                <span>backend</span>
                <strong>{@backend.title}</strong>
              </div>
              <div class="stat wide">
                <span>observation</span>
                <strong>{fmt_obs(@obs)}</strong>
              </div>
              <div class="stat"><span>reward</span><strong>{fmt_reward(@last_exp)}</strong></div>
              <div class="stat"><span>return</span><strong>{fmt_num(@return)}</strong></div>
              <div class="stat wide">
                <span>status</span>
                <strong class={if @done, do: "done"}>{status(@terminated, @truncated)}</strong>
              </div>
            </div>
          </section>

          <p :if={@message} class="card message">{@message}</p>
        </aside>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select", %{"id" => id}, socket),
    do:
      {:noreply,
       socket
       |> assign(agent: nil, algo: keep_or_fallback(socket.assigns.algo, id))
       |> bump_train()
       |> clear_learn()
       |> boot(id, default_env_opts(id))}

  def handle_event("algo", %{"algo" => algo}, socket) do
    {:noreply,
     socket
     |> assign(algo: algo, agent: nil, message: nil)
     |> bump_train()
     |> clear_learn()}
  end

  def handle_event("params", raw, socket) do
    opts = cast_params(socket.assigns.params, raw)
    session = Session.configure(socket.assigns.session, opts)
    map_changed? = env_map_changed?(socket.assigns.env, session.env)

    session = if map_changed?, do: Session.reset(session), else: session

    {:noreply,
     socket
     |> assign_session(session)
     |> assign(
       params: Session.params(session),
       playing: if(map_changed?, do: false, else: socket.assigns.playing)
     )
     |> assign_view(session)}
  end

  def handle_event("reset", _params, socket) do
    {:noreply, socket |> assign(playing: false, agent: socket.assigns.agent) |> reset_env()}
  end

  def handle_event("random", _params, socket) do
    {:noreply,
     apply_action(
       socket,
       Random.act(%Random{}, socket.assigns.obs, socket.assigns.env.action_space)
     )}
  end

  def handle_event("act", %{"action" => action}, socket) do
    {:noreply, apply_action(socket, parse_action(action))}
  end

  def handle_event("act_vec", params, socket) do
    action =
      socket.assigns.sliders
      |> Enum.map(fn slider -> parse_float(Map.get(params, "a#{slider.index}"), slider.value) end)
      |> List.to_tuple()

    {:noreply,
     socket
     |> assign(sliders: put_slider_values(socket.assigns.sliders, action))
     |> apply_action(action)}
  end

  def handle_event("toggle", _params, socket) do
    playing? = not socket.assigns.playing

    if playing? and not socket.assigns.done do
      send(self(), :tick)
    end

    {:noreply, assign(socket, playing: playing? and not socket.assigns.done)}
  end

  def handle_event("train", _params, socket) do
    id = socket.assigns.id
    algo = socket.assigns.algo

    if not available?(algo, id) do
      {:noreply, assign(socket, message: "#{algo_label(algo)} has no preset for #{id}")}
    else
      train_async(socket, id, algo)
    end
  end

  defp train_async(socket, id, algo) do
    pid = self()
    socket = bump_train(socket)
    seq = socket.assigns.train_seq

    Task.start(fn ->
      exp = Experiment.new(env: id, algo: algo)
      episodes = exp.episodes || 500
      stride = max(1, div(episodes, 80))

      send(pid, {:train_progress, id, algo, seq, empty_payload(episodes)})

      result =
        Experiment.run(exp,
          on_progress: fn info ->
            if info.episode == info.episodes or rem(info.episode, stride) == 0 do
              send(pid, {:train_progress, id, algo, seq, progress_payload(info)})
            end
          end
        )

      send(
        pid,
        {:trained, id, algo, seq, result.agent, result.eval_return, result.episodes,
         final_payload(result.returns, result.episodes)}
      )
    end)

    {:noreply,
     socket
     |> clear_learn()
     |> assign(
       training: true,
       playing: false,
       message: "Training #{algo_label(algo)} on #{id}…"
     )}
  end

  @impl true
  def handle_info({:train_progress, id, algo, seq, payload}, socket) do
    if stale_train?(socket, id, algo, seq) do
      {:noreply, socket}
    else
      {:noreply, assign_learn(socket, payload)}
    end
  end

  def handle_info({:trained, id, algo, seq, agent, avg, episodes, payload}, socket) do
    if stale_train?(socket, id, algo, seq) do
      {:noreply, assign(socket, training: false)}
    else
      {:noreply,
       socket
       |> boot(id, default_env_opts(id))
       |> assign_learn(payload)
       |> assign(
         agent: Agent.eval(agent),
         algo: algo,
         training: false,
         message:
           "Trained #{algo_label(algo)} for #{episodes} episodes. Eval return #{fmt_num(avg)}. Autoplay uses this policy."
       )}
    end
  end

  def handle_info(:tick, socket) do
    cond do
      not socket.assigns.playing or socket.assigns.done ->
        {:noreply, assign(socket, playing: false)}

      true ->
        socket = apply_action(socket, auto_action(socket))

        if socket.assigns.playing and not socket.assigns.done do
          Process.send_after(self(), :tick, socket.assigns.delay)
        end

        {:noreply, socket}
    end
  end

  defp env_map_changed?(%{map_name: a}, %{map_name: b}), do: a != b
  defp env_map_changed?(_, _), do: false

  defp cast_params(params, raw) do
    Enum.map(params, fn
      %{key: key, type: :boolean} ->
        {key, raw_truthy?(Map.get(raw, Atom.to_string(key)))}

      %{key: key} ->
        {key, Map.get(raw, Atom.to_string(key))}
    end)
  end

  defp raw_truthy?(value) when value in [true, "true", "on", "1"], do: true
  defp raw_truthy?(_), do: false

  defp available?(algo, id), do: Presets.available?(algo, id)

  defp keep_or_fallback(algo, id) do
    if Presets.available?(algo, id) do
      algo
    else
      Enum.find_value(~w(a2c ppo q_learning reinforce sarsa), fn other ->
        if Presets.available?(other, id), do: other
      end) || algo
    end
  end
  defp algorithms, do: Presets.algorithms()
  defp algo_label(algo), do: Presets.algo_label(algo)

  defp default_env_opts("FrozenLake-v1"), do: [is_slippery: false]
  defp default_env_opts("gymnasium/" <> _), do: [render: true]
  defp default_env_opts(_), do: []

  defp action_buttons("FrozenLake-v1", _env), do: []

  defp action_buttons(id, env) do
    case actions_for(id) do
      [] -> discrete_buttons(env)
      labeled -> labeled
    end
  end

  defp discrete_buttons(%{action_space: %Gyx.Core.Spaces.Discrete{n: n}} = env) do
    meanings = Map.get(env, :action_meanings) || []

    if is_list(meanings) and length(meanings) == n do
      Enum.with_index(meanings)
    else
      Enum.map(0..(n - 1), fn i -> {Integer.to_string(i), i} end)
    end
  end

  defp discrete_buttons(_env), do: []

  defp atari_pad("gymnasium/ALE/" <> _, env) do
    pairs = Enum.with_index(List.wrap(Map.get(env, :action_meanings)))
    by_name = Map.new(pairs)
    stick = ~w(UP DOWN LEFT RIGHT)

    %{
      up: by_name["UP"],
      down: by_name["DOWN"],
      left: by_name["LEFT"],
      right: by_name["RIGHT"],
      fire: by_name["FIRE"],
      stick?: Enum.any?(stick, &Map.has_key?(by_name, &1)),
      extras: Enum.reject(pairs, fn {name, _} -> name in ["UP", "DOWN", "LEFT", "RIGHT", "FIRE"] end)
    }
  end

  defp atari_pad(_, _), do: nil

  defp viewport_label(:scene), do: "3D"
  defp viewport_label(:frame), do: "pixels"
  defp viewport_label(_), do: "2D"

  defp boot(socket, id, env_opts \\ []) do
    case Session.start(id, env_opts) do
      {:ok, session} ->
        env = session.env

        socket
        |> assign(
          id: id,
          backend: backend_info(id),
          playing: false,
          actions: action_buttons(id, env),
          atari_pad: atari_pad(id, env),
          sliders: sliders_for(id, env),
          params: Session.params(session),
          training: false,
          message: nil
        )
        |> assign_session(session)
        |> assign_view(session)

      {:error, reason} ->
        assign(socket,
          id: id,
          backend: backend_info(id),
          atari_pad: nil,
          actions: [],
          sliders: [],
          message: "Could not start #{id}: #{inspect(reason)}"
        )
    end
  end

  defp assign_session(socket, session) do
    assign(socket,
      session: session,
      env: session.env,
      obs: session.obs,
      return: session.return,
      terminated: session.terminated,
      truncated: session.truncated,
      done: Session.done?(session),
      last_exp: session.last_exp
    )
  end

  defp reset_env(socket) do
    session = Session.reset(socket.assigns.session)

    socket
    |> assign_session(session)
    |> assign(
      playing: false,
      sliders: sliders_for(socket.assigns.id, session.env)
    )
    |> assign_view(session)
  end

  defp apply_action(%{assigns: %{done: true}} = socket, _action), do: socket

  defp apply_action(socket, action) do
    case Session.step(socket.assigns.session, action) do
      {:ok, session} ->
        socket
        |> assign_session(session)
        |> assign(playing: socket.assigns.playing and not Session.done?(session))
        |> assign_view(session)

      {:error, _} ->
        socket
    end
  end

  defp assign_view(socket, session) do
    cond do
      String.starts_with?(socket.assigns.id, "gymnasium/ALE/") ->
        {:ok, svg} = Session.render(session, :svg)
        assign(socket, mode: :frame, scene: nil, svg: svg)

      true ->
        case Session.render(session, :scene) do
          {:ok, scene} ->
            assign(socket, mode: :scene, scene: scene, svg: "")

          _ ->
            {:ok, svg} = Session.render(session, :svg)
            assign(socket, mode: :svg, scene: nil, svg: svg)
        end
    end
  end

  defp auto_action(%{assigns: %{agent: agent, obs: obs, id: id, env: env}})
       when not is_nil(agent) do
    Agent.act(agent, obs, policy_actions(id, env))
  end

  defp auto_action(%{assigns: %{obs: obs, env: env}}) do
    Random.act(%Random{}, obs, env.action_space)
  end

  defp policy_actions(id, env) do
    Presets.policy_actions(id) || env.action_space
  end

  defp actions_for("CartPole-v1"), do: [{"Left", 0}, {"Right", 1}]
  defp actions_for("FrozenLake-v1"), do: [{"Left", 0}, {"Down", 1}, {"Right", 2}, {"Up", 3}]
  defp actions_for("MountainCar-v0"), do: [{"Left", 0}, {"Coast", 1}, {"Right", 2}]
  defp actions_for("Blackjack-v1"), do: [{"Stick", 0}, {"Hit", 1}]
  defp actions_for("Pendulum-v1"), do: [{"Torque−", 0}, {"None", 1}, {"Torque+", 2}]
  defp actions_for("Acrobot-v1"), do: [{"Torque−", 0}, {"Coast", 1}, {"Torque+", 2}]
  defp actions_for("tree/" <> rest), do: actions_for(rest)
  defp actions_for("InvertedPendulum-v4"), do: [{"Left", 0}, {"Hold", 1}, {"Right", 2}]
  defp actions_for("InvertedDoublePendulum-v4"), do: [{"Left", 0}, {"Hold", 1}, {"Right", 2}]
  defp actions_for(_), do: []

  defp sliders_for("gymnasium/ALE/" <> _, _env), do: []
  defp sliders_for("gymnasium/" <> rest, env), do: box_sliders(rest, env)
  defp sliders_for("tree/" <> rest, env), do: sliders_for(rest, env)

  defp sliders_for(id, env) when id in ~w(Reacher-v4 Swimmer-v4 Hopper-v4 Walker2d-v4 HalfCheetah-v4 Ant-v4) do
    box_sliders(id, env)
  end

  defp sliders_for(_, _), do: []

  defp box_sliders(id, env) do
    n = slider_count(env.action_space)
    {lo, hi} = slider_bounds(env.action_space)
    names = slider_names(id, n)

    Enum.map(0..(n - 1), fn i ->
      %{label: Enum.at(names, i), index: i, min: lo, max: hi, value: 0}
    end)
  end

  defp slider_count(%{shape: {n}}), do: n
  defp slider_bounds(%{low: lo, high: hi}) when is_number(lo), do: {lo, hi}
  defp slider_bounds(%{low: lo, high: hi}) when is_tuple(lo), do: {elem(lo, 0), elem(hi, 0)}

  defp put_slider_values(sliders, action) do
    Enum.map(sliders, fn slider ->
      %{slider | value: elem(action, slider.index)}
    end)
  end

  defp parse_float(nil, fallback), do: fallback

  defp parse_float(raw, fallback) do
    case Float.parse(to_string(raw)) do
      {f, _} -> f
      :error -> fallback
    end
  end

  defp parse_action(raw) do
    case Integer.parse(raw) do
      {n, ""} ->
        n

      _ ->
        case Float.parse(raw) do
          {f, ""} -> f
          _ -> raw
        end
    end
  end

  defp catalog_groups do
    classic = [
      {"CartPole-v1", "CartPole-v1"},
      {"FrozenLake-v1", "FrozenLake-v1"},
      {"MountainCar-v0", "MountainCar-v0"},
      {"Pendulum-v1", "Pendulum-v1"},
      {"Acrobot-v1", "Acrobot-v1"},
      {"Blackjack-v1", "Blackjack-v1"}
    ]

    farama = [
      {"InvertedPendulum-v4", "InvertedPendulum-v4"},
      {"InvertedDoublePendulum-v4", "InvertedDoublePendulum-v4"},
      {"Reacher-v4", "Reacher-v4"},
      {"Swimmer-v4", "Swimmer-v4"},
      {"Hopper-v4", "Hopper-v4"},
      {"Walker2d-v4", "Walker2d-v4"},
      {"HalfCheetah-v4", "HalfCheetah-v4"},
      {"Ant-v4", "Ant-v4"}
    ]

    tree = [
      {"InvertedPendulum-v4 · approximate", "tree/InvertedPendulum-v4"},
      {"Hopper-v4 · approximate", "tree/Hopper-v4"},
      {"Walker2d-v4 · approximate", "tree/Walker2d-v4"},
      {"Ant-v4 · approximate", "tree/Ant-v4"}
    ]

    python =
      Enum.map(Gyx.Envs.Gymnasium.mujoco_ids(), fn id ->
        {String.replace_prefix(id, "gymnasium/", "") <> " · C MuJoCo", id}
      end)

    atari =
      Enum.map(Gyx.Envs.Atari.ids(), fn id ->
        {String.replace_prefix(id, "gymnasium/ALE/", "") <> " · ALE", id}
      end)

    [
      {"Classic · Elixir", classic},
      {"Native Farama · Elixir MJCF", farama},
      {"Tree · approximate", tree},
      {"Gymnasium · C MuJoCo", python},
      {"Gymnasium · Atari", atari}
    ]
  end

  defp backend_info("gymnasium/ALE/" <> game) do
    %{
      kind: :atari,
      short: "ALE",
      title: "Gymnasium · Atari",
      engine: "Python gymnasium.make → ALE/Stella",
      summary:
        "Arcade Learning Environment through a Port. Frames are Nx uint8 tensors; the joystick is Discrete.",
      transfer: "Same official ALE id",
      task: "ALE/#{game}"
    }
  end

  defp backend_info("gymnasium/" <> gym_id) do
    %{
      kind: :gymnasium,
      short: "C MuJoCo",
      title: "Gymnasium · C MuJoCo",
      engine: "Python gymnasium.make → MuJoCo C",
      summary:
        "Real Farama Gymnasium through a Port. Same official task id as the native suite, running the C simulator.",
      transfer: "Reference C backend"
    }
    |> Map.put(:task, gym_id)
  end

  defp backend_info("tree/" <> name) do
    %{
      kind: :tree,
      short: "Tree (approx)",
      title: "Tree · approximate",
      engine: "Gyx.Physics.Tree",
      summary:
        "Older approximate rigid-body tree. Same task name as Farama, not gold-tested against gymnasium.make.",
      transfer: "Not a Farama gold match",
      task: name
    }
  end

  defp backend_info(id) do
    if farama_id?(id) do
      exla? = Gyx.Physics.Mjx.enabled?()

      %{
        kind: :native,
        short: "Native Elixir",
        title: if(exla?, do: "Native Elixir · EXLA", else: "Native Elixir · BEAM"),
        engine: if(exla?, do: "Gyx.Physics.Mj · EXLA", else: "Gyx.Physics.Mj · scalar Elixir"),
        summary:
          "Official Farama MJCF on the Elixir stepper. Gold-tested against gymnasium.make from a shared state.",
        transfer: "Gold-tested vs gymnasium.make",
        task: id
      }
    else
      %{
        kind: :classic,
        short: "Classic Elixir",
        title: "Classic · Elixir",
        engine: "Pure Elixir environment",
        summary: "Built-in Gym-style environment. No MuJoCo and no Python.",
        transfer: "Native Elixir",
        task: id
      }
    end
  end

  defp farama_id?(id), do: String.contains?(id, "-v4") or String.contains?(id, "-v5")

  defp backend_siblings(id) do
    task = backend_info(id).task

    [
      %{id: task, short: "Native Elixir", title: "Official Farama MJCF · Elixir stepper"},
      %{id: "tree/#{task}", short: "Tree (approx)", title: "Approximate Gyx.Physics.Tree"},
      %{id: "gymnasium/#{task}", short: "C MuJoCo", title: "Python gymnasium.make · MuJoCo C"}
    ]
    |> Enum.filter(&env_registered?(&1.id))
  end

  defp env_registered?(id), do: match?({:ok, _}, Gyx.Envs.fetch(id))

  defp status_class(true, _), do: "danger"
  defp status_class(_, true), do: "warn"
  defp status_class(_, _), do: "ok"

  defp slider_names("tree/" <> rest, n), do: slider_names(rest, n)
  defp slider_names("Hopper-v4", _), do: ~w(a0·thigh a1·leg a2·foot)
  defp slider_names("Hopper-v5", n), do: slider_names("Hopper-v4", n)
  defp slider_names("Walker2d-v4", _), do: ~w(a0·r-thigh a1·r-leg a2·r-foot a3·l-thigh a4·l-leg a5·l-foot)
  defp slider_names("Walker2d-v5", n), do: slider_names("Walker2d-v4", n)
  defp slider_names("HalfCheetah-v4", _), do: ~w(a0·b-thigh a1·b-shin a2·b-foot a3·f-thigh a4·f-shin a5·f-foot)
  defp slider_names("HalfCheetah-v5", n), do: slider_names("HalfCheetah-v4", n)
  defp slider_names("Ant-v4", _), do: ~w(a0·fl-hip a1·fl-ankle a2·fr-hip a3·fr-ankle a4·bl-hip a5·bl-ankle a6·br-hip a7·br-ankle)
  defp slider_names("Ant-v5", n), do: slider_names("Ant-v4", n)
  defp slider_names("Reacher-v4", _), do: ~w(a0·joint1 a1·joint2)
  defp slider_names("Reacher-v5", n), do: slider_names("Reacher-v4", n)
  defp slider_names("Swimmer-v4", _), do: ~w(a0·joint1 a1·joint2)
  defp slider_names("Swimmer-v5", n), do: slider_names("Swimmer-v4", n)
  defp slider_names(_, n), do: Enum.map(0..(n - 1), &"a#{&1}")

  defp status(true, _), do: "terminated"
  defp status(_, true), do: "truncated"
  defp status(_, _), do: "running"

  defp fmt_reward(nil), do: "—"
  defp fmt_reward(exp), do: fmt_num(exp.reward)
  defp fmt_num(nil), do: "—"
  defp fmt_num(n) when is_float(n), do: n |> Float.round(3) |> to_string()
  defp fmt_num(n), do: to_string(n)

  defp fmt_obs(%Nx.Tensor{} = tensor) do
    {type, bits} = Nx.type(tensor)
    dims = tensor |> Nx.shape() |> Tuple.to_list() |> Enum.join("×")
    "#{dims} #{type}#{bits}"
  end

  defp fmt_obs(obs) when is_tuple(obs) and tuple_size(obs) > 6 do
    obs
    |> Tuple.to_list()
    |> Enum.map(&fmt_num/1)
    |> Enum.join(", ")
  end

  defp fmt_obs(obs), do: inspect(obs)

  defp stale_train?(socket, id, algo, seq) do
    socket.assigns.id != id or socket.assigns.algo != algo or socket.assigns.train_seq != seq
  end

  defp bump_train(socket), do: assign(socket, train_seq: socket.assigns.train_seq + 1)

  defp clear_learn(socket) do
    assign(socket,
      training: false,
      train_episode: 0,
      train_episodes: 0,
      train_pct: 0.0,
      train_last: nil,
      train_mean: nil,
      train_curve: [],
      train_smooth: []
    )
  end

  defp assign_learn(socket, payload) do
    assign(socket,
      train_episode: payload.episode,
      train_episodes: payload.episodes,
      train_pct: train_pct(payload.episode, payload.episodes),
      train_last: payload.return,
      train_mean: payload.mean,
      train_curve: payload.curve,
      train_smooth: payload.smooth
    )
  end

  defp empty_payload(episodes) do
    %{episode: 0, episodes: episodes, return: nil, mean: nil, curve: [], smooth: []}
  end

  defp progress_payload(info) do
    build_payload(Enum.reverse(info.returns), info.episode, info.episodes, info.return)
  end

  defp final_payload(returns, episodes) do
    build_payload(returns, episodes, episodes, List.last(returns))
  end

  defp build_payload(chrono, episode, episodes, last) do
    window = 20

    mean =
      case Enum.take(chrono, -window) do
        [] -> nil
        xs -> Enum.sum(xs) / length(xs)
      end

    %{
      episode: episode,
      episodes: episodes,
      return: last,
      mean: mean,
      curve: downsample(chrono, 120),
      smooth: downsample(rolling_mean(chrono, window), 120)
    }
  end

  defp train_pct(_episode, episodes) when episodes in [0, nil], do: 0.0
  defp train_pct(episode, episodes), do: min(100.0, Float.round(100.0 * episode / episodes, 1))

  defp downsample(xs, max_points) when xs == [] or max_points < 1, do: []
  defp downsample(xs, max_points) when length(xs) <= max_points, do: xs

  defp downsample(xs, max_points) do
    n = length(xs)
    last = n - 1

    Enum.map(0..(max_points - 1), fn i ->
      Enum.at(xs, div(i * last, max_points - 1))
    end)
  end

  defp rolling_mean([], _window), do: []

  defp rolling_mean(xs, window) do
    xs
    |> Enum.with_index(1)
    |> Enum.map(fn {_x, i} ->
      start = max(0, i - window)
      slice = Enum.slice(xs, start, i - start)
      Enum.sum(slice) / length(slice)
    end)
  end

  defp curve_svg([], _), do: ""

  defp curve_svg(raw, smooth) do
    {ymin, ymax} = extrema(raw ++ smooth)
    pad = max((ymax - ymin) * 0.08, 0.5)
    ymin = ymin - pad
    ymax = ymax + pad
    width = 640
    height = 168
    left = 40
    right = 12
    top = 10
    bottom = 24
    inner_w = width - left - right
    inner_h = height - top - bottom
    n = max(length(raw), 1)

    raw_pts = polyline_points(raw, n, ymin, ymax, left, top, inner_w, inner_h)
    smooth_pts = polyline_points(smooth, n, ymin, ymax, left, top, inner_w, inner_h)
    y0 = y_at(0.0, ymin, ymax, top, inner_h)
    hi = fmt_num(ymax - pad)
    lo = fmt_num(ymin + pad)
    raw_line = polyline_tag(raw_pts, "var(--raw)", 1.4)
    smooth_line = polyline_tag(smooth_pts, "var(--accent)", 2.2)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{width} #{height}" role="img" aria-label="Learning curve">
      <line x1="#{left}" y1="#{y0}" x2="#{left + inner_w}" y2="#{y0}" stroke="var(--line)" stroke-width="1"/>
      <text x="#{left - 6}" y="#{top + 4}" text-anchor="end" fill="var(--muted)" font-size="10" font-family="IBM Plex Mono, ui-monospace, monospace">#{hi}</text>
      <text x="#{left - 6}" y="#{top + inner_h + 3}" text-anchor="end" fill="var(--muted)" font-size="10" font-family="IBM Plex Mono, ui-monospace, monospace">#{lo}</text>
      #{raw_line}
      #{smooth_line}
    </svg>
    """
  end

  defp polyline_tag("", _, _), do: ""

  defp polyline_tag(points, stroke, width) do
    "<polyline fill=\"none\" stroke=\"#{stroke}\" stroke-width=\"#{width}\" points=\"#{points}\"/>"
  end

  defp extrema([]), do: {0.0, 1.0}

  defp extrema(xs) do
    {min, max} = Enum.min_max(xs)
    if min == max, do: {min - 1.0, max + 1.0}, else: {min * 1.0, max * 1.0}
  end

  defp polyline_points([], _, _, _, _, _, _, _), do: ""

  defp polyline_points(xs, n, ymin, ymax, left, top, inner_w, inner_h) do
    last = max(n - 1, 1)

    xs
    |> Enum.with_index()
    |> Enum.map(fn {y, i} ->
      x = left + inner_w * i / last
      "#{Float.round(x, 1)},#{Float.round(y_at(y, ymin, ymax, top, inner_h), 1)}"
    end)
    |> Enum.join(" ")
  end

  defp y_at(y, ymin, ymax, top, inner_h) do
    span = ymax - ymin
    span = if span == 0, do: 1.0, else: span
    top + inner_h * (1.0 - (y - ymin) / span)
  end
end
