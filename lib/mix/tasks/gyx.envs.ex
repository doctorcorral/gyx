defmodule Mix.Tasks.Gyx.Envs do
  @shortdoc "List registered Gyx environments or print one spec"
  @moduledoc """
  Lists environment ids, or prints the spec for one id.

      mix gyx.envs
      mix gyx.envs CartPole-v1
      mix gyx.envs gymnasium/ALE/Pong-v5
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      [] ->
        Enum.each(Gyx.envs(), &Mix.shell().info/1)

      [id] ->
        spec = Gyx.spec(id)
        Mix.shell().info("#{spec.id}")
        Mix.shell().info("  observation: #{inspect(spec.observation_space)}")
        Mix.shell().info("  action:      #{inspect(spec.action_space)}")

        if spec[:max_episode_steps] do
          Mix.shell().info("  max steps:   #{spec.max_episode_steps}")
        end

      _ ->
        Mix.raise("Usage: mix gyx.envs [ENV_ID]")
    end
  end
end
