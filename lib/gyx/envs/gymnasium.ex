defmodule Gyx.Envs.Gymnasium do
  @moduledoc """
  Farama Gymnasium wraps (`gymnasium/*` ids).

  * MuJoCo C (`gymnasium/Hopper-v4`, v4 and v5) — real MuJoCo through
    Python so a policy trained in Gyx can be evaluated with
    `gymnasium.make/1` on the same official id (without the prefix).
  * Atari (`gymnasium/ALE/Pong-v5`, …) — ALE/Stella through the same
    Port. Observations are `uint8` Nx tensors; actions are `Discrete`.
    There is no unprefixed or `tree/` Atari id.

  Requires `python3` with `gymnasium`. MuJoCo wraps also need `mujoco`;
  Atari wraps need `ale-py` and the ALE ROMs. Unprefixed `Hopper-v4`
  is the pure-Elixir Farama suite; `tree/Hopper-v4` is the older
  approximate engine.
  """

  alias Gyx.Gymnasium.Bridge

  @entries [
    {"InvertedPendulum-v4", 4, 1, -3.0, 3.0, 1000},
    {"InvertedPendulum-v5", 4, 1, -3.0, 3.0, 1000},
    {"InvertedDoublePendulum-v4", 11, 1, -1.0, 1.0, 1000},
    {"InvertedDoublePendulum-v5", 9, 1, -1.0, 1.0, 1000},
    {"Reacher-v4", 11, 2, -1.0, 1.0, 50},
    {"Reacher-v5", 10, 2, -1.0, 1.0, 50},
    {"Swimmer-v4", 8, 2, -1.0, 1.0, 1000},
    {"Swimmer-v5", 8, 2, -1.0, 1.0, 1000},
    {"Hopper-v4", 11, 3, -1.0, 1.0, 1000},
    {"Hopper-v5", 11, 3, -1.0, 1.0, 1000},
    {"Walker2d-v4", 17, 6, -1.0, 1.0, 1000},
    {"Walker2d-v5", 17, 6, -1.0, 1.0, 1000},
    {"HalfCheetah-v4", 17, 6, -1.0, 1.0, 1000},
    {"HalfCheetah-v5", 17, 6, -1.0, 1.0, 1000},
    {"Ant-v4", 27, 8, -1.0, 1.0, 1000},
    {"Ant-v5", 105, 8, -1.0, 1.0, 1000}
  ]

  # {gym_id, n_actions, max_episode_steps}
  @atari [
    {"ALE/Pong-v5", 6, 108_000},
    {"ALE/Breakout-v5", 4, 108_000},
    {"ALE/SpaceInvaders-v5", 6, 108_000},
    {"ALE/MsPacman-v5", 9, 108_000}
  ]

  def entries, do: @entries
  def atari_entries, do: @atari
  def ids, do: mujoco_ids() ++ atari_ids()
  def mujoco_ids, do: Enum.map(@entries, fn {id, _, _, _, _, _} -> "gymnasium/#{id}" end)
  def atari_ids, do: Enum.map(@atari, fn {id, _, _} -> "gymnasium/#{id}" end)
  def available?, do: Bridge.capabilities().mujoco
  def atari_available?, do: Bridge.capabilities().atari

  def registry, do: Map.merge(mujoco_registry(), atari_registry())

  def mujoco_registry do
    Map.new(@entries, fn {gym_id, _, _, _, _, _} ->
      {"gymnasium/#{gym_id}", module_for(gym_id)}
    end)
  end

  def atari_registry do
    Map.new(@atari, fn {gym_id, _, _} ->
      {"gymnasium/#{gym_id}", module_for(gym_id)}
    end)
  end

  def module_for(gym_id) do
    parts =
      gym_id
      |> String.replace("-", "")
      |> String.split("/")

    Module.concat([__MODULE__ | parts])
  end

  defmodule Client do
    @moduledoc false
    defmacro __using__(opts) do
      quote bind_quoted: [opts: opts] do
        use Gyx.Env

        alias Gyx.Envs.Gymnasium.Impl

        @gym_id Keyword.fetch!(opts, :gym_id)
        @gyx_id Keyword.fetch!(opts, :gyx_id)
        @max_steps Keyword.fetch!(opts, :max_steps)

        @observation_space Keyword.get_lazy(opts, :observation_space, fn ->
          %Gyx.Core.Spaces.Box{shape: {Keyword.fetch!(opts, :obs)}, low: -1.0e38, high: 1.0e38}
        end)

        @action_space Keyword.get_lazy(opts, :action_space, fn ->
          %Gyx.Core.Spaces.Box{
            shape: {Keyword.fetch!(opts, :act)},
            low: Keyword.fetch!(opts, :act_low),
            high: Keyword.fetch!(opts, :act_high)
          }
        end)

        defstruct handle: nil,
                    obs: nil,
                    render?: false,
                    action_space: nil,
                    observation_space: nil,
                    action_meanings: []

        @impl true
        def spec do
          %{
            id: @gyx_id,
            observation_space: @observation_space,
            action_space: @action_space,
            max_episode_steps: @max_steps
          }
        end

        @impl true
        def new(opts), do: Impl.new(__MODULE__, @gym_id, opts)

        @impl true
        def reset(env, opts), do: Impl.reset(env, opts)

        @impl true
        def step(env, action), do: Impl.step(env, action)

        @impl true
        def observe(env), do: env.obs

        @impl true
        def render(env, mode), do: Impl.render(env, mode)
      end
    end
  end

  defmodule Impl do
    @moduledoc false

    alias Gyx.Core.{Exp, Spaces}
    alias Gyx.Core.Spaces.{Box, Discrete}
    alias Gyx.Gymnasium.Bridge
    alias Gyx.Render.Png

    def new(mod, gym_id, opts) do
      {:ok, _} = Bridge.ensure_started()
      render? = Keyword.get(opts, :render, false)

      case Bridge.make(gym_id, render: render?) do
        %{"ok" => true, "handle" => handle} = reply ->
          spec = mod.spec()

          env =
            struct(mod,
              handle: handle,
              obs: nil,
              render?: render?,
              action_space: spec.action_space,
              observation_space: spec.observation_space,
              action_meanings: List.wrap(reply["act_meanings"])
            )

          {env, _obs, _} = reset(env, opts)
          env

        %{"ok" => false, "error" => err} ->
          raise ArgumentError, "Gymnasium #{gym_id}: #{err}"

        {:error, reason} ->
          raise ArgumentError, "Gymnasium bridge: #{inspect(reason)}"
      end
    end

    def reset(env, opts) do
      seed = Keyword.get(opts, :seed)

      case Bridge.reset(env.handle, seed) do
        %{"ok" => true, "obs" => obs, "info" => info} ->
          obs = to_obs(obs)
          {%{env | obs: obs}, obs, stringify_keys(info)}

        other ->
          raise "Gymnasium reset failed: #{inspect(other)}"
      end
    end

    def step(env, action) do
      spec = env.__struct__.spec()

      case encode_action(action, spec.action_space) do
        {:ok, list} ->
          case Bridge.step(env.handle, list) do
            %{
              "ok" => true,
              "obs" => obs,
              "reward" => reward,
              "terminated" => terminated,
              "truncated" => truncated,
              "info" => info
            } ->
              obs = to_obs(obs)

              {:ok, %{env | obs: obs},
               %Exp{
                 observation: env.obs,
                 action: action,
                 reward: reward * 1.0,
                 next_observation: obs,
                 terminated: terminated,
                 truncated: truncated,
                 info: stringify_keys(info)
               }}

            other ->
              raise "Gymnasium step failed: #{inspect(other)}"
          end

        :error ->
          {:error, :invalid_action}
      end
    end

    def render(env, :rgb) do
      case png_view(env) do
        {:ok, png, _w, _h} -> {:ok, png}
        :error -> {:error, :unsupported_render_mode}
      end
    end

    def render(env, :svg) do
      case png_view(env) do
        {:ok, png, w, h} ->
          {:ok,
           ~s(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" role="img"><image href="data:image/png;base64,#{png}" width="#{w}" height="#{h}" style="image-rendering:pixelated"/></svg>)}

        :error ->
          {:error, :unsupported_render_mode}
      end
    end

    def render(env, :ansi), do: {:ok, inspect_obs(env.obs)}
    def render(env, :text), do: render(env, :ansi)
    def render(_env, _mode), do: {:error, :unsupported_render_mode}

    defp png_view(env) do
      case Png.from_tensor(env.obs) do
        {:ok, png} ->
          {h, w, 3} = Nx.shape(env.obs)
          {:ok, Base.encode64(png), w, h}

        :error ->
          case Bridge.render(env.handle) do
            %{"ok" => true, "png" => png, "width" => w, "height" => h} -> {:ok, png, w, h}
            %{"ok" => true, "png" => png} -> {:ok, png, 480, 480}
            _ -> :error
          end
      end
    end

    defp encode_action(action, %Discrete{} = space) do
      if Spaces.contains?(space, action), do: {:ok, action}, else: :error
    end

    defp encode_action(action, %Box{} = space) do
      list =
        cond do
          is_number(action) -> [action * 1.0]
          is_tuple(action) -> Tuple.to_list(action)
          is_list(action) -> action
          true -> :invalid
        end

      cond do
        list == :invalid ->
          :error

        Spaces.contains?(space, List.to_tuple(Enum.map(list, &(&1 * 1.0)))) or
            Spaces.contains?(space, hd(list)) ->
          {:ok, Enum.map(list, &(&1 * 1.0))}

        true ->
          n = elem(space.shape, 0)

          if length(list) == n and Enum.all?(list, &is_number/1) do
            {:ok, Enum.map(list, &(&1 * 1.0))}
          else
            :error
          end
      end
    end

    defp encode_action(_action, _space), do: :error

    defp to_obs(%{"encoding" => "raw", "b64" => b64, "shape" => shape, "dtype" => dtype}) do
      b64
      |> Base.decode64!()
      |> Nx.from_binary(Box.nx_type(dtype))
      |> Nx.reshape(List.to_tuple(shape))
    end

    defp to_obs(list) when is_list(list), do: list |> Enum.map(&(&1 * 1.0)) |> List.to_tuple()
    defp to_obs(n) when is_number(n), do: n * 1.0

    defp inspect_obs(%Nx.Tensor{} = tensor) do
      {type, bits} = Nx.type(tensor)
      dims = tensor |> Nx.shape() |> Tuple.to_list() |> Enum.join("×")
      "#{dims} #{type}#{bits}"
    end

    defp inspect_obs(obs), do: inspect(obs)

    defp stringify_keys(map) when is_map(map) do
      Map.new(map, fn {k, v} -> {k, v} end)
    end

    defp stringify_keys(_), do: %{}
  end

  for {gym_id, obs, act, lo, hi, maxs} <- @entries do
    mod =
      Module.concat([
        __MODULE__
        | gym_id |> String.replace("-", "") |> String.split("/")
      ])

    Module.create(
      mod,
      quote do
        use Gyx.Envs.Gymnasium.Client,
          gym_id: unquote(gym_id),
          gyx_id: unquote("gymnasium/#{gym_id}"),
          obs: unquote(obs),
          act: unquote(act),
          act_low: unquote(lo),
          act_high: unquote(hi),
          max_steps: unquote(maxs)
      end,
      Macro.Env.location(__ENV__)
    )
  end

  for {gym_id, n, maxs} <- @atari do
    mod =
      Module.concat([
        __MODULE__
        | gym_id |> String.replace("-", "") |> String.split("/")
      ])

    Module.create(
      mod,
      quote do
        use Gyx.Envs.Gymnasium.Client,
          gym_id: unquote(gym_id),
          gyx_id: unquote("gymnasium/#{gym_id}"),
          observation_space: %Gyx.Core.Spaces.Box{
            shape: {210, 160, 3},
            low: 0,
            high: 255,
            dtype: :u8
          },
          action_space: %Gyx.Core.Spaces.Discrete{n: unquote(n)},
          max_steps: unquote(maxs)
      end,
      Macro.Env.location(__ENV__)
    )
  end
end
