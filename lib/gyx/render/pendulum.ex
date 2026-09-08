defmodule Gyx.Render.Pendulum do
  @moduledoc false

  alias Gyx.Envs.Pendulum
  alias Gyx.Render

  @width 480
  @height 280
  @cx 240
  @cy 140
  @rod 90

  def svg(%Pendulum{} = env) do
    tip_x = @cx + :math.sin(env.theta) * @rod
    tip_y = @cy - :math.cos(env.theta) * @rod
    upright? = abs(angle_normalize(env.theta)) < 0.2 and abs(env.theta_dot) < 0.5
    color = if upright?, do: "#15803d", else: "#b91c1c"

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@width} #{@height}" role="img" aria-label="Pendulum">
      <rect width="100%" height="100%" fill="#f4f1ea"/>
      <line x1="#{@cx}" y1="24" x2="#{@cx}" y2="#{@height - 24}" stroke="#e7e5e4" stroke-width="2" stroke-dasharray="4 4"/>
      <line x1="#{@cx}" y1="#{@cy}" x2="#{tip_x}" y2="#{tip_y}" stroke="#{color}" stroke-width="10" stroke-linecap="round"/>
      <circle cx="#{tip_x}" cy="#{tip_y}" r="12" fill="#{color}"/>
      <circle cx="#{@cx}" cy="#{@cy}" r="6" fill="#292524"/>
      <text x="16" y="28" fill="#44403c" font-family="ui-monospace, monospace" font-size="12">
        θ=#{fmt(env.theta)}  ω=#{fmt(env.theta_dot)}  τ=#{fmt(env.last_u)}  t=#{env.steps}
      </text>
    </svg>
    """
  end

  def ansi(%Pendulum{} = env) do
    "Pendulum θ=#{fmt(env.theta)} ω=#{fmt(env.theta_dot)} τ=#{fmt(env.last_u)} t=#{env.steps}"
  end

  defp angle_normalize(x) do
    two_pi = 2 * :math.pi()
    x = x + :math.pi()
    x = x - two_pi * Float.floor(x / two_pi)
    x - :math.pi()
  end

  defp fmt(n), do: n |> Float.round(3) |> to_string() |> Render.escape()
end
