defmodule Gyx.Render.Scene do
  @moduledoc false

  alias Gyx.Physics.Tree
  alias Gyx.Render

  @spec from_world([map()], keyword()) :: map()
  def from_world(geoms, opts \\ []) do
    track = Keyword.get(opts, :track_pos, {0.0, 0.0, 0.5})
    extras = Keyword.get(opts, :extras, [])

    %{
      camera: %{
        track: v3(track),
        distance: Keyword.get(opts, :distance, 3.6),
        azimuth: Keyword.get(opts, :azimuth, 135),
        elevation: Keyword.get(opts, :elevation, -18)
      },
      ground: Keyword.get(opts, :ground, true),
      water: Keyword.get(opts, :water, false),
      bodies: geoms ++ extras
    }
  end

  def svg_world(geoms, title, plane \\ :xz) do
    segs =
      Enum.map(geoms, fn
        %{from: a, to: b, color: c} -> {proj_list(a, plane), proj_list(b, plane), c}
        %{pos: p, radius: r, color: c} ->
          {x, y} = proj_list(p, plane)
          {{x - r, y}, {x + r, y}, c}

        _ ->
          {{0.0, 0.0}, {0.0, 0.0}, "#888"}
      end)

    xs = Enum.flat_map(segs, fn {{ax, _}, {bx, _}, _} -> [ax, bx] end)
    ys = Enum.flat_map(segs, fn {{_, ay}, {_, by}, _} -> [ay, by] end)
    {xmin, xmax} = padded_range(xs, 1.5)
    {ymin, ymax} = padded_range(ys, 1.0)
    w = 640
    h = 360
    sx = w / max(xmax - xmin, 0.1)
    sy = h / max(ymax - ymin, 0.1)
    s = min(sx, sy) * 0.86

    to_svg = fn {x, y} ->
      {20 + (x - xmin) * s, h - 20 - (y - ymin) * s}
    end

    lines =
      Enum.map(segs, fn {a, b, color} ->
        {x1, y1} = to_svg.(a)
        {x2, y2} = to_svg.(b)

        ~s(<line x1="#{fmt(x1)}" y1="#{fmt(y1)}" x2="#{fmt(x2)}" y2="#{fmt(y2)}" stroke="#{color}" stroke-width="8" stroke-linecap="round"/>)
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" role="img" aria-label="#{Render.escape(title)}">
      <rect width="#{w}" height="#{h}" fill="transparent"/>
      <text x="16" y="28" fill="var(--muted, #57534e)" font-size="14" font-family="ui-monospace, monospace">#{Render.escape(title)}</text>
      #{Enum.join(lines, "\n")}
    </svg>
    """
  end

  defp proj_list([x, _y, z], :xz), do: {x, z}
  defp proj_list([x, y, _z], :xy), do: {x, y}
  defp proj_list([x, _y, z], _), do: {x, z}

  @spec from_tree(tuple(), map(), keyword()) :: map()
  def from_tree(q, model, opts \\ []) do
    poses = Tree.fk(q, model)
    track_name = Keyword.get(opts, :track, hd(model.bodies).name)
    track = poses[track_name].pos
    extras = Keyword.get(opts, :extras, [])

    bodies =
      Enum.flat_map(model.bodies, fn body ->
        pose = poses[body.name]

        body.geoms
        |> Enum.with_index()
        |> Enum.map(fn {geom, i} ->
          pose
          |> geom_payload(geom)
          |> Map.put(:id, "#{body.name}-#{i}")
        end)
      end) ++ extras

    %{
      camera: %{
        track: v3(track),
        distance: Keyword.get(opts, :distance, 3.6),
        azimuth: Keyword.get(opts, :azimuth, 135),
        elevation: Keyword.get(opts, :elevation, -18)
      },
      ground: Keyword.get(opts, :ground, true),
      water: Keyword.get(opts, :water, false),
      bodies: bodies
    }
  end

  @spec svg(tuple(), map(), String.t()) :: String.t()
  def svg(q, model, title) do
    poses = Tree.fk(q, model)
    plane = Map.get(model, :view, :xz)

    segs =
      Enum.flat_map(model.bodies, fn body ->
        pose = poses[body.name]

        Enum.map(body.geoms, fn geom ->
          {a, b, color} = geom_segment(pose, geom, plane)
          {a, b, color}
        end)
      end)

    xs = Enum.flat_map(segs, fn {{ax, _}, {bx, _}, _} -> [ax, bx] end)
    ys = Enum.flat_map(segs, fn {{_, ay}, {_, by}, _} -> [ay, by] end)
    {xmin, xmax} = padded_range(xs, 1.5)
    {ymin, ymax} = padded_range(ys, 1.0)
    w = 640
    h = 360
    sx = w / max(xmax - xmin, 0.1)
    sy = h / max(ymax - ymin, 0.1)
    s = min(sx, sy) * 0.86

    to_svg = fn {x, y} ->
      {20 + (x - xmin) * s, h - 20 - (y - ymin) * s}
    end

    lines =
      Enum.map(segs, fn {a, b, color} ->
        {x1, y1} = to_svg.(a)
        {x2, y2} = to_svg.(b)

        ~s(<line x1="#{fmt(x1)}" y1="#{fmt(y1)}" x2="#{fmt(x2)}" y2="#{fmt(y2)}" stroke="#{color}" stroke-width="8" stroke-linecap="round"/>)
      end)

    """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{w} #{h}" role="img" aria-label="#{Render.escape(title)}">
      <rect width="#{w}" height="#{h}" fill="transparent"/>
      <text x="16" y="28" fill="var(--muted, #57534e)" font-size="14" font-family="ui-monospace, monospace">#{Render.escape(title)}</text>
      #{Enum.join(lines, "\n")}
    </svg>
    """
  end

  defp geom_payload(pose, {:capsule, a, b, radius, color}) do
    %{
      geom: "capsule",
      from: v3(Tree.world_point(pose, a)),
      to: v3(Tree.world_point(pose, b)),
      radius: radius,
      color: color
    }
  end

  defp geom_payload(pose, {:box, pos, {sx, sy, sz}, color}) do
    %{
      geom: "box",
      pos: v3(Tree.world_point(pose, pos)),
      size: [sx, sy, sz],
      rot: mat_to_quat(pose.rot),
      color: color
    }
  end

  defp geom_payload(pose, {:sphere, pos, radius, color}) do
    %{
      geom: "sphere",
      pos: v3(Tree.world_point(pose, pos)),
      radius: radius,
      color: color
    }
  end

  defp geom_segment(pose, {:capsule, a, b, _, color}, plane) do
    {project(Tree.world_point(pose, a), plane), project(Tree.world_point(pose, b), plane), color}
  end

  defp geom_segment(pose, {:box, pos, {sx, _sy, sz}, color}, plane) do
    a = Tree.world_point(pose, add(pos, {-sx, 0.0, -sz}))
    b = Tree.world_point(pose, add(pos, {sx, 0.0, sz}))
    {project(a, plane), project(b, plane), color}
  end

  defp geom_segment(pose, {:sphere, pos, r, color}, plane) do
    p = Tree.world_point(pose, pos)
    {project(add(p, {-r, 0.0, 0.0}), plane), project(add(p, {r, 0.0, 0.0}), plane), color}
  end

  defp project({x, _y, z}, :xz), do: {x, z}
  defp project({x, y, _z}, :xy), do: {x, y}

  defp padded_range([], pad), do: {-pad, pad}

  defp padded_range(xs, pad) do
    {lo, hi} = Enum.min_max(xs)
    {lo - pad, hi + pad}
  end

  defp v3({x, y, z}), do: [x * 1.0, y * 1.0, z * 1.0]
  defp add({ax, ay, az}, {bx, by, bz}), do: {ax + bx, ay + by, az + bz}
  defp fmt(n), do: n |> Float.round(2) |> to_string()

  defp mat_to_quat({{r00, r01, r02}, {r10, r11, r12}, {r20, r21, r22}}) do
    tr = r00 + r11 + r22

    {w, x, y, z} =
      if tr > 0 do
        s = :math.sqrt(tr + 1.0) * 2
        {0.25 * s, (r21 - r12) / s, (r02 - r20) / s, (r10 - r01) / s}
      else
        {0.5, 0.0, 0.0, 0.0}
      end

    [w, x, y, z]
  end
end
