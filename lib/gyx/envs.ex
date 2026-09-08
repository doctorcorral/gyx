defmodule Gyx.Envs do
  @moduledoc """
  Registry of native Gymnasium-like environments.

  Unprefixed Farama ids (`Hopper-v4`) are the pure-Elixir MJCF suite.
  `tree/*` is the older approximate `Gyx.Physics.Tree` backend.
  `gymnasium/*` wraps Python Gymnasium (MuJoCo C and `ALE/*` Atari).
  """

  @registry %{
    "Acrobot-v1" => Gyx.Envs.Acrobot,
    "Ant-v4" => Gyx.Envs.Ant,
    "Blackjack-v1" => Gyx.Envs.Blackjack,
    "CartPole-v1" => Gyx.Envs.CartPole,
    "FrozenLake-v1" => Gyx.Envs.FrozenLake,
    "HalfCheetah-v4" => Gyx.Envs.HalfCheetah,
    "Hopper-v4" => Gyx.Envs.Hopper,
    "InvertedDoublePendulum-v4" => Gyx.Envs.InvertedDoublePendulum,
    "InvertedPendulum-v4" => Gyx.Envs.InvertedPendulum,
    "MountainCar-v0" => Gyx.Envs.MountainCar,
    "Pendulum-v1" => Gyx.Envs.Pendulum,
    "Reacher-v4" => Gyx.Envs.Reacher,
    "Swimmer-v4" => Gyx.Envs.Swimmer,
    "Walker2d-v4" => Gyx.Envs.Walker2d,
    "tree/Ant-v4" => Gyx.Envs.Tree.Ant,
    "tree/HalfCheetah-v4" => Gyx.Envs.Tree.HalfCheetah,
    "tree/Hopper-v4" => Gyx.Envs.Tree.Hopper,
    "tree/InvertedDoublePendulum-v4" => Gyx.Envs.Tree.InvertedDoublePendulum,
    "tree/InvertedPendulum-v4" => Gyx.Envs.Tree.InvertedPendulum,
    "tree/Reacher-v4" => Gyx.Envs.Tree.Reacher,
    "tree/Swimmer-v4" => Gyx.Envs.Tree.Swimmer,
    "tree/Walker2d-v4" => Gyx.Envs.Tree.Walker2d
  }

  @aliases %{
    "Blackjack-v0" => "Blackjack-v1",
    "CartPole-v0" => "CartPole-v1",
    "FrozenLake-v0" => "FrozenLake-v1",
    acrobot: "Acrobot-v1",
    ant: "Ant-v4",
    blackjack: "Blackjack-v1",
    cartpole: "CartPole-v1",
    frozenlake: "FrozenLake-v1",
    halfcheetah: "HalfCheetah-v4",
    hopper: "Hopper-v4",
    inverted_double_pendulum: "InvertedDoublePendulum-v4",
    inverted_pendulum: "InvertedPendulum-v4",
    mountaincar: "MountainCar-v0",
    pendulum: "Pendulum-v1",
    reacher: "Reacher-v4",
    swimmer: "Swimmer-v4",
    walker2d: "Walker2d-v4"
  }

  @spec ids() :: [String.t()]
  def ids do
    @registry
    |> Map.keys()
    |> Kernel.++(Map.keys(Gyx.Envs.Gymnasium.registry()))
    |> Enum.sort()
  end

  @spec fetch(term()) :: {:ok, module()} | :error
  def fetch(id) do
    key = Map.get(@aliases, id, id)

    case Map.fetch(@registry, key) do
      :error -> Map.fetch(Gyx.Envs.Gymnasium.registry(), key)
      found -> found
    end
  end

  @spec fetch!(term()) :: module()
  def fetch!(id) do
    case fetch(id) do
      {:ok, mod} -> mod
      :error -> raise ArgumentError, "unknown environment #{inspect(id)}"
    end
  end
end
