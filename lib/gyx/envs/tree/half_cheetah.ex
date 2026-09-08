defmodule Gyx.Envs.Tree.HalfCheetah do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  HalfCheetah-v4, Gymnasium-shaped.

  Planar cheetah, 9-D qpos / 6 actuators. Observation is 17-D.
  Reward is forward velocity minus control cost. Episodes truncate
  at 1000 steps and do not terminate on falling.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @dt 0.01
  @nsub 5
  @max_episode_steps 1000

  defstruct q: nil,
            qd: nil,
            last_u: nil,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {6}, low: -1.0, high: 1.0},
            observation_space: %Box{shape: {17}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/HalfCheetah-v4",
      observation_space: %Box{shape: {17}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {6}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 4800.0
    }
  end

  @impl true
  def new(opts \\ []) do
    reset(%__MODULE__{max_episode_steps: Keyword.get(opts, :max_episode_steps, @max_episode_steps)}, opts)
    |> elem(0)
  end

  @impl true
  def reset(env, opts \\ []) do
    rng = rng(env, opts)
    {noise, rng} = Mujoco.noise(rng, 9, 0.1)
    q0 = {0.0, 0.7, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    env = %{env | q: Mujoco.add(q0, scale(noise, 0.1)), qd: Mujoco.zeros(9), last_u: Mujoco.zeros(6), steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: q, qd: qd}) do
    [_x | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(qd))
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 6, -1.0, 1.0) do
      {:ok, u} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene), do: Mujoco.render_scene(env.q, model(), track: :torso, distance: 3.8, azimuth: 120)
  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/HalfCheetah-v4")
  def render(env, :ansi), do: {:ok, "HalfCheetah #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(6, -1.0, 1.0)

  defp do_step(env, u) do
    obs = observe(env)
    {x0, _, _, _, _, _, _, _, _} = env.q
    tau = List.to_tuple([0.0, 0.0, 0.0 | Enum.map(Tuple.to_list(u), &(&1 * 50.0))])
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt / @nsub, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {x1, _, _, _, _, _, _, _, _} = q
    dt = @dt
    forward = (x1 - x0) / dt
    ctrl = 0.1 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    reward = forward - ctrl
    truncated = env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: false,
       truncated: truncated,
       info: %{steps: env.steps, x_velocity: forward, reward_ctrl: -ctrl}
     }}
  end

  defp scale(t, s) do
    Enum.map(0..(tuple_size(t) - 1), & (elem(t, &1) * s))
    |> List.to_tuple()
  end

  defp model do
    %{
      n: 9,
      inertia: {22.0, 8.0, 2.5, 0.5, 0.3, 0.15, 0.5, 0.3, 0.15},
      damping: 0.1,
      gravity: 9.81,
      contact_k: 5000.0,
      contact_c: 90.0,
      friction: 1.6,
      auto_contacts: true,
      contacts: [],
      view: :xz,
      bodies: [
        %{
          name: :torso,
          parent: nil,
          joint: {:free_planar, 0, 1, 2},
          mass: 6.0,
          com: {0.0, 0.0, 0.0},
          geoms: [{:capsule, {-0.5, 0.0, 0.0}, {0.5, 0.0, 0.0}, 0.046, "#4f46e5"}]
        },
        %{
          name: :bthigh,
          parent: :torso,
          joint: {:hinge, 3, {0.0, 1.0, 0.0}},
          attach: {-0.5, 0.0, 0.0},
          mass: 1.5,
          com: {0.0, 0.0, -0.12},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.24}, 0.04, "#6366f1"}]
        },
        %{
          name: :bshin,
          parent: :bthigh,
          joint: {:hinge, 4, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.24},
          mass: 1.0,
          com: {0.0, 0.0, -0.12},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.24}, 0.032, "#818cf8"}]
        },
        %{
          name: :bfoot,
          parent: :bshin,
          joint: {:hinge, 5, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.24},
          mass: 0.5,
          com: {0.0, 0.0, -0.06},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.13}, 0.025, "#1e1b4b"}]
        },
        %{
          name: :fthigh,
          parent: :torso,
          joint: {:hinge, 6, {0.0, 1.0, 0.0}},
          attach: {0.5, 0.0, 0.0},
          mass: 1.4,
          com: {0.0, 0.0, -0.12},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.24}, 0.04, "#6366f1"}]
        },
        %{
          name: :fshin,
          parent: :fthigh,
          joint: {:hinge, 7, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.24},
          mass: 1.0,
          com: {0.0, 0.0, -0.12},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.24}, 0.032, "#818cf8"}]
        },
        %{
          name: :ffoot,
          parent: :fshin,
          joint: {:hinge, 8, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.24},
          mass: 0.5,
          com: {0.0, 0.0, -0.06},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.13}, 0.025, "#1e1b4b"}]
        }
      ]
    }
  end

  defp rng(env, opts) do
    case Keyword.fetch(opts, :seed) do
      {:ok, seed} -> RNG.seed(seed)
      :error -> env.rng || RNG.seed(nil)
    end
  end
end
