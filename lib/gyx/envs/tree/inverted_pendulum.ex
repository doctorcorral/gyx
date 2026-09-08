defmodule Gyx.Envs.Tree.InvertedPendulum do
  @moduledoc """
  Approximate tree backend (`tree/` id).

  InvertedPendulum-v4, Gymnasium-shaped.

  Continuous cart force in `[-3, 3]`. Observation is
  `{x, θ, ẋ, θ̇}` with `θ = 0` upright. Reward is `+1` while
  `|θ| ≤ 0.2`. Integer actions `0/1/2` map to `-3/0/+3`.
  """

  use Gyx.Env

  alias Gyx.Core.Exp
  alias Gyx.Core.Spaces.Box
  alias Gyx.Envs.Mujoco
  alias Gyx.RNG

  @gravity 9.81
  @masscart 1.0
  @masspole 0.1
  @total @masscart + @masspole
  @length 0.3
  @polemass_length @masspole * @length
  @tau 0.02
  @force_max 3.0
  @theta_limit 0.2
  @max_episode_steps 1000

  defstruct x: 0.0,
            x_dot: 0.0,
            theta: 0.0,
            theta_dot: 0.0,
            last_u: 0.0,
            steps: 0,
            rng: nil,
            max_episode_steps: @max_episode_steps,
            action_space: %Box{shape: {1}, low: -@force_max, high: @force_max},
            observation_space: %Box{shape: {4}, low: -1.0e38, high: 1.0e38}

  @type t :: %__MODULE__{}

  @impl true
  def spec do
    %{
      id: "tree/InvertedPendulum-v4",
      observation_space: %Box{shape: {4}, low: -1.0e38, high: 1.0e38},
      action_space: %Box{shape: {1}, low: -@force_max, high: @force_max},
      max_episode_steps: @max_episode_steps,
      reward_threshold: 950.0
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
    {noise, rng} = Mujoco.noise(rng, 4, Keyword.get(opts, :reset_noise_scale, 0.01))

    env = %{
      env
      | x: elem(noise, 0),
        theta: elem(noise, 1),
        x_dot: elem(noise, 2),
        theta_dot: elem(noise, 3),
        last_u: 0.0,
        steps: 0,
        rng: rng
    }

    {env, observe(env), %{}}
  end

  @impl true
  def observe(%__MODULE__{x: x, theta: theta, x_dot: x_dot, theta_dot: theta_dot}) do
    {x, theta, x_dot, theta_dot}
  end

  @impl true
  def step(env, action) do
    case Mujoco.decode_action(action, 1, -@force_max, @force_max) do
      {:ok, {u}} -> do_step(env, u)
      :error -> {:error, :invalid_action}
    end
  end

  @impl true
  def render(env, :scene), do: Mujoco.render_scene({env.x, env.theta}, model(), track: :cart, distance: 2.4)
  def render(env, :svg), do: Mujoco.render_svg({env.x, env.theta}, model(), "tree/InvertedPendulum-v4")
  def render(env, :ansi), do: {:ok, "InvertedPendulum x=#{Float.round(env.x, 3)} θ=#{Float.round(env.theta, 3)}"}
  def render(env, :text), do: render(env, :ansi)
  def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

  def discrete_actions, do: Mujoco.discrete_actions(1, -@force_max, @force_max)

  defp do_step(env, force) do
    obs = observe(env)
    costheta = :math.cos(env.theta)
    sintheta = :math.sin(env.theta)

    temp =
      (force + @polemass_length * env.theta_dot * env.theta_dot * sintheta) / @total

    thetaacc =
      (@gravity * sintheta - costheta * temp) /
        (@length * (4.0 / 3.0 - @masspole * costheta * costheta / @total))

    xacc = temp - @polemass_length * thetaacc * costheta / @total

    env = %{
      env
      | x: env.x + @tau * env.x_dot,
        x_dot: env.x_dot + @tau * xacc,
        theta: env.theta + @tau * env.theta_dot,
        theta_dot: env.theta_dot + @tau * thetaacc,
        last_u: force,
        steps: env.steps + 1
    }

    terminated = abs(env.theta) > @theta_limit
    truncated = not terminated and env.steps >= env.max_episode_steps
    reward = if terminated, do: 0.0, else: 1.0

    {:ok, env,
     %Exp{
       observation: obs,
       action: force,
       reward: reward,
       next_observation: observe(env),
       terminated: terminated,
       truncated: truncated,
       info: %{steps: env.steps, reward_survive: reward}
     }}
  end

  defp model do
    %{
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
          name: :pole,
          parent: :cart,
          joint: {:hinge, 1, {0.0, 1.0, 0.0}},
          attach: {0.0, 0.0, 0.1},
          mass: 0.1,
          com: {0.0, 0.0, 0.3},
          geoms: [{:capsule, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.6}, 0.045, "#4f46e5"}]
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
