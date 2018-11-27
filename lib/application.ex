defmodule Gyx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    Gyx.Supervisor.start_link()
  end
end
