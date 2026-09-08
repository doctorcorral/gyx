defmodule Gyx.Render.CartPole do
  @moduledoc false

  alias Gyx.Envs.CartPole
  alias Gyx.Render

  @width 480
  @height 220
  @track_y 160
  @cart_w 56
  @cart_h 28
  @pole_len 90
  @x_span 2.4 * 1.2

  def svg(%CartPole{} = env) do
    cx = x_to_px(env.x)
    cy = @track_y - @cart_h / 2
    tip_x = cx + :math.sin(env.theta) * @pole_len
    tip_y = cy - :math.cos(env.theta) * @pole_len
    fallen? = abs(env.x) > 2.4 or abs(env.theta) > 12 * 2 * :math.pi() / 360
    pole_color = if fallen?, do: "#b45309", else: "#1d4ed8"

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@width} #{@height}" role="img" aria-label="CartPole">
      <rect width="100%" height="100%" fill="#f4f1ea"/>
      <line x1="24" y1="#{@track_y}" x2="#{@width - 24}" y2="#{@track_y}" stroke="#44403c" stroke-width="3"/>
      <line x1="#{x_to_px(-2.4)}" y1="#{@track_y - 8}" x2="#{x_to_px(-2.4)}" y2="#{@track_y + 8}" stroke="#a8a29e" stroke-width="2"/>
      <line x1="#{x_to_px(2.4)}" y1="#{@track_y - 8}" x2="#{x_to_px(2.4)}" y2="#{@track_y + 8}" stroke="#a8a29e" stroke-width="2"/>
      <rect x="#{cx - @cart_w / 2}" y="#{@track_y - @cart_h}" width="#{@cart_w}" height="#{@cart_h}" rx="4" fill="#292524"/>
      <circle cx="#{cx - 16}" cy="#{@track_y}" r="6" fill="#78716c"/>
      <circle cx="#{cx + 16}" cy="#{@track_y}" r="6" fill="#78716c"/>
      <line x1="#{cx}" y1="#{cy}" x2="#{tip_x}" y2="#{tip_y}" stroke="#{pole_color}" stroke-width="8" stroke-linecap="round"/>
      <circle cx="#{cx}" cy="#{cy}" r="5" fill="#e7e5e4"/>
      <text x="16" y="28" fill="#44403c" font-family="ui-monospace, monospace" font-size="12">
        x=#{fmt(env.x)}  θ=#{fmt(env.theta)}  t=#{env.steps}
      </text>
    </svg>
    """
  end

  def ansi(%CartPole{} = env) do
    "CartPole x=#{fmt(env.x)} ẋ=#{fmt(env.x_dot)} θ=#{fmt(env.theta)} θ̇=#{fmt(env.theta_dot)} t=#{env.steps}"
  end

  defp x_to_px(x), do: @width / 2 + x / @x_span * (@width / 2 - 40)
  defp fmt(n), do: n |> Float.round(3) |> to_string() |> Render.escape()
end
