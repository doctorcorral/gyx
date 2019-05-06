defmodule Gyx.Core.Env do
  @moduledoc """
  This behaviour is intended to be followed for any `Environment` implementation
  The most critical function to be exposed is `step/1` , which serves as a direct bridge
  between the environment and any agent.

  Here, an important design question to address is the fundamental difference between
  the environment state (its internal representation) and an _observation_ of such state.

  In principle, the environment returns an observation as part of step/1 response.

  Should it be a way to obtain an evironment state abstraction as suposed to be shown
  to an agent? i.e. an indirect observation.
  """

  alias Gyx.Core.Exp

  @type initial_state :: Exp.t()
  @type observation :: any()
  @type action :: any()

  @doc "Sets the state of the environment to its default"
  @callback reset() :: initial_state()
  @doc "Gets an environment representation usable by the agent"
  @callback observe() :: observation()
  @doc """
  Recieves an agent's `action` and responds to it,
  informing the agent back with a reward, a modified environment
  and a termination signal
  """
  @callback step(action()) :: Exp.t() | {:error, reason :: String.t()}

  @doc "Retrieves the parameters for current environment state"
  @callback get_state() :: any()

  defmacro __using__(_params) do
    quote do
      @before_compile Gyx.Core.Env
      @behaviour Gyx.Core.Env

      @enforce_keys [:action_space, :observation_space]

      def observe(), do: GenServer.call(__MODULE__, :observe)

      def get_state(), do: GenServer.call(__MODULE__, :get_state)

      @impl true
      def step(action) do
        case action_checked = GenServer.call(__MODULE__, {:check, action}) do
          {:error, _} -> action_checked
          {:ok, action} -> GenServer.call(__MODULE__, {:act, action})
        end
      end

      defoverridable get_state: 0
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def handle_call({:check, action}, _from, state = %__MODULE__{action_space: action_space}) do
        case Gyx.Core.Spaces.contains?(action_space, action) do
          false -> {:reply, {:error, "invalid_action"}, state}
          _ -> {:reply, {:ok, action}, state}
        end
      end

      def handle_call(:get_state, _from, state), do: {:reply, state, state}
    end
  end
end
