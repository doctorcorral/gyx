defmodule Gyx.Envs.CartPole do
  @moduledoc """
  CartPole-v1, matching Gymnasium's physics.

  Observation is `{x, x_dot, theta, theta_dot}`. Actions are `0` (left)
  and `1` (right). The episode terminates when the cart leaves `±2.4` or
  the pole angle exceeds `±12°`, and truncates at 500 steps.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.{Box, Discrete}
  alias Gyx.RNG

  @gravity 9.8
  @masscart 1.0
  @masspole 0.1
  @total_mass @masscart + @masspole
  @length 0.5
  @polemass_length @masspole * @length
  @force_mag 10.0
  @tau 0.02
  @theta_threshold_radians 12 * 2 * :math.pi() / 360
  @x_threshold 2.4
  @max_episode_steps 500
  @reset_span 0.05

  defstruct x: 0.0,
            x_dot: 0.0,
            theta: 0.0,
            theta_dot: 0.0,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Discrete{n: 2},
            observation_space: %Box{
              shape: {4},
              low: {-4.8, -3.4e38, -0.418, -3.4e38},
              high: {4.8, 3.4e38, 0.418, 3.4e38}
            }

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "CartPole-v1",
      observation_space: %Box{
        shape: {4},
        low: {-4.8, -3.4e38, -0.418, -3.4e38},
        high: {4.8, 3.4e38, 0.418, 3.4e38}
      },
      action_space: %Discrete{n: 2},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 475.0
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

    {x, rng} = RNG.uniform_range(rng, -@reset_span, @reset_span)
    {x_dot, rng} = RNG.uniform_range(rng, -@reset_span, @reset_span)
    {theta, rng} = RNG.uniform_range(rng, -@reset_span, @reset_span)
    {theta_dot, rng} = RNG.uniform_range(rng, -@reset_span, @reset_span)

    env = %{env | x: x, x_dot: x_dot, theta: theta, theta_dot: theta_dot, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{x: x, x_dot: x_dot, theta: theta, theta_dot: theta_dot}) do
    {x, x_dot, theta, theta_dot}
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
  def render(env, :svg), do: {:ok, Gyx.Render.CartPole.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.CartPole.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  defp do_step(env, action) do
    obs = observe(env)
    force = if action == 1, do: @force_mag, else: -@force_mag
    costheta = :math.cos(env.theta)
    sintheta = :math.sin(env.theta)

    temp =
      (force + @polemass_length * env.theta_dot * env.theta_dot * sintheta) / @total_mass

    thetaacc =
      (@gravity * sintheta - costheta * temp) /
        (@length * (4.0 / 3.0 - @masspole * costheta * costheta / @total_mass))

    xacc = temp - @polemass_length * thetaacc * costheta / @total_mass

    env = %{
      env
      | x: env.x + @tau * env.x_dot,
        x_dot: env.x_dot + @tau * xacc,
        theta: env.theta + @tau * env.theta_dot,
        theta_dot: env.theta_dot + @tau * thetaacc,
        steps: env.steps + 1
    }

    terminated =
      env.x < -@x_threshold or env.x > @x_threshold or
        env.theta < -@theta_threshold_radians or env.theta > @theta_threshold_radians

    truncated = not terminated and env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: action,
       reward: 1.0,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps}
     }}
  end
end
