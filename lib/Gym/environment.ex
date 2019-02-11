defmodule Gyx.Gym.Environment do
  @moduledoc """
  This module is an API for accessing
  Python OpenAI Gym methods
  """
  alias Gyx.Python.Helper
  alias Gyx.Framework.Env
  use Env
  use GenServer
  alias Gyx.Experience.Exp
  require Logger
  defstruct env: nil, state: nil

  @type t :: %__MODULE__{
          env: any(),
          state: any()
        }

  @impl true
  def init(_) do
    Logger.warn("Gym environment not associated yet with current process")
    Logger.info("In order to assign a Gym environment to this process,
    please use #{__MODULE__}.make(ENVIRONMENTNAME)")
    {:ok, %__MODULE__{env: nil, state: nil}}
  end

  def start_link(_, opts) do
    GenServer.start_link(__MODULE__, %__MODULE__{}, opts)
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

  def handle_call({:make, environment_name}, _from, _state) do
    {env, initial_state} =
      Helper.call_python(
        :gym_interface,
        :make,
        [environment_name]
      )

    {:reply, initial_state, %__MODULE__{env: env, state: initial_state}}
  end

  def handle_call({:act, action}, _from, state) do
    {next_env, {gym_state, reward, done, info}} =
      Helper.call_python(
        :gym_interface,
        :step,
        [state.env, action]
      )

    experience = %Exp{
      state: state.state,
      action: action,
      next_state: gym_state,
      reward: reward,
      done: done,
      info: %{gym_info: info}
    }

    {:reply, experience, %__MODULE__{env: next_env, state: gym_state}}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    {env, state} = Helper.call_python(:gym_interface, :reset, [state.env])
    {:reply, %Exp{}, %__MODULE__{env: env, state: state}}
  end

  def handle_call(:render, _from, state) do
    Helper.call_python(:gym_interface, :render, [state.env])
    {:reply, state.state, state}
  end

  def handle_call(:get_state, _from, state), do: {:reply, state, state}
end
