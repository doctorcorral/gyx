defmodule Gyx.Environments.Gym do
  @moduledoc """
  This module is an API for accessing
  Python OpenAI Gym methods
  """
  alias Gyx.Helpers.Python
  alias Gyx.Core.{Env, Exp}
  alias Gyx.Core.Spaces.{Discrete, Box, Tuple}
  import Gyx.Gym.Utils, only: [gyx_space: 1]
  use Env
  use GenServer
  require Logger

  defstruct env: nil,
            current_state: nil,
            session: nil,
            action_space: nil,
            observation_space: nil

  @type space :: Discrete.t() | Box.t() | Tuple.t()
  @type t :: %__MODULE__{
          env: any(),
          current_state: any(),
          session: pid(),
          action_space: space(),
          observation_space: space()
        }

  @impl true
  def init(reference_name) do
    python_session = Python.start()

    name =
      case reference_name do
        nil -> inspect(self())
        name -> ":#{name}"
      end

    Logger.warn(inspect(self()))
    Logger.warn("Gym environment not associated yet with current #{__MODULE__} process")
    Logger.warn("In order to assign a Gym environment to this process,
    please use #{__MODULE__}.make(#{name}, \"ENVIRONMENTNAME\")\n")

    {:ok,
     %__MODULE__{
       env: nil,
       current_state: nil,
       session: python_session,
       action_space: nil,
       observation_space: nil
     }}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, opts[:name], opts)
  end

  def render(environment) do
    GenServer.call(environment, {:render, :python})
  end

  def render(environment, output_device) do
    GenServer.call(environment, {:render, output_device})
  end

  def render(environment, output_device, opts) do
    GenServer.call(environment, {:render, output_device, opts})
  end

  def make(environment, environment_name) do
    GenServer.call(environment, {:make, environment_name})
  end

  @impl true
  def reset(environment) do
    GenServer.call(environment, :reset)
  end

  def getRGB(environment) do
    GenServer.call(environment, :get_rgb)
  end

  def handle_call(
        {:make, environment_name},
        _from,
        %{session: session}
      ) do
    Logger.info("Starting OpenAI Gym environment: " <> environment_name, ansi_color: :magenta)

    {env, initial_state, action_space, observation_space} =
      Python.call(
        session,
        :gym_interface,
        :make,
        [environment_name]
      )

    Logger.info("Environment created on Python process: " <> inspect(session),
      ansi_color: :magenta
    )

    {:reply, :ok,
     %__MODULE__{
       env: env,
       current_state: initial_state,
       session: session,
       action_space: gyx_space(action_space),
       observation_space: gyx_space(observation_space)
     }}
  end

  def handle_call({:act, action}, _from, state) do
    {next_env, {gym_state, reward, done, info}} =
      Python.call(
        state.session,
        :gym_interface,
        :step,
        [state.env, action]
      )

    experience = %Exp{
      state: state.current_state,
      action: action,
      next_state: gym_state,
      reward: reward,
      done: done,
      info: %{gym_info: info}
    }

    {:reply, experience, %{state | env: next_env, current_state: gym_state}}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    {env, initial_state, action_space, observation_space} =
      Python.call(state.session, :gym_interface, :reset, [state.env])

    {:reply, %Exp{},
     %{
       state
       | env: env,
         current_state: initial_state,
         action_space: gyx_space(action_space),
         observation_space: gyx_space(observation_space)
     }}
  end

  def handle_call({:render, :python}, _from, state) do
    Python.call(state.session, :gym_interface, :render, [state.env])
    {:noreply, state}
  end

  def handle_call({:render, :terminal}, _from, state) do
    with rgb <- get_rgb(state.session, state.env) do
      rgb
      |> Matrex.resize(0.5)
      |> Matrex.heatmap(:color8)
      |> (fn _ -> :ok end).()
    end

    {:noreply, state}
  end

  def handle_call({:render, :terminal, [scale: scale]}, _from, state) do
    with rgb <- get_rgb(state.session, state.env) do
      rgb
      |> Matrex.resize(scale)
      |> Matrex.heatmap(:color8)
      |> (fn _ -> :ok end).()
    end

    {:noreply, state}
  end

  def handle_call(:get_rgb, _from, state) do
    screen_rgb = get_rgb(state.session, state.env)
    {:reply, screen_rgb, state}
  end

  def handle_call(:observe, _from, state), do: {:reply, state.current_state, state}

  defp get_rgb(python_session, env) do
    with rgb_matrix <- Python.call(python_session, :gym_interface, :getScreenRGB2, [env]) do
      rgb_matrix
      |> Matrex.new()
    end
  end
end
