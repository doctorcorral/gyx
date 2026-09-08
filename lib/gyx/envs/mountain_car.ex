defmodule Gyx.Envs.MountainCar do
  @moduledoc """
  MountainCar-v0, matching Gymnasium's physics.

  Observation is `{position, velocity}`. Actions: `0` push left, `1`
  coast, `2` push right. Reward is `-1` per step until the flag at
  position `0.5`, then the episode terminates. Truncates at 200 steps.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.{Box, Discrete}
  alias Gyx.RNG

  @min_position -1.2
  @max_position 0.6
  @max_speed 0.07
  @goal_position 0.5
  @goal_velocity 0.0
  @force 0.001
  @gravity 0.0025
  @max_episode_steps 200

  defstruct position: -0.5,
            velocity: 0.0,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Discrete{n: 3},
            observation_space: %Box{
              shape: {2},
              low: {@min_position, -@max_speed},
              high: {@max_position, @max_speed}
            }

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "MountainCar-v0",
      observation_space: %Box{
        shape: {2},
        low: {@min_position, -@max_speed},
        high: {@max_position, @max_speed}
      },
      action_space: %Discrete{n: 3},
      max_episode_steps: @max_episode_steps,
      reward_threshold: -110.0
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

    {position, rng} = RNG.uniform_range(rng, -0.6, -0.4)
    env = %{env | position: position, velocity: 0.0, steps: 0, rng: rng}
    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{position: position, velocity: velocity}), do: {position, velocity}

  @impl true
  def step(env, action) do
    if Gyx.Core.Spaces.contains?(env.action_space, action) do
      do_step(env, action)
    else
      {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :svg), do: {:ok, Gyx.Render.MountainCar.svg(env)}
  def render(env, :ansi), do: {:ok, Gyx.Render.MountainCar.ansi(env)}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  defp do_step(env, action) do
    obs = observe(env)
    force = (action - 1) * @force
    velocity = env.velocity + force - :math.cos(3 * env.position) * @gravity
    velocity = clamp(velocity, -@max_speed, @max_speed)
    position = clamp(env.position + velocity, @min_position, @max_position)
    velocity = if position == @min_position and velocity < 0, do: 0.0, else: velocity

    env = %{env | position: position, velocity: velocity, steps: env.steps + 1}
    terminated = position >= @goal_position and velocity >= @goal_velocity
    truncated = not terminated and env.steps >= env.max_episode_steps

    {:ok, env,
     %Exp{
       observation: obs,
       action: action,
       reward: -1.0,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps}
     }}
  end

  defp clamp(x, lo, hi), do: x |> max(lo) |> min(hi)
end
