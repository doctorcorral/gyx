defmodule Gyx.Gym.Environment do
  @moduledoc """
  This module is an API for accessing
  Python OpenAI Gym methods
  """
  alias Gyx.Python.HelperAsync
  alias Gyx.Core.{Env, Exp}
  import Gyx.Gym.Utils, only: [gyx_space: 1]
  use Env
  use GenServer
  require Logger
  defstruct env: nil, current_state: nil, session: nil, action_space: nil

  @type t :: %__MODULE__{
          env: any(),
          current_state: any(),
          session: any(),
          action_space: any()
        }

  @impl true
  def init(_) do
    python_session = HelperAsync.start()
    Logger.warn("Gym environment not associated yet with current #{__MODULE__} process")
    Logger.info("In order to assign a Gym environment to this process,
    please use #{__MODULE__}.make(ENVIRONMENTNAME)\n")
    HelperAsync.call(python_session, :test, :register_handler, [self()])

    {:ok, %__MODULE__{env: nil, current_state: nil, session: python_session, action_space: nil}}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{action_space: nil}, opts)
  end

  def render() do
    GenServer.call(__MODULE__, :render)
  end

  def make(environment_name) do
    GenServer.call(__MODULE__, {:make, environment_name})
  end

  @impl true
  def step(action) do
    GenServer.call(__MODULE__, {:act, action})
  end

  @impl true
  def reset() do
    GenServer.call(__MODULE__, :reset)
  end

  def handle_call({:make, environment_name}, _from, state) do
    {env, initial_state, action_space} =
      HelperAsync.call(
        state.session,
        :gym_interface,
        :make,
        [environment_name]
      )

    {:reply, initial_state,
     %__MODULE__{
       env: env,
       current_state: initial_state,
       session: state.session,
       action_space: gyx_space(action_space)
     }}
  end

  def handle_call({:act, action}, _from, state) do
    {next_env, {gym_state, reward, done, info}} =
      HelperAsync.call(
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
    {env, initial_state, action_space} =
      HelperAsync.call(state.session, :gym_interface, :reset, [state.env])

    {:reply, %Exp{},
     %{state | env: env, current_state: initial_state, action_space: action_space}}
  end

  def handle_call(:render, _from, state) do
    HelperAsync.call(state.session, :gym_interface, :render, [state.env])
    {:reply, state.current_state, state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call(:observe, _from, state), do: {:reply, state.current_state, state}
end
