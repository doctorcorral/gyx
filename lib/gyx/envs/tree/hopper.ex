defmodule Gyx.Envs.Tree.Hopper do
  @moduledoc """
  Approximate tree backend (`tree/Hopper-v4`).

  Hopper-v4, Gymnasium-shaped.

  Planar hopper: free root `{x, z, θ}` plus thigh/leg/foot hinges.
  Observation is 11-D (qpos without `x`, then qvel). Reward is
  healthy + forward − control.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @dt 0.002
  @nsub 4
  @max_episode_steps 1000
  @healthy_z 0.7
  @healthy_angle 0.35

  defstruct q: nil,
            qd: nil,
            last_u: {0.0, 0.0, 0.0},
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {3}, low: -1.0, high: 1.0},
            observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/Hopper-v4",
      observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {3}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 3800.0
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
    {noise, rng} = Mujoco.noise(rng, 6, 0.005)
    q0 = {0.0, 1.25, 0.0, 0.0, 0.0, 0.0}
    env = %{env | q: Mujoco.add(q0, noise), qd: Mujoco.zeros(6), last_u: {0.0, 0.0, 0.0}, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: q, qd: qd}) do
    [_x | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(qd))
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 3, -1.0, 1.0) do
      {:ok, u} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene), do: Mujoco.render_scene(env.q, model(), track: :torso, distance: 3.2)
  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/Hopper-v4")
  def render(env, :ansi), do: {:ok, "Hopper #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(3, -1.0, 1.0)

  defp do_step(env, {a0, a1, a2} = u) do
    obs = observe(env)
    {x0, z0, th0, _, _, _} = env.q
    tau = {0.0, 0.0, 0.0, a0 * 55.0, a1 * 45.0, a2 * 35.0}
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {x1, z1, th1, _, _, _} = q
    dt = @dt * @nsub
    healthy? = z1 > @healthy_z and abs(th1) < @healthy_angle
    forward = (x1 - x0) / dt
    ctrl = 0.001 * (a0 * a0 + a1 * a1 + a2 * a2)
    reward = (if healthy?, do: 1.0, else: 0.0) + forward - ctrl
    terminated = not healthy?
    truncated = not terminated and env.steps >= env.max_episode_steps
    _ = {z0, th0}

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps, x_velocity: forward, reward_survive: if(healthy?, do: 1.0, else: 0.0)}
     }}
  end

  defp model do
    %{
      n: 6,
      inertia: {18.0, 6.0, 1.8, 0.45, 0.28, 0.12},
      damping: 0.12,
      gravity: 9.81,
      contact_k: 4000.0,
      contact_c: 80.0,
      friction: 1.6,
      auto_contacts: true,
      limits: [{3, -2.6, 0.15}, {4, -2.6, 0.15}, {5, -0.8, 0.8}],
      contacts: [
        %{body: :foot, offset: {0.13, 0.0, 0.0}},
        %{body: :foot, offset: {-0.1, 0.0, 0.0}}
      ],
      view: :xz,
      bodies: [
        %{
          name: :torso,
          parent: nil,
          joint: {:free_planar, 0, 1, 2},
          mass: 3.5,
          com: {0.0, 0.0, 0.05},
          geoms: [{:capsule, {0.0, 0.0, -0.18}, {0.0, 0.0, 0.18}, 0.05, "#4f46e5"}]
        },
        %{
          name: :thigh,
          parent: :torso,
          joint: {:hinge, 3, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.18},
          mass: 1.2,
          com: {0.0, 0.0, -0.2},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.4}, 0.045, "#6366f1"}]
        },
        %{
          name: :leg,
          parent: :thigh,
          joint: {:hinge, 4, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.4},
          mass: 0.8,
          com: {0.0, 0.0, -0.22},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.45}, 0.035, "#818cf8"}]
        },
        %{
          name: :foot,
          parent: :leg,
          joint: {:hinge, 5, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.45},
          mass: 0.4,
          com: {0.05, 0.0, 0.0},
          geoms: [{:capsule, {-0.1, 0.0, 0.0}, {0.18, 0.0, 0.0}, 0.03, "#1e1b4b"}]
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
