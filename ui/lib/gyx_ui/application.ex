defmodule GyxUI.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: GyxUI.PubSub},
      GyxUI.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: GyxUI.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    GyxUI.Endpoint.config_change(changed, removed)
    :ok
  end
end
