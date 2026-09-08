defmodule Gyx.Envs.MjEnv do
  @moduledoc false

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      use Gyx.Env

      alias Gyx.Core.Exp
      alias Gyx.Core.Spaces.Box
      alias Gyx.Envs.Mujoco
      alias Gyx.Physics.Mj
      alias Gyx.RNG
      alias Gyx.Render.Scene

      @xml Keyword.fetch!(opts, :xml)
      @env_id Keyword.fetch!(opts, :id)
      @frame_skip Keyword.fetch!(opts, :frame_skip)
      @obs_n Keyword.fetch!(opts, :obs)
      @act_n Keyword.fetch!(opts, :act)
      @act_low Keyword.get(opts, :act_low, -1.0)
      @act_high Keyword.get(opts, :act_high, 1.0)
      @max_steps Keyword.get(opts, :max_steps, 1000)
      @reward_threshold Keyword.get(opts, :reward_threshold)
      @view Keyword.get(opts, :view, :xz)
      @track Keyword.get(opts, :track, "torso")
      @distance Keyword.get(opts, :distance, 3.2)
      @water Keyword.get(opts, :water, false)
      @ground Keyword.get(opts, :ground, true)

      defstruct data: nil,
                model: nil,
                last_u: nil,
                steps: 0,
                rng: nil,
                extras: %{},
                max_episode_steps: @max_steps,
                action_space: %Box{shape: {@act_n}, low: @act_low, high: @act_high},
                observation_space: %Box{shape: {@obs_n}, low: -1.0e38, high: 1.0e38}

      @type t :: %__MODULE__{}

      @impl true
      def spec do
        spec = %{
          id: @env_id,
          observation_space: %Box{shape: {@obs_n}, low: -1.0e38, high: 1.0e38},
          action_space: %Box{shape: {@act_n}, low: @act_low, high: @act_high},
          max_episode_steps: @max_steps
        }

        if @reward_threshold, do: Map.put(spec, :reward_threshold, @reward_threshold), else: spec
      end

      @impl true
      def new(opts \\ []) do
        model = Mj.load(@xml)

        reset(
          %__MODULE__{
            model: model,
            max_episode_steps: Keyword.get(opts, :max_episode_steps, @max_steps),
            action_space: %Box{shape: {@act_n}, low: @act_low, high: @act_high},
            observation_space: %Box{shape: {@obs_n}, low: -1.0e38, high: 1.0e38}
          },
          opts
        )
        |> elem(0)
      end

      @impl true
      def reset(env, opts \\ []) do
        rng = rng(env, opts)
        model = env.model || Mj.load(@xml)

        {qpos, qvel, extras, rng} =
          cond do
            Keyword.has_key?(opts, :qpos) ->
              {Keyword.fetch!(opts, :qpos), Keyword.get(opts, :qvel, model.init_qvel), %{}, rng}

            true ->
              reset_model(rng, model)
          end

        data = Mj.data(model, qpos, qvel) |> Mj.forward(model)
        env = %{env | model: model, data: data, last_u: Mujoco.zeros(@act_n), steps: 0, rng: rng, extras: extras}
        {env, observe(env), %{}}
      end

      @impl true
      def step(env, action) do
        case Mujoco.decode_action(action, @act_n, @act_low, @act_high) do
          {:ok, u} -> do_step(env, u)
          :error -> {:error, :invalid_action}
        end
      end

      @impl true
      def render(env, :scene) do
        geoms = Mj.world_geoms(env.model, env.data.qpos, extras: render_extras(env))
        track = Mj.track_pos(env.model, env.data.qpos, @track)

        {:ok,
         Scene.from_world(geoms,
           track_pos: track,
           distance: @distance,
           ground: @ground,
           water: @water
         )}
      end

      def render(env, :svg) do
        geoms = Mj.world_geoms(env.model, env.data.qpos)
        {:ok, Scene.svg_world(geoms, @env_id, @view)}
      end

      def render(env, :ansi), do: {:ok, "#{@env_id} #{inspect(observe(env))}"}
      def render(env, :text), do: render(env, :ansi)
      def render(_env, mode), do: {:error, {:unsupported_render_mode, mode}}

      def discrete_actions, do: Mujoco.discrete_actions(@act_n, @act_low, @act_high)

      def observe(%{data: data}) do
        data.qpos
      end

      def reset_model(rng, model), do: {model.init_qpos, model.init_qvel, %{}, rng}
      def reward(_env, _before, _after, _u), do: {0.0, %{}}
      def terminated?(_env), do: false
      def render_extras(_env), do: []

      defoverridable observe: 1, reset_model: 2, reward: 4, terminated?: 1, render_extras: 1

      defp do_step(env, u) do
        obs = observe(env)
        before = env.data
        data = Mj.set_ctrl(before, u)
        data = Mj.step(env.model, data, @frame_skip)
        env = %{env | data: data, last_u: u, steps: env.steps + 1}
        {reward, info} = reward(env, before, env.data, u)
        terminated = terminated?(env)
        truncated = env.steps >= env.max_episode_steps
        truncated = if terminated, do: false, else: truncated

        {:ok, env,
         %Exp{
           observation: obs,
           action: if(@act_n == 1, do: elem(u, 0), else: u),
           reward: reward,
           next_observation: observe(env),
           terminated: terminated,
           truncated: truncated,
           info: Map.merge(%{steps: env.steps}, info)
         }}
      end

      defp rng(env, opts) do
        case Keyword.fetch(opts, :seed) do
          {:ok, seed} -> RNG.seed(seed)
          :error -> env.rng || RNG.seed(nil)
        end
      end

      defp clip_tuple(t, lo, hi) do
        t
        |> Tuple.to_list()
        |> Enum.map(&min(max(&1, lo), hi))
        |> List.to_tuple()
      end

      defp noise_list(rng, n, scale) do
        Enum.map_reduce(1..n, rng, fn _, rng ->
          RNG.uniform_range(rng, -scale, scale)
        end)
      end

      defp add_noise(base, noise) do
        base
        |> Tuple.to_list()
        |> Enum.zip(noise)
        |> Enum.map(fn {a, b} -> a + b end)
        |> List.to_tuple()
      end

      defp normal_list(rng, n, scale) do
        Enum.map_reduce(1..n, rng, fn _, rng ->
          {z, rng} = RNG.normal(rng)
          {z * scale, rng}
        end)
      end
    end
  end
end
