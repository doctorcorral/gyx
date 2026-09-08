defmodule Gyx.Render.MountainCar do
  @moduledoc false

  alias Gyx.Envs.MountainCar

  @width 480
  @height 220
  @min_x -1.2
  @max_x 0.6

  def svg(%MountainCar{} = env) do
    track =
      0..48
      |> Enum.map_join(" ", fn i ->
        t = i / 48
        x = @min_x + t * (@max_x - @min_x)
        {px, py} = to_px(x, height(x))
        "#{if i == 0, do: "M", else: "L"} #{px} #{py}"
      end)

    {cx, cy} = to_px(env.position, height(env.position))
    {fx, fy} = to_px(0.5, height(0.5))

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{@width} #{@height}" role="img" aria-label="MountainCar">
      <rect width="100%" height="100%" fill="#f4f1ea"/>
      <path d="#{track}" fill="none" stroke="#44403c" stroke-width="3"/>
      <line x1="#{fx}" y1="#{fy}" x2="#{fx}" y2="#{fy - 28}" stroke="#b45309" stroke-width="3"/>
      <rect x="#{fx - 8}" y="#{fy - 36}" width="16" height="10" fill="#b45309"/>
      <circle cx="#{cx}" cy="#{cy - 8}" r="10" fill="#1d4ed8" stroke="#1e3a8a" stroke-width="2"/>
      <text x="16" y="28" fill="#44403c" font-family="ui-monospace, monospace" font-size="12">
        x=#{fmt(env.position)}  v=#{fmt(env.velocity)}  t=#{env.steps}
      </text>
    </svg>
    """
  end

  def ansi(%MountainCar{} = env) do
    "MountainCar x=#{fmt(env.position)} v=#{fmt(env.velocity)} t=#{env.steps}"
  end

  defp height(x), do: :math.sin(3 * x)

  defp to_px(x, y) do
    px = 24 + (x - @min_x) / (@max_x - @min_x) * (@width - 48)
    py = 150 - y * 42
    {px, py}
  end

  defp fmt(n), do: n |> Float.round(3) |> to_string()
end
