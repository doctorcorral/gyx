defmodule Gyx.Envs.Pendulum do
  @moduledoc """
  Pendulum-v1, matching Gymnasium's physics.

  Observation is `{cos(θ), sin(θ), θ̇}` with `θ = 0` upright. The
  action is a torque in `[-2, 2]`. Integer actions `0/1/2` map to
  `-2/0/+2` so tabular agents can share the playground buttons.
  Reward is `-(θ² + 0.1 θ̇² + 0.001 τ²)`. Truncates at 200 steps.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.RNG

  @max_speed 8.0
  @max_torque 2.0
  @dt 0.05
  @mass 1.0
  @length 1.0
  @max_episode_steps 200
  @discrete_torques {-2.0, 0.0, 2.0}

  defstruct theta: 0.0,
            theta_dot: 0.0,
            last_u: 0.0,
            steps: 0,
            g: 10.0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {1}, low: -@max_torque, high: @max_torque},
            observation_space: %Box{
              shape: {3},
              low: {-1.0, -1.0, -@max_speed},
              high: {1.0, 1.0, @max_speed}
            }

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "Pendulum-v1",
      observation_space: %Box{
        shape: {3},
        low: {-1.0, -1.0, -@max_speed},
        high: {1.0, 1.0, @max_speed}
      },
      action_space: %Box{shape: {1}, low: -@max_torque, high: @max_torque},
      max_episode_steps: @max_episode_steps,
      reward_threshold: -200.0
    }
  end

  @impl true
  def new(opts \\ []) do
    reset(
      %__MODULE__{
        g: Keyword.get(opts, :g, 10.0),
        max_episode_steps: Keyword.get(opts, :max_episode_steps, @max_episode_steps)
      },
      opts
    )
    |> elem(0)
  end

  @impl true
  def reset(env, opts \\ []) do
    rng =
      case Keyword.fetch(opts, :seed) do
        {:ok, seed} -> RNG.seed(seed)
        :error -> env.rng || RNG.seed(nil)
      end

    {theta, rng} = RNG.uniform_range(rng, -:math.pi(), :math.pi())
    {theta_dot, rng} = RNG.uniform_range(rng, -1.0, 1.0)

    env = %{env | theta: theta, theta_dot: theta_dot, last_u: 0.0, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{theta: theta, theta_dot: theta_dot}) do
    {:math.cos(theta), :math.sin(theta), theta_dot}
  end

  @impl true
  def step(env, action) do
    case decode_action(action) do
      {:ok, u} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :svg), do: {:ok, Gyx.Render.Pendulum.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.Pendulum.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Tuple.to_list(@discrete_torques)

  defp do_step(env, u) do
    obs = observe(env)
    u = min(max(u, -@max_torque), @max_torque)
    th = env.theta
    thdot = env.theta_dot

    costs = angle_normalize(th) ** 2 + 0.1 * thdot * thdot + 0.001 * u * u

    newthdot =
      thdot +
        (3 * env.g / (2 * @length) * :math.sin(th) + 3.0 / (@mass * @length * @length) * u) *
          @dt

    newthdot = min(max(newthdot, -@max_speed), @max_speed)
    newth = th + newthdot * @dt

    env = %{env | theta: newth, theta_dot: newthdot, last_u: u, steps: env.steps + 1}
    truncated = env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: u,
       reward: -costs,
       next_observation: observe(env),
       terminated: false,
       truncated: truncated,
       info: %{steps: env.steps}
     }}
  end

  defp decode_action(i) when i in 0..2, do: {:ok, elem(@discrete_torques, i)}
  defp decode_action(u) when is_number(u), do: {:ok, u * 1.0}
  defp decode_action({u}) when is_number(u), do: {:ok, u * 1.0}
  defp decode_action([u]) when is_number(u), do: {:ok, u * 1.0}
  defp decode_action(_), do: :error

  defp angle_normalize(x) do
    two_pi = 2 * :math.pi()
    x = x + :math.pi()
    x = x - two_pi * Float.floor(x / two_pi)
    x - :math.pi()
  end
end
