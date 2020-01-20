defmodule Mix.Tasks.Gyx.Trainer do
  use Mix.Task

  @env_module Gyx.Environments.Gym
  @q_storage_module Gyx.Qstorage.QGenServer
  @agents_module "Elixir.Gyx.Agents."

  @shortdoc "It runs a training process for an agent and environment pair"
  def run([agent, env_name]) do
    agent_name = String.to_atom(@agents_module <> agent)
    {:ok, environment} = @env_module.start_link([], [])
    {:ok, qgenserver} = @q_storage_module.start_link([], [])
    {:ok, agent} = agent_name.start_link(qgenserver, [])
    Gyx.Environments.Gym.make(environment, env_name)
  end

end
