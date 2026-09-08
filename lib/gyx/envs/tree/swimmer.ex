defmodule Gyx.Envs.Tree.Swimmer do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  Swimmer-v4, Gymnasium-shaped.

  Three-link swimmer in the x-y plane with fluid drag. Observation is
  8-D. Reward is forward velocity minus a small control cost.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @dt 0.01
  @nsub 4
  @max_episode_steps 1000

  defstruct q: nil,
            qd: nil,
            last_u: {0.0, 0.0},
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {2}, low: -1.0, high: 1.0},
            observation_space: %Box{shape: {8}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/Swimmer-v4",
      observation_space: %Box{shape: {8}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {2}, low: -1.0, high: 1.0},
      max_episode_steps: @max_episode_steps
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
    {noise, rng} = Mujoco.noise(rng, 5, 0.1)
    q0 = {0.0, 0.0, 0.0, 0.0, 0.0}
    env = %{env | q: Mujoco.add(q0, noise), qd: Mujoco.zeros(5), last_u: {0.0, 0.0}, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%{q: q, qd: qd}) do
    [_x, _y | rest] = Tuple.to_list(q)
    List.to_tuple(rest ++ Tuple.to_list(qd))
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
    Mujoco.render_scene(env.q, model(),
      track: :torso,
      distance: 3.0,
      elevation: -55,
      azimuth: 90,
      water: true,
      ground: false
    )
  end

  def render(env, :svg), do: Mujoco.render_svg(env.q, model(), "tree/Swimmer-v4")
  def render(env, :ansi), do: {:ok, "Swimmer #{inspect(env.q)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(2, -1.0, 1.0)

  defp do_step(env, {a0, a1} = u) do
    obs = observe(env)
    {x0, _, _, _, _} = env.q
    tau = {0.0, 0.0, 0.0, a0 * 0.4, a1 * 0.4}
    {q, qd} = Mujoco.integrate(env.q, env.qd, tau, model(), @dt, @nsub)
    env = %{env | q: q, qd: qd, last_u: u, steps: env.steps + 1}
    {x1, _, _, _, _} = q
    dt = @dt * @nsub
    forward = (x1 - x0) / dt
    reward = forward - 0.0001 * (a0 * a0 + a1 * a1)
    truncated = env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: reward,
       next_observation: observe(env),
       terminated: false,
       truncated: truncated,
       info: %{steps: env.steps, x_velocity: forward}
     }}
  end

  defp model do
    %{
      n: 5,
      inertia: {4.0, 4.0, 0.4, 0.15, 0.12},
      damping: 0.04,
      gravity: 0.0,
      drag: 1.6,
      contacts: [],
      view: :xy,
      bodies: [
        %{
          name: :torso,
          parent: nil,
          joint: {:free_planar_xy, 0, 1, 2},
          z: 0.08,
          mass: 1.2,
          com: {0.0, 0.0, 0.0},
          geoms: [{:capsule, {-0.1, 0.0, 0.0}, {0.1, 0.0, 0.0}, 0.05, "#0ea5e9"}]
        },
        %{
          name: :mid,
          parent: :torso,
          joint: {:hinge, 3, {0.0, 0.0, 1.0}},
          attach: {0.1, 0.0, 0.0},
          mass: 0.8,
          com: {0.1, 0.0, 0.0},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.2, 0.0, 0.0}, 0.04, "#38bdf8"}]
        },
        %{
          name: :back,
          parent: :mid,
          joint: {:hinge, 4, {0.0, 0.0, 1.0}},
          attach: {0.2, 0.0, 0.0},
          mass: 0.6,
          com: {0.1, 0.0, 0.0},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.2, 0.0, 0.0}, 0.035, "#7dd3fc"}]
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
