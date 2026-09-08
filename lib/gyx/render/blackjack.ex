defmodule Gyx.Render.Blackjack do
  @moduledoc false

  alias Gyx.Envs.Blackjack

  def svg(%Blackjack{} = env) do
    {player_sum, showing, ace} = Blackjack.observe(env)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 480 240" role="img" aria-label="Blackjack">
      <rect width="100%" height="100%" fill="#14532d"/>
      <text x="24" y="36" fill="#bbf7d0" font-family="ui-sans-serif, system-ui" font-size="16">Dealer</text>
      #{cards_row(env.dealer, 24, 52, hide_hole?: not env.finished)}
      <text x="24" y="140" fill="#bbf7d0" font-family="ui-sans-serif, system-ui" font-size="16">Player</text>
      #{cards_row(env.player, 24, 156, hide_hole?: false)}
      <text x="24" y="226" fill="#f0fdf4" font-family="ui-monospace, monospace" font-size="13">
        sum=#{player_sum}  showing=#{showing}  usable_ace=#{ace}
      </text>
    </svg>
    """
  end

  def ansi(%Blackjack{} = env) do
    {sum, showing, ace} = Blackjack.observe(env)
    "Blackjack player=#{inspect(env.player)} (#{sum}) dealer_up=#{showing} ace=#{ace}"
  end

  defp cards_row(cards, x, y, hide_hole?: hide?) do
    cards
    |> Enum.with_index()
    |> Enum.map_join("\n", fn {card, i} ->
      hidden = hide? and i == 1
      card_svg(x + i * 58, y, card, hidden)
    end)
  end

  defp card_svg(x, y, card, hidden) do
    face = if hidden, do: "?", else: card_label(card)
    fill = if hidden, do: "#1e3a8a", else: "#f8fafc"
    ink = if hidden, do: "#93c5fd", else: "#111827"

    """
    <rect x="#{x}" y="#{y}" width="50" height="70" rx="6" fill="#{fill}" stroke="#0f172a"/>
    <text x="#{x + 25}" y="#{y + 42}" text-anchor="middle" fill="#{ink}" font-size="18" font-family="ui-monospace, monospace">#{face}</text>
    """
  end

  defp card_label(1), do: "A"
  defp card_label(10), do: "10"
  defp card_label(n), do: Integer.to_string(n)
end
