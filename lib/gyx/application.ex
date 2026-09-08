defmodule Gyx.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    if Code.ensure_loaded?(EXLA) do
      Nx.default_backend(EXLA.Backend)
      Nx.Defn.default_options(compiler: EXLA, client: :host)
    end

    children = [
      {Registry, keys: :unique, name: Gyx.Registry}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Gyx.Supervisor)
  end
end
