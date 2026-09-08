defmodule Gyx.Envs.Tree.Ant do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  Ant-v4, Gymnasium-shaped.

  Quadruped with a free 6-D root and 8 hinge joints. Observation is
  27-D (qpos without `x,y`, then qvel). Reward is healthy + forward −
  control. Unhealthy if torso height leaves `(0.2, 1.0)`.
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
            action_space: %Box{shape: {8}, low: -1.0, high: 1.0},
            observation_space: %Box{shape: {27}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/Ant-v4",
      observation_space: %Box{shape: {27}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {8}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 6000.0
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
    {noise, rng} = Mujoco.noise(rng, 14, 0.1)
    # hips 0, ankles bent down so all four feet reach the ground
    q0 = {0.0, 0.0, 0.32, 0.0, 0.0, 0.0, 0.0, 0.9, 0.0, 0.9, 0.0, 0.9, 0.0, 0.9}
    q = Mujoco.add(q0, scale(noise, 0.05))
    env = %{env | q: q, qd: Mujoco.zeros(14), last_u: Mujoco.zeros(8), steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: q, qd: qd}) do
    # Gymnasium skips x,y and uses quat (4) + 8 hinges + 14 qvel = 27.
    # We store Euler (roll,pitch,yaw) and expand to a unit quaternion.
    {_, _, z, roll, pitch, yaw, h0, h1, h2, h3, h4, h5, h6, h7} = q
    {qw, qx, qy, qz} = euler_to_quat(roll, pitch, yaw)

    List.to_tuple(
      [z, qw, qx, qy, qz, h0, h1, h2, h3, h4, h5, h6, h7] ++ Tuple.to_list(qd)
    )
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 8, -1.0, 1.0) do
      {:ok, u} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene), do: Mujoco.render_scene(env.q, model(), track: :torso, distance: 4.2, azimuth: 140)
  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/Ant-v4")
  def render(env, :ansi), do: {:ok, "Ant #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(8, -1.0, 1.0)

  defp do_step(env, u) do
    obs = observe(env)
    {x0, _, z0, _, _, _, _, _, _, _, _, _, _, _} = env.q
    gears = Enum.map(Tuple.to_list(u), &(&1 * 28.0))
    tau = List.to_tuple([0.0, 0.0, 0.0, 0.0, 0.0, 0.0 | gears])
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt / @nsub, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {x1, _, z1, _, _, _, _, _, _, _, _, _, _, _} = q
    dt = @dt
    healthy? = z1 > 0.2 and z1 < 1.0
    forward = (x1 - x0) / dt
    ctrl = 0.5 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    reward = (if healthy?, do: 1.0, else: 0.0) + forward - ctrl
    terminated = not healthy?
    truncated = not terminated and env.steps >= env.max_episode_steps
    _ = z0

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps, x_velocity: forward}
     }}
  end

  defp euler_to_quat(roll, pitch, yaw) do
    cr = :math.cos(roll * 0.5)
    sr = :math.sin(roll * 0.5)
    cp = :math.cos(pitch * 0.5)
    sp = :math.sin(pitch * 0.5)
    cy = :math.cos(yaw * 0.5)
    sy = :math.sin(yaw * 0.5)

    {cr * cp * cy + sr * sp * sy, sr * cp * cy - cr * sp * sy, cr * sp * cy + sr * cp * sy,
     cr * cp * sy - sr * sp * cy}
  end

  defp scale(t, s) do
    Enum.map(0..(tuple_size(t) - 1), & (elem(t, &1) * s))
    |> List.to_tuple()
  end

  defp model do
    legs = [
      {:leg_fl, 6, 7, {0.12, 0.12, 0.0}, 0.785},
      {:leg_fr, 8, 9, {0.12, -0.12, 0.0}, -0.785},
      {:leg_bl, 10, 11, {-0.12, 0.12, 0.0}, 2.356},
      {:leg_br, 12, 13, {-0.12, -0.12, 0.0}, -2.356}
    ]

    leg_bodies =
      Enum.flat_map(legs, fn {name, hip, ankle, attach, yaw} ->
        hip_name = :"#{name}_hip"
        ankle_name = :"#{name}_ankle"

        [
          %{
            name: hip_name,
            parent: :torso,
            joint: {:hinge, hip, {0.0, 0.0, 1.0}},
            attach: attach,
            rest: rz(yaw),
            mass: 0.4,
            com: {0.1, 0.0, 0.0},
            geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.2, 0.0, 0.0}, 0.04, "#6366f1"}]
          },
          %{
            name: ankle_name,
            parent: hip_name,
            joint: {:hinge, ankle, {0.0, 1.0, 0.0}},
            attach: {0.2, 0.0, 0.0},
            mass: 0.3,
            com: {0.16, 0.0, 0.0},
            geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.32, 0.0, 0.0}, 0.035, "#818cf8"}]
          }
        ]
      end)

    %{
      n: 14,
      inertia: {8.0, 8.0, 6.0, 1.2, 1.2, 1.4, 0.2, 0.15, 0.2, 0.15, 0.2, 0.15, 0.2, 0.15},
      damping: 0.18,
      gravity: 9.81,
      contact_k: 4500.0,
      contact_c: 90.0,
      friction: 1.4,
      auto_contacts: true,
      contacts: [],
      view: :xy,
      bodies: [
        %{
          name: :torso,
          parent: nil,
          joint: {:free, 0, 1, 2, 3, 4, 5},
          mass: 4.0,
          com: {0.0, 0.0, 0.0},
          geoms: [{:sphere, {0.0, 0.0, 0.0}, 0.1, "#4f46e5"}]
        }
      ] ++ leg_bodies
    }
  end

  defp rz(a) do
    c = :math.cos(a)
    s = :math.sin(a)
    {{c, -s, 0.0}, {s, c, 0.0}, {0.0, 0.0, 1.0}}
  end

  defp rng(env, opts) do
    case Keyword.fetch(opts, :seed) do
      {:ok, seed} -> RNG.seed(seed)
      :error -> env.rng || RNG.seed(nil)
    end
  end
end
