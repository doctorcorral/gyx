defmodule Gyx.Envs.Tree.Reacher do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  Reacher-v4, Gymnasium-shaped.

  Two-link arm in the horizontal plane. Observation is 11-D (joint
  cos/sin, target, velocities, fingertip − target). Reward is
  `-distance - ||a||²`.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @dt 0.01
  @nsub 2
  @max_episode_steps 50

  defstruct q: nil,
            qd: nil,
            target: {0.1, 0.1},
            last_u: {0.0, 0.0},
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {2}, low: -1.0, high: 1.0},
            observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/Reacher-v4",
      observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {2}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps,
      reward_threshold: -3.75
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
    {q, rng} = Mujoco.noise(rng, 2, 0.1)
    {qd, rng} = Mujoco.noise(rng, 2, 0.05)
    {tx, rng} = Gyx.RNG.uniform_range(rng, -0.2, 0.2)
    {ty, rng} = Gyx.RNG.uniform_range(rng, -0.2, 0.2)
    env = %{env | q: q, qd: qd, target: {tx, ty}, last_u: {0.0, 0.0}, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: {th1, th2}, qd: {w1, w2}, target: {tx, ty}} = env) do
    {fx, fy, fz} = fingertip(env)
    {th1 |> :math.cos(), th2 |> :math.cos(), :math.sin(th1), :math.sin(th2), tx, ty, w1, w2,
     fx - tx, fy - ty, fz}
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 2, -1.0, 1.0) do
      {:ok, u} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene) do
    {tx, ty} = env.target
    extras = [%{id: "target", geom: "sphere", pos: [tx, ty, 0.02], radius: 0.02, color: "#e11d48"}]
    Mujoco.render_scene(env.q, model(), track: :arm1, distance: 1.4, elevation: -70, extras: extras, ground: true)
  end

  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/Reacher-v4")
  def render(env, :ansi), do: {:ok, "Reacher #{inspect(observe(env))}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(2, -1.0, 1.0)

  defp do_step(env, {u1, u2} = u) do
    obs = observe(env)
    tau = {u1 * 0.08, u2 * 0.08}
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {fx, fy, _} = fingertip(env)
    {tx, ty} = env.target
    dist = :math.sqrt((fx - tx) ** 2 + (fy - ty) ** 2)
    reward = -dist - (u1 * u1 + u2 * u2)
    truncated = env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: false,
       truncated: truncated,
       info: %{steps: env.steps, reward_dist: -dist, reward_ctrl: -(u1 * u1 + u2 * u2)}
     }}
  end

  defp fingertip(env), do: Mujoco.tip(env.q, model(), :arm2, {0.1, 0.0, 0.0})

  defp model do
    %{
      n: 2,
      inertia: {0.05, 0.03},
      damping: 0.02,
      gravity: 0.0,
      drag: 0.01,
      contacts: [],
      view: :xy,
      bodies: [
        %{
          name: :root,
          parent: nil,
          joint: :fixed,
          pos: {0.0, 0.0, 0.05},
          mass: 0.1,
          com: {0.0, 0.0, 0.0},
          geoms: [{:sphere, {0.0, 0.0, 0.0}, 0.025, "#1c1917"}]
        },
        %{
          name: :arm1,
          parent: :root,
          joint: {:hinge, 0, {0.0, 0.0, 1.0}},
          attach: {0.0, 0.0, 0.0},
          mass: 0.05,
          com: {0.05, 0.0, 0.0},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.1, 0.0, 0.0}, 0.015, "#4f46e5"}]
        },
        %{
          name: :arm2,
          parent: :arm1,
          joint: {:hinge, 1, {0.0, 0.0, 1.0}},
          attach: {0.1, 0.0, 0.0},
          mass: 0.04,
          com: {0.05, 0.0, 0.0},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.1, 0.0, 0.0}, 0.012, "#818cf8"}]
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
