defmodule Gyx.Experiment.Checkpoint do
  @moduledoc false

  alias Gyx.Agents.{ActorCritic, QLearning, Reinforce, Sarsa}
  alias Gyx.Trainers.Presets

  @version 1

  @spec dump(Gyx.Experiment.t()) :: binary()
  def dump(%{algo: algo, env: env, agent: agent}) when agent != nil do
    :erlang.term_to_binary(%{
      v: @version,
      algo: algo,
      env: env,
      state: freeze(agent)
    })
  end

  @spec restore(Gyx.Experiment.t(), binary()) :: {:ok, struct()} | {:error, term()}
  def restore(%{algo: algo, env: env}, bin) when is_binary(bin) do
    case :erlang.binary_to_term(bin, [:safe]) do
      %{v: 1, algo: ^algo, env: ^env, state: state} ->
        case Presets.build(algo, env) do
          {fresh, _} -> thaw(fresh, state)
          nil -> {:error, :no_preset}
        end

      %{v: 1, algo: other_algo, env: other_env} ->
        {:error, {:checkpoint_mismatch, %{algo: other_algo, env: other_env}}}

      %{v: v} ->
        {:error, {:unsupported_checkpoint, v}}

      other ->
        {:error, {:invalid_checkpoint, other}}
    end
  rescue
    e -> {:error, Exception.message(e)}
  end

  defp freeze(%QLearning{} = agent) do
    %{
      kind: :q_learning,
      q: agent.q,
      alpha: agent.alpha,
      gamma: agent.gamma,
      epsilon: agent.epsilon,
      epsilon_min: agent.epsilon_min,
      epsilon_decay: agent.epsilon_decay
    }
  end

  defp freeze(%Sarsa{} = agent) do
    %{
      kind: :sarsa,
      q: agent.q,
      alpha: agent.alpha,
      gamma: agent.gamma,
      epsilon: agent.epsilon,
      epsilon_min: agent.epsilon_min,
      epsilon_decay: agent.epsilon_decay
    }
  end

  defp freeze(%Reinforce{} = agent) do
    %{
      kind: :reinforce,
      weights: agent.weights,
      lr: agent.lr,
      gamma: agent.gamma,
      baseline: agent.baseline
    }
  end

  defp freeze(%ActorCritic{} = agent) do
    %{
      kind: :actor_critic,
      params: tensors_to_binary(agent.params),
      opt_state: tensors_to_binary(agent.opt_state),
      algo: agent.algo,
      gamma: agent.gamma,
      gae_lambda: agent.gae_lambda,
      entropy_coef: agent.entropy_coef,
      vf_coef: agent.vf_coef,
      clip: agent.clip,
      epochs: agent.epochs
    }
  end

  defp thaw(%QLearning{} = fresh, %{kind: :q_learning} = state) do
    {:ok,
     %{
       fresh
       | q: state.q,
         alpha: state.alpha,
         gamma: state.gamma,
         epsilon: state.epsilon,
         epsilon_min: state.epsilon_min,
         epsilon_decay: state.epsilon_decay
     }}
  end

  defp thaw(%Sarsa{} = fresh, %{kind: :sarsa} = state) do
    {:ok,
     %{
       fresh
       | q: state.q,
         alpha: state.alpha,
         gamma: state.gamma,
         epsilon: state.epsilon,
         epsilon_min: state.epsilon_min,
         epsilon_decay: state.epsilon_decay,
         pending: nil
     }}
  end

  defp thaw(%Reinforce{} = fresh, %{kind: :reinforce} = state) do
    {:ok,
     %{
       fresh
       | weights: state.weights,
         lr: state.lr,
         gamma: state.gamma,
         baseline: state.baseline,
         trajectory: []
     }}
  end

  defp thaw(%ActorCritic{} = fresh, %{kind: :actor_critic} = state) do
    {:ok,
     %{
       fresh
       | params: tensors_to_runtime(state.params),
         opt_state: tensors_to_runtime(state.opt_state),
         algo: state.algo,
         gamma: state.gamma,
         gae_lambda: state.gae_lambda,
         entropy_coef: state.entropy_coef,
         vf_coef: state.vf_coef,
         clip: state.clip,
         epochs: state.epochs,
         trajectory: []
     }}
  end

  defp thaw(_fresh, state), do: {:error, {:kind_mismatch, Map.get(state, :kind)}}

  defp tensors_to_binary(%Nx.Tensor{} = tensor), do: Nx.backend_copy(tensor, Nx.BinaryBackend)

  defp tensors_to_binary(%mod{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {key, tensors_to_binary(value)} end)
    |> then(&struct!(mod, &1))
  end

  defp tensors_to_binary(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, tensors_to_binary(value)} end)
  end

  defp tensors_to_binary(list) when is_list(list), do: Enum.map(list, &tensors_to_binary/1)

  defp tensors_to_binary(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&tensors_to_binary/1) |> List.to_tuple()
  end

  defp tensors_to_binary(other), do: other

  defp tensors_to_runtime(%Nx.Tensor{} = tensor) do
    Nx.backend_copy(tensor, Nx.default_backend())
  end

  defp tensors_to_runtime(%mod{} = struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {key, value} -> {key, tensors_to_runtime(value)} end)
    |> then(&struct!(mod, &1))
  end

  defp tensors_to_runtime(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, tensors_to_runtime(value)} end)
  end

  defp tensors_to_runtime(list) when is_list(list), do: Enum.map(list, &tensors_to_runtime/1)

  defp tensors_to_runtime(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&tensors_to_runtime/1) |> List.to_tuple()
  end

  defp tensors_to_runtime(other), do: other
end
