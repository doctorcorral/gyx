defmodule Gyx.Render.Acrobot do
  @moduledoc false

  alias Gyx.Envs.Acrobot
  alias Gyx.Render

  @width 480
  @height 320
  @cx 240
  @cy 150
  @len 70

  def svg(%Acrobot{} = env) do
    x1 = @cx + :math.sin(env.theta1) * @len
    y1 = @cy + :math.cos(env.theta1) * @len
    th = env.theta1 + env.theta2
    x2 = x1 + :math.sin(th) * @len
    y2 = y1 + :math.cos(th) * @len
    goal_y = @cy - @len
    done? = Acrobot.tip_height(env) > 1.0
    color = if done?, do: "#15803d", else: "#1d4ed8"

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@width} #{@height}" role="img" aria-label="Acrobot">
      <rect width="100%" height="100%" fill="#f4f1ea"/>
      <line x1="80" y1="#{goal_y}" x2="#{@width - 80}" y2="#{goal_y}" stroke="#a8a29e" stroke-width="2" stroke-dasharray="6 4"/>
      <line x1="#{@cx}" y1="#{@cy}" x2="#{x1}" y2="#{y1}" stroke="#{color}" stroke-width="10" stroke-linecap="round"/>
      <line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{color}" stroke-width="10" stroke-linecap="round"/>
      <circle cx="#{@cx}" cy="#{@cy}" r="6" fill="#a16207"/>
      <circle cx="#{x1}" cy="#{y1}" r="6" fill="#a16207"/>
      <circle cx="#{x2}" cy="#{y2}" r="8" fill="#{color}"/>
      <text x="16" y="28" fill="#44403c" font-family="ui-monospace, monospace" font-size="12">
        θ1=#{fmt(env.theta1)}  θ2=#{fmt(env.theta2)}  tip=#{fmt(Acrobot.tip_height(env))}  t=#{env.steps}
      </text>
    </svg>
    """
  end

  def ansi(%Acrobot{} = env) do
    "Acrobot θ1=#{fmt(env.theta1)} θ2=#{fmt(env.theta2)} tip=#{fmt(Acrobot.tip_height(env))} t=#{env.steps}"
  end

  defp fmt(n), do: n |> Float.round(3) |> to_string() |> Render.escape()
end
