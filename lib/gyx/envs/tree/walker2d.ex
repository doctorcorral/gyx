defmodule Gyx.Envs.Tree.Walker2d do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  Walker2d-v4, Gymnasium-shaped.

  Biped in the x-z plane. Observation is 17-D. Reward is healthy +
  forward − control. Unhealthy if torso height or pitch leaves range.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @dt 0.002
  @nsub 4
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
      id: "tree/Walker2d-v4",
      observation_space: %Box{shape: {17}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {6}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 4000.0
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
    {noise, rng} = Mujoco.noise(rng, 9, 0.005)
    q0 = {0.0, 1.25, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0}
    env = %{env | q: Mujoco.add(q0, noise), qd: Mujoco.zeros(9), last_u: Mujoco.zeros(6), steps: 0, rng: rng}
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
  def render(env, :scene), do: Mujoco.render_scene(env.q, model(), track: :torso, distance: 3.6)
  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/Walker2d-v4")
  def render(env, :ansi), do: {:ok, "Walker2d #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(6, -1.0, 1.0)

  defp do_step(env, u) do
    obs = observe(env)
    {x0, _, _, _, _, _, _, _, _} = env.q
    tau = List.to_tuple([0.0, 0.0, 0.0 | Enum.map(Tuple.to_list(u), &(&1 * 40.0))])
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {x1, z1, th1, _, _, _, _, _, _} = q
    dt = @dt * @nsub
    healthy? = z1 > 0.8 and abs(th1) < 1.0
    forward = (x1 - x0) / dt
    ctrl = 0.001 * Enum.reduce(Tuple.to_list(u), 0.0, fn a, acc -> acc + a * a end)
    reward = (if healthy?, do: 1.0, else: 0.0) + forward - ctrl
    terminated = not healthy?
    truncated = not terminated and env.steps >= env.max_episode_steps

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

  defp model do
    leg = fn prefix, hip, knee, foot, color ->
      [
        %{
          name: :"#{prefix}_thigh",
          parent: :torso,
          joint: {:hinge, hip, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.2},
          mass: 1.0,
          com: {0.0, 0.0, -0.18},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.36}, 0.04, color}]
        },
        %{
          name: :"#{prefix}_leg",
          parent: :"#{prefix}_thigh",
          joint: {:hinge, knee, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.36},
          mass: 0.7,
          com: {0.0, 0.0, -0.2},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, -0.4}, 0.03, color}]
        },
        %{
          name: :"#{prefix}_foot",
          parent: :"#{prefix}_leg",
          joint: {:hinge, foot, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, -0.4},
          mass: 0.3,
          com: {0.04, 0.0, 0.0},
          geoms: [{:capsule, {-0.05, 0.0, 0.0}, {0.14, 0.0, 0.0}, 0.025, "#1e1b4b"}]
        }
      ]
    end

    %{
      n: 9,
      inertia: {20.0, 7.0, 2.2, 0.4, 0.28, 0.12, 0.4, 0.28, 0.12},
      damping: 0.12,
      gravity: 9.81,
      contact_k: 4000.0,
      contact_c: 80.0,
      friction: 1.5,
      auto_contacts: true,
      contacts: [
        %{body: :right_foot, offset: {0.12, 0.04, 0.0}},
        %{body: :right_foot, offset: {-0.04, 0.04, 0.0}},
        %{body: :left_foot, offset: {0.12, -0.04, 0.0}},
        %{body: :left_foot, offset: {-0.04, -0.04, 0.0}}
      ],
      view: :xz,
      bodies:
        [
          %{
            name: :torso,
            parent: nil,
            joint: {:free_planar, 0, 1, 2},
            mass: 4.0,
            com: {0.0, 0.0, 0.05},
            geoms: [{:capsule, {0.0, 0.0, -0.2}, {0.0, 0.0, 0.2}, 0.055, "#4f46e5"}]
          }
        ] ++ leg.(:right, 3, 4, 5, "#6366f1") ++ leg.(:left, 6, 7, 8, "#818cf8")
    }
  end

  defp rng(env, opts) do
    case Keyword.fetch(opts, :seed) do
      {:ok, seed} -> RNG.seed(seed)
      :error -> env.rng || RNG.seed(nil)
    end
  end
end
