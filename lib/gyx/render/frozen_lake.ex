defmodule Gyx.Render.FrozenLake do
  @moduledoc false

  alias Gyx.Envs.FrozenLake

  @cell 36
  @pad 12

  @colors %{
    ?S => "#bae6fd",
    ?F => "#e0f2fe",
    ?H => "#1e293b",
    ?G => "#fde68a"
  }

  def svg(%FrozenLake{} = env) do
    w = env.ncol * @cell + @pad * 2
    h = env.nrow * @cell + @pad * 2 + 28

    tiles =
      for {line, row} <- Enum.with_index(env.map),
          {ch, col} <- Enum.with_index(line) do
        x = @pad + col * @cell
        y = @pad + row * @cell
        fill = Map.get(@colors, ch, "#e7e5e4")
        label = List.to_string([ch])

        """
        <rect x="#{x}" y="#{y}" width="#{@cell - 2}" height="#{@cell - 2}" rx="4" fill="#{fill}" stroke="#94a3b8"/>
        <text x="#{x + @cell / 2 - 1}" y="#{y + @cell / 2 + 4}" text-anchor="middle" fill="#334155" font-size="11" font-family="ui-monospace, monospace">#{label}</text>
        """
      end

    ax = @pad + env.col * @cell + @cell / 2 - 1
    ay = @pad + env.row * @cell + @cell / 2

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" role="img" aria-label="FrozenLake">
      <rect width="100%" height="100%" fill="#f8fafc"/>
      #{tiles}
      <circle cx="#{ax}" cy="#{ay}" r="9" fill="#dc2626" stroke="#7f1d1d" stroke-width="2"/>
      <text x="#{@pad}" y="#{h - 6}" fill="#475569" font-family="ui-monospace, monospace" font-size="11">
        is_slippery=#{env.is_slippery}  obs=#{Gyx.Envs.FrozenLake.observe(env)} tile=#{List.to_string([FrozenLake.cell(env)])}#{move_caption(env)}
      </text>
    </svg>
    """
  end

  defp move_caption(%{last_action: nil}), do: ""

  defp move_caption(env) do
    pressed = FrozenLake.action_name(env.last_action)
    moved = FrozenLake.action_name(env.last_applied)

    if env.is_slippery and env.last_applied != env.last_action do
      "  #{pressed} slipped #{moved}"
    else
      "  #{moved}"
    end
  end

  def ansi(%FrozenLake{} = env) do
    env.map
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {line, row} ->
      line
      |> Enum.with_index()
      |> Enum.map_join("", fn {ch, col} ->
        glyph = List.to_string([ch])
        if row == env.row and col == env.col, do: "@", else: glyph
      end)
    end)
  end
end
