defmodule Gyx.Application do
  @moduledoc false
  use Application

  def start(_type, _args) do
    IO.puts ""
    IO.puts "    ████████╗   ████╗  ██╗    Reinforcement"
    IO.puts "    ██╔════╚██╗ ██╔╚██╗██╔╝   Learning for"
    IO.puts "    ██║  ███╚████╔╝ ╚███╔╝    Elixir"
    IO.puts "    ██║   ██║╚██╔╝  ██╔██╗    http://gyx.ai"
    IO.puts "    ╚██████╔╝ ██║  ██╔╝ ██╗   ______________"
    IO.puts "     ╚═════╝  ╚═╝  ╚═╝  ╚═╝"

    Gyx.Supervisor.start_link()
  end
end
