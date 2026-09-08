defmodule Gyx.Envs.Acrobot do
  @moduledoc """
  Acrobot-v1, matching Gymnasium / Sutton & Barto book dynamics.

  Observation is `{cos θ1, sin θ1, cos θ2, sin θ2, θ1̇, θ2̇}`. Actions
  apply `-1 / 0 / +1` torque on the second joint. Reward is `-1` until
  the tip swings above the target height, then `0` and terminate.
  Truncates at 500 steps.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.{Box, Discrete}
  alias Gyx.RNG

  @dt 0.2
  @link_length_1 1.0
  @link_mass_1 1.0
  @link_mass_2 1.0
  @link_com_1 0.5
  @link_com_2 0.5
  @link_moi 1.0
  @max_vel_1 4 * :math.pi()
  @max_vel_2 9 * :math.pi()
  @torques {-1.0, 0.0, 1.0}
  @max_episode_steps 500
  @g 9.8

  defstruct theta1: 0.0,
            theta2: 0.0,
            dtheta1: 0.0,
            dtheta2: 0.0,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Discrete{n: 3},
            observation_space: %Box{
              shape: {6},
              low: {-1.0, -1.0, -1.0, -1.0, -@max_vel_1, -@max_vel_2},
              high: {1.0, 1.0, 1.0, 1.0, @max_vel_1, @max_vel_2}
            }

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "Acrobot-v1",
      observation_space: %Box{
        shape: {6},
        low: {-1.0, -1.0, -1.0, -1.0, -@max_vel_1, -@max_vel_2},
        high: {1.0, 1.0, 1.0, 1.0, @max_vel_1, @max_vel_2}
      },
      action_space: %Discrete{n: 3},
      max_episode_steps: @max_episode_steps,
      reward_threshold: -100.0
    }
  end

  @impl true
  def new(opts \\ []) do
    reset(
      %__MODULE__{max_episode_steps: Keyword.get(opts, :max_episode_steps, @max_episode_steps)},
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

    {theta1, rng} = RNG.uniform_range(rng, -0.1, 0.1)
    {theta2, rng} = RNG.uniform_range(rng, -0.1, 0.1)
    {dtheta1, rng} = RNG.uniform_range(rng, -0.1, 0.1)
    {dtheta2, rng} = RNG.uniform_range(rng, -0.1, 0.1)

    env = %{
      env
      | theta1: theta1,
        theta2: theta2,
        dtheta1: dtheta1,
        dtheta2: dtheta2,
        steps: 0,
        rng: rng
    }

    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{} = env) do
    {:math.cos(env.theta1), :math.sin(env.theta1), :math.cos(env.theta2), :math.sin(env.theta2),
     env.dtheta1, env.dtheta2}
  end

  @impl true
  def step(env, action) do
    if Gyx.Core.Spaces.contains?(env.action_space, action) do
      do_step(env, action)
    else
      {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :svg), do: {:ok, Gyx.Render.Acrobot.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.Acrobot.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  defp do_step(env, action) do
    obs = observe(env)
    torque = elem(@torques, action)
    {theta1, theta2, dtheta1, dtheta2} = rk4(env, torque)

    env = %{
      env
      | theta1: wrap(theta1),
        theta2: wrap(theta2),
        dtheta1: bound(dtheta1, -@max_vel_1, @max_vel_1),
        dtheta2: bound(dtheta2, -@max_vel_2, @max_vel_2),
        steps: env.steps + 1
    }

    terminated = tip_height(env) > 1.0
    truncated = not terminated and env.steps >= env.max_episode_steps
    reward = if terminated, do: 0.0, else: -1.0

    {:ok, env,
     %Exp{
       observation: obs,
       action: action,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps}
     }}
  end

  def tip_height(%__MODULE__{theta1: t1, theta2: t2}) do
    -:math.cos(t1) - :math.cos(t2 + t1)
  end

  defp rk4(env, torque) do
    y0 = {env.theta1, env.theta2, env.dtheta1, env.dtheta2, torque}
    dt = @dt
    dt2 = dt / 2.0
    k1 = dsdt(y0)
    k2 = dsdt(add(y0, scale(k1, dt2)))
    k3 = dsdt(add(y0, scale(k2, dt2)))
    k4 = dsdt(add(y0, scale(k3, dt)))

    y =
      add(
        y0,
        scale(
          add(add(k1, scale(k2, 2.0)), add(scale(k3, 2.0), k4)),
          dt / 6.0
        )
      )

    {elem(y, 0), elem(y, 1), elem(y, 2), elem(y, 3)}
  end

  defp dsdt({theta1, theta2, dtheta1, dtheta2, a}) do
    d1 =
      @link_mass_1 * @link_com_1 * @link_com_1 +
        @link_mass_2 *
          (@link_length_1 * @link_length_1 + @link_com_2 * @link_com_2 +
             2 * @link_length_1 * @link_com_2 * :math.cos(theta2)) + @link_moi + @link_moi

    d2 =
      @link_mass_2 *
        (@link_com_2 * @link_com_2 + @link_length_1 * @link_com_2 * :math.cos(theta2)) + @link_moi

    phi2 = @link_mass_2 * @link_com_2 * @g * :math.cos(theta1 + theta2 - :math.pi() / 2.0)

    phi1 =
      -@link_mass_2 * @link_length_1 * @link_com_2 * dtheta2 * dtheta2 * :math.sin(theta2) -
        2 * @link_mass_2 * @link_length_1 * @link_com_2 * dtheta2 * dtheta1 * :math.sin(theta2) +
        (@link_mass_1 * @link_com_1 + @link_mass_2 * @link_length_1) * @g *
          :math.cos(theta1 - :math.pi() / 2) + phi2

    ddtheta2 =
      (a + d2 / d1 * phi1 -
         @link_mass_2 * @link_length_1 * @link_com_2 * dtheta1 * dtheta1 *
           :math.sin(theta2) - phi2) /
        (@link_mass_2 * @link_com_2 * @link_com_2 + @link_moi - d2 * d2 / d1)

    ddtheta1 = -(d2 * ddtheta2 + phi1) / d1
    {dtheta1, dtheta2, ddtheta1, ddtheta2, 0.0}
  end

  defp add({a, b, c, d, e}, {f, g, h, i, j}), do: {a + f, b + g, c + h, d + i, e + j}
  defp scale({a, b, c, d, e}, s), do: {a * s, b * s, c * s, d * s, e * s}

  defp wrap(x) do
    pi = :math.pi()
    two_pi = 2 * pi
    x = x - two_pi * Float.floor((x + pi) / two_pi)
    x
  end

  defp bound(x, low, high), do: min(max(x, low), high)
end
