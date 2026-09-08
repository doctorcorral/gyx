defmodule Gyx.Envs.Tree.InvertedDoublePendulum do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  InvertedDoublePendulum-v4, Gymnasium-shaped.

  Cart plus two poles. Observation is 11-D (`x`, sines/cosines, velocities,
  and placeholder constraint terms). Reward is `10 - distance - velocity`
  while the tip stays above `1.0`.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @force_max 1.0
  @dt 0.01
  @nsub 2
  @max_episode_steps 1000

  defstruct q: nil,
            qd: nil,
            last_u: 0.0,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {1}, low: -@force_max, high: @force_max},
            observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/InvertedDoublePendulum-v4",
      observation_space: %Box{shape: {11}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {1}, low: -@force_max, high: @force_max},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 9100.0
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
    {nq, rng} = Mujoco.noise(rng, 3, 0.1)
    {nv, rng} = Mujoco.noise(rng, 3, 0.1)
    env = %{env | q: nq, qd: nv, last_u: 0.0, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: {x, th1, th2}, qd: {v0, v1, v2}}) do
    {x, :math.sin(th1), :math.sin(th2), :math.cos(th1), :math.cos(th2), v0, v1, v2, 0.0, 0.0, 0.0}
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 1, -@force_max, @force_max) do
      {:ok, {u}} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene),
    do: Mujoco.render_scene(env.q, model(), track: :cart, distance: 3.2, azimuth: 90)

  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/InvertedDoublePendulum-v4")
  def render(env, :ansi), do: {:ok, "InvertedDoublePendulum #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(1, -@force_max, @force_max)

  defp do_step(env, u) do
    obs = observe(env)
    tau = {u * 18.0, 0.0, 0.0}
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}

    {_x, _y, tip_z} = Mujoco.tip(q, model(), :pole2, {0.0, 0.0, 0.6})
    {cx, _, _} = q_xyz(q)
    dist = 0.01 * cx * cx + (tip_z - 1.2) * (tip_z - 1.2)
    {_v0, v1, v2} = qd
    vel = 1.0e-3 * v1 * v1 + 5.0e-3 * v2 * v2
    terminated = tip_z <= 1.0
    reward = if terminated, do: 0.0, else: 10.0 - dist - vel
    truncated = not terminated and env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps}
     }}
  end

  defp q_xyz({x, _, _}), do: {x, 0.0, 0.0}

  defp model do
    %{
      n: 3,
      inertia: {12.0, 0.35, 0.2},
      damping: 0.08,
      gravity: 9.81,
      contacts: [],
      bodies: [
        %{
          name: :cart,
          parent: nil,
          joint: {:slide_x, 0},
          mass: 1.0,
          com: {0.0, 0.0, 0.1},
          geoms: [{:box, {0.0, 0.0, 0.1}, {0.2, 0.12, 0.1}, "#1c1917"}]
        },
        %{
          name: :pole1,
          parent: :cart,
          joint: {:hinge, 1, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, 0.1},
          mass: 0.1,
          com: {0.0, 0.0, 0.3},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.6}, 0.04, "#4f46e5"}]
        },
        %{
          name: :pole2,
          parent: :pole1,
          joint: {:hinge, 2, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, 0.6},
          mass: 0.1,
          com: {0.0, 0.0, 0.3},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.6}, 0.035, "#818cf8"}]
        }
      ],
      view: :xz
    }
  end

  defp rng(env, opts) do
    case Keyword.fetch(opts, :seed) do
      {:ok, seed} -> RNG.seed(seed)
      :error -> env.rng || RNG.seed(nil)
    end
  end
end
