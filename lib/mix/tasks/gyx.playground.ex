defmodule Mix.Tasks.Gyx.Playground do
  @shortdoc "How to start the optional playground UI"
  @moduledoc """
  The LiveView playground is a separate Phoenix app under `ui/` and is
  not part of the Gyx library.

      cd ui && mix phx.server
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("""
    The playground is the optional ui/ app (not compiled or shipped with Gyx).

      cd ui && mix deps.get && mix phx.server

    Then open http://127.0.0.1:4000
    """)
  end
end
