defmodule Gyx.Physics.Mjcf do
  @moduledoc """
  MJCF subset used by Farama Gymnasium MuJoCo v4 models.

  Compiles official assets under `priv/mjcf/` into a `Gyx.Physics.Mj` model.
  Mass and capsule inertia follow MuJoCo's `inertiafromgeom` formulas.
  """

  @pi :math.pi()

  @doc "Load and compile a vendored Gymnasium MJCF file by basename."
  def load(name) when is_binary(name) do
    key = {__MODULE__, name}

    case :persistent_term.get(key, :missing) do
      :missing ->
        model = name |> path() |> File.read!() |> parse() |> compile()
        :persistent_term.put(key, model)
        model

      model ->
        model
    end
  end

  def path(name), do: Path.join(xml_dir(), name)

  def xml_dir do
    case :code.priv_dir(:gyx) do
      {:error, _} -> Path.expand("priv/mjcf")
      dir -> Path.join(dir, "mjcf")
    end
  end

  def parse(xml) when is_binary(xml) do
    xml
    |> strip_comments()
    |> String.trim()
    |> parse_element()
    |> elem(0)
  end

  def compile(%{tag: "mujoco"} = root) do
    compiler = child(root, "compiler")
    option = child(root, "option")
    defaults = collect_defaults(root)
    angle = attr(compiler, "angle", "degree")
    degree? = angle != "radian"

    gravity = parse_vec3(attr(option, "gravity", "0 0 -9.81"))
    dt = to_f(attr(option, "timestep", "0.002"))
    integrator = integrator(attr(option, "integrator", "Euler"))
    viscosity = to_f(attr(option, "viscosity", "0"))
    fluid_density = to_f(attr(option, "density", "0"))

    world = child(root, "worldbody")
    {bodies, joints, geoms, sites, world_geoms} = walk_world(world, defaults, degree?)

    actuators = compile_actuators(root, joints, defaults)

    bodies = infer_inertias(bodies, geoms)

    %{
      nq: Enum.reduce(joints, 0, fn j, n -> n + j.nq end),
      nv: Enum.reduce(joints, 0, fn j, n -> n + j.nv end),
      nu: length(actuators),
      dt: dt,
      integrator: integrator,
      gravity: gravity,
      viscosity: viscosity,
      fluid_density: fluid_density,
      bodies: bodies,
      joints: joints,
      geoms: geoms,
      sites: sites,
      world_geoms: world_geoms,
      actuators: actuators,
      init_qpos: init_qpos(joints, bodies),
      init_qvel: List.duplicate(0.0, Enum.reduce(joints, 0, fn j, n -> n + j.nv end)) |> List.to_tuple()
    }
  end

  defp integrator("RK4"), do: :rk4
  defp integrator("Euler"), do: :euler
  defp integrator(_), do: :euler

  defp init_qpos(joints, bodies) do
    joints
    |> Enum.flat_map(fn
      %{type: :free, body: bid} ->
        body = Enum.find(bodies, &(&1.id == bid))
        {x, y, z} = body.pos
        [x, y, z, 1.0, 0.0, 0.0, 0.0]

      %{ref: ref} ->
        [ref]
    end)
    |> List.to_tuple()
  end

  defp walk_world(world, defaults, degree?) do
    acc = %{
      bodies: [],
      joints: [],
      geoms: [],
      sites: [],
      world_geoms: [],
      qadr: 0,
      vadr: 0,
      bid: 1
    }

    acc =
      Enum.reduce(world.children, acc, fn
        %{tag: "body"} = node, acc ->
          walk_body(node, 0, defaults, degree?, acc)

        %{tag: "geom"} = node, acc ->
          geom = compile_geom(node, 0, defaults, length(acc.world_geoms))
          %{acc | world_geoms: acc.world_geoms ++ [geom]}

        _, acc ->
          acc
      end)

    world_body = %{
      id: 0,
      name: "world",
      parent: 0,
      pos: {0.0, 0.0, 0.0},
      quat: {1.0, 0.0, 0.0, 0.0},
      mass: 0.0,
      com: {0.0, 0.0, 0.0},
      inertia: {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}}
    }

    {[world_body | acc.bodies], acc.joints, acc.geoms, acc.sites, acc.world_geoms}
  end

  defp walk_body(node, parent, defaults, degree?, acc) do
    id = acc.bid
    name = attr(node, "name", "body#{id}")
    pos = parse_vec3(attr(node, "pos", "0 0 0"))
    quat = parse_quat(node)

    body = %{
      id: id,
      name: name,
      parent: parent,
      pos: pos,
      quat: quat,
      mass: 0.0,
      com: {0.0, 0.0, 0.0},
      inertia: {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}}
    }

    acc = %{acc | bodies: acc.bodies ++ [body], bid: id + 1}

    {acc, _} =
      Enum.reduce(node.children, {acc, id}, fn
        %{tag: "joint"} = jnode, {acc, _} ->
          {joint, acc} = compile_joint(jnode, id, defaults, degree?, acc)
          {%{acc | joints: acc.joints ++ [joint]}, id}

        %{tag: "freejoint"} = jnode, {acc, _} ->
          {joint, acc} = compile_freejoint(jnode, id, acc)
          {%{acc | joints: acc.joints ++ [joint]}, id}

        %{tag: "geom"} = gnode, {acc, _} ->
          geom = compile_geom(gnode, id, defaults, length(acc.geoms))
          {%{acc | geoms: acc.geoms ++ [geom]}, id}

        %{tag: "site"} = snode, {acc, _} ->
          site = %{
            name: attr(snode, "name", "site"),
            body: id,
            pos: parse_vec3(attr(snode, "pos", "0 0 0"))
          }

          {%{acc | sites: acc.sites ++ [site]}, id}

        %{tag: "body"} = child, {acc, _} ->
          {walk_body(child, id, defaults, degree?, acc), id}

        _, acc_id ->
          acc_id
      end)

    acc
  end

  defp compile_joint(node, body, defaults, degree?, acc) do
    d = Map.merge(defaults.joint, node.attrs)
    type = joint_type(Map.get(d, "type", "hinge"))
    {nq, nv} = if type == :free, do: {7, 6}, else: {1, 1}
    range = parse_range(Map.get(d, "range"), degree? and type == :hinge)
    ref = to_f(Map.get(d, "ref", "0"))
    ref = if degree? and type == :hinge, do: ref * @pi / 180.0, else: ref

    joint = %{
      name: Map.get(d, "name", "joint#{acc.qadr}"),
      type: type,
      body: body,
      axis: parse_vec3(Map.get(d, "axis", "0 0 1")),
      pos: parse_vec3(Map.get(d, "pos", "0 0 0")),
      range: range,
      limited: truthy(Map.get(d, "limited", "false")) and range != nil,
      damping: to_f(Map.get(d, "damping", "0")),
      armature: to_f(Map.get(d, "armature", "0")),
      stiffness: to_f(Map.get(d, "stiffness", "0")),
      ref: ref,
      qadr: acc.qadr,
      vadr: acc.vadr,
      nq: nq,
      nv: nv
    }

    {joint, %{acc | qadr: acc.qadr + nq, vadr: acc.vadr + nv}}
  end

  defp compile_freejoint(node, body, acc) do
    joint = %{
      name: attr(node, "name", "root"),
      type: :free,
      body: body,
      axis: {0.0, 0.0, 1.0},
      pos: {0.0, 0.0, 0.0},
      range: nil,
      limited: false,
      damping: 0.0,
      armature: 0.0,
      stiffness: 0.0,
      ref: 0.0,
      qadr: acc.qadr,
      vadr: acc.vadr,
      nq: 7,
      nv: 6
    }

    {joint, %{acc | qadr: acc.qadr + 7, vadr: acc.vadr + 6}}
  end

  defp joint_type("slide"), do: :slide
  defp joint_type("hinge"), do: :hinge
  defp joint_type("free"), do: :free
  defp joint_type(_), do: :hinge

  defp compile_geom(node, body, defaults, idx) do
    d = Map.merge(defaults.geom, node.attrs)
    type = Map.get(d, "type", "sphere")
    fromto = parse_fromto(Map.get(d, "fromto"))
    size = parse_floats(Map.get(d, "size", "0.01"))
    pos = parse_vec3(Map.get(d, "pos", "0 0 0"))
    quat = parse_quat_attrs(d)
    {pos, quat, size} = apply_fromto(type, fromto, pos, quat, size)
    rgba = parse_floats(Map.get(d, "rgba", "0.8 0.6 0.4 1"))
    friction = parse_floats(Map.get(d, "friction", "1 0.005 0.0001"))
    solref = parse_floats(Map.get(d, "solref", "0.02 1"))
    solimp = parse_floats(Map.get(d, "solimp", "0.9 0.95 0.001"))

    %{
      id: idx,
      name: Map.get(d, "name", "geom#{idx}"),
      body: body,
      type: type,
      pos: pos,
      quat: quat,
      size: size,
      fromto: fromto,
      density: to_f(Map.get(d, "density", "1000")),
      contype: to_i(Map.get(d, "contype", "1")),
      conaffinity: to_i(Map.get(d, "conaffinity", "1")),
      condim: to_i(Map.get(d, "condim", "3")),
      margin: to_f(Map.get(d, "margin", "0")),
      friction: friction,
      solref: solref,
      solimp: solimp,
      rgba: rgba
    }
  end

  defp apply_fromto(_type, nil, pos, quat, size), do: {pos, quat, size}

  defp apply_fromto(type, {a, b}, _pos, _quat, size)
       when type in ["capsule", "cylinder", "box"] do
    mid = scale3(add3(a, b), 0.5)
    dir = sub3(b, a)
    len = norm3(dir)
    quat = quat_from_z(dir)
    radius = hd(size)
    half = len / 2.0
    {mid, quat, [radius, half | Enum.drop(size, 1)]}
  end

  defp apply_fromto(_type, _, pos, quat, size), do: {pos, quat, size}

  defp compile_actuators(root, joints, defaults) do
    case child(root, "actuator") do
      nil ->
        []

      act ->
        by_name = Map.new(joints, &{&1.name, &1})

        act.children
        |> Enum.filter(&(&1.tag in ["motor", "general"]))
        |> Enum.map(fn node ->
          d = Map.merge(defaults.motor, node.attrs)
          jname = Map.fetch!(d, "joint")
          joint = Map.fetch!(by_name, jname)
          [lo, hi] = parse_floats(Map.get(d, "ctrlrange", "-1 1"))
          gear = hd(parse_floats(Map.get(d, "gear", "1")))

          %{
            name: Map.get(d, "name", jname),
            joint: joint.name,
            vadr: joint.vadr,
            gear: gear,
            ctrlrange: {lo, hi}
          }
        end)
    end
  end

  defp infer_inertias(bodies, geoms) do
    Enum.map(bodies, fn
      %{id: 0} = world ->
        world

      body ->
        gs = Enum.filter(geoms, &(&1.body == body.id))
        {mass, com, inertia} = combine_geoms(gs)
        %{body | mass: mass, com: com, inertia: inertia}
    end)
  end

  defp combine_geoms([]),
    do: {0.0, {0.0, 0.0, 0.0}, {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}}}

  defp combine_geoms(geoms) do
    parts =
      Enum.map(geoms, fn g ->
        {mass, com_local, i_diag} = geom_mass_inertia(g)
        com = add3(g.pos, rotq(g.quat, com_local))
        i_body = rotate_diag(g.quat, i_diag)
        {mass, com, i_body}
      end)

    mass = Enum.reduce(parts, 0.0, fn {m, _, _}, acc -> acc + m end)

    com =
      if mass > 0 do
        parts
        |> Enum.reduce({0.0, 0.0, 0.0}, fn {m, c, _}, acc -> add3(acc, scale3(c, m)) end)
        |> scale3(1.0 / mass)
      else
        {0.0, 0.0, 0.0}
      end

    inertia =
      Enum.reduce(parts, zero_mat(), fn {m, c, i}, acc ->
        add_mat(acc, add_mat(i, parallel_axis(m, sub3(c, com))))
      end)

    {mass, com, inertia}
  end

  defp geom_mass_inertia(%{type: "plane"}), do: {0.0, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}}

  defp geom_mass_inertia(%{type: "sphere", size: [r | _], density: d}) do
    mass = d * 4.0 / 3.0 * @pi * r * r * r
    i = 0.4 * mass * r * r
    {mass, {0.0, 0.0, 0.0}, {i, i, i}}
  end

  defp geom_mass_inertia(%{type: "capsule", size: [r | rest], density: d}) do
    h = 2.0 * (Enum.at(rest, 0) || r)
    vol = @pi * (r * r * h + 4.0 / 3.0 * r * r * r)
    mass = d * vol
    sphere_mass = mass * 4 * r / (4 * r + 3 * h)
    cyl_mass = mass - sphere_mass
    ixx = cyl_mass * (3 * r * r + h * h) / 12
    izz = cyl_mass * r * r / 2
    sphere_i = 2 * sphere_mass * r * r / 5
    shift = sphere_mass * h * (3 * r + 2 * h) / 8
    {mass, {0.0, 0.0, 0.0}, {ixx + sphere_i + shift, ixx + sphere_i + shift, izz + sphere_i}}
  end

  defp geom_mass_inertia(%{type: "cylinder", size: [r | rest], density: d}) do
    h = 2.0 * (Enum.at(rest, 0) || r)
    mass = d * @pi * r * r * h
    ixx = mass * (3 * r * r + h * h) / 12
    izz = mass * r * r / 2
    {mass, {0.0, 0.0, 0.0}, {ixx, ixx, izz}}
  end

  defp geom_mass_inertia(%{type: "box", size: [sx, sy, sz | _], density: d}) do
    mass = d * 8.0 * sx * sy * sz
    {mass, {0.0, 0.0, 0.0},
     {mass * (sy * sy + sz * sz) / 3, mass * (sx * sx + sz * sz) / 3, mass * (sx * sx + sy * sy) / 3}}
  end

  defp geom_mass_inertia(g), do: geom_mass_inertia(%{g | type: "sphere", size: [0.01]})

  defp parallel_axis(m, {x, y, z}) do
    {{m * (y * y + z * z), -m * x * y, -m * x * z}, {-m * x * y, m * (x * x + z * z), -m * y * z},
     {-m * x * z, -m * y * z, m * (x * x + y * y)}}
  end

  defp rotate_diag(q, {ix, iy, iz}) do
    r = quat_to_mat(q)
    d = {{ix, 0.0, 0.0}, {0.0, iy, 0.0}, {0.0, 0.0, iz}}
    mul_mat(mul_mat(r, d), transpose(r))
  end

  defp collect_defaults(root) do
    base = %{
      joint: %{},
      geom: %{"contype" => "1", "conaffinity" => "1", "condim" => "3", "density" => "1000"},
      motor: %{}
    }

    case child(root, "default") do
      nil ->
        base

      node ->
        Enum.reduce(node.children, base, fn
          %{tag: "joint", attrs: a}, acc -> %{acc | joint: Map.merge(acc.joint, a)}
          %{tag: "geom", attrs: a}, acc -> %{acc | geom: Map.merge(acc.geom, a)}
          %{tag: "motor", attrs: a}, acc -> %{acc | motor: Map.merge(acc.motor, a)}
          %{tag: "default"} = nested, acc ->
            Enum.reduce(nested.children, acc, fn
              %{tag: "joint", attrs: a}, acc -> %{acc | joint: Map.merge(acc.joint, a)}
              %{tag: "geom", attrs: a}, acc -> %{acc | geom: Map.merge(acc.geom, a)}
              %{tag: "motor", attrs: a}, acc -> %{acc | motor: Map.merge(acc.motor, a)}
              _, acc -> acc
            end)

          _, acc ->
            acc
        end)
    end
  end

  defp child(node, tag), do: Enum.find(node.children, &(&1.tag == tag))

  defp attr(nil, _k, default), do: default
  defp attr(node, k, default), do: Map.get(node.attrs, k, default)

  defp parse_range(nil, _), do: nil

  defp parse_range(str, degree?) do
    [lo, hi] = parse_floats(str)
    if degree?, do: {lo * @pi / 180.0, hi * @pi / 180.0}, else: {lo, hi}
  end

  defp parse_fromto(nil), do: nil

  defp parse_fromto(str) do
    [x1, y1, z1, x2, y2, z2] = parse_floats(str)
    {{x1, y1, z1}, {x2, y2, z2}}
  end

  defp parse_quat(node) do
    parse_quat_attrs(node.attrs)
  end

  defp parse_quat_attrs(%{"quat" => q}), do: (q |> parse_floats() |> List.to_tuple() |> normalize_quat())

  defp parse_quat_attrs(_), do: {1.0, 0.0, 0.0, 0.0}

  defp parse_vec3(str) do
    case parse_floats(str) do
      [x, y, z | _] -> {x, y, z}
      [x, y] -> {x, y, 0.0}
      [x] -> {x, 0.0, 0.0}
      _ -> {0.0, 0.0, 0.0}
    end
  end

  defp parse_floats(nil), do: []

  defp parse_floats(str) do
    str
    |> String.split(~r/[\s,]+/, trim: true)
    |> Enum.map(&to_f/1)
  end

  defp to_f(n) when is_number(n), do: n * 1.0

  defp to_f(<<"." , _::binary>> = s), do: to_f("0" <> s)
  defp to_f(<<"-.", rest::binary>>), do: to_f("-0." <> rest)

  defp to_f(s) when is_binary(s) do
    case Float.parse(s) do
      {f, _} -> f
      :error ->
        case Integer.parse(s) do
          {i, _} -> i * 1.0
          :error -> 0.0
        end
    end
  end

  defp to_i(s), do: s |> to_f() |> trunc()

  defp truthy(v) when v in ["true", "1", "True"], do: true
  defp truthy(_), do: false

  defp strip_comments(xml), do: String.replace(xml, ~r/<!--.*?-->/s, "")

  defp parse_element(str) do
    str = String.trim_leading(str)

    case Regex.run(~r{\A<(/)?([A-Za-z0-9_:-]+)([^>]*)>}s, str) do
      [full, "/", _tag, _] ->
        {:close, String.replace_prefix(str, full, "")}

      [full, "", tag, attrs] ->
        rest = String.replace_prefix(str, full, "")
        map = parse_attrs(attrs)
        self? = String.ends_with?(String.trim(attrs), "/") or String.ends_with?(full, "/>")

        if self? do
          {%{tag: tag, attrs: map, children: []}, rest}
        else
          {children, rest} = parse_children(rest)
          {%{tag: tag, attrs: map, children: children}, rest}
        end

      _ ->
        {:done, str}
    end
  end

  defp parse_children(str) do
    str = String.trim_leading(str)

    cond do
      str == "" ->
        {[], ""}

      String.starts_with?(str, "</") ->
        case Regex.run(~r{\A</[A-Za-z0-9_:-]+>}s, str) do
          [full] -> {[], String.replace_prefix(str, full, "")}
          _ -> {[], str}
        end

      String.starts_with?(str, "<") ->
        case parse_element(str) do
          {:close, rest} ->
            {[], rest}

          {:done, rest} ->
            {[], rest}

          {elem, rest} ->
            {kids, rest} = parse_children(rest)
            {[elem | kids], rest}
        end

      true ->
        case Regex.run(~r{\A[^<]+}s, str) do
          [text] -> parse_children(String.replace_prefix(str, text, ""))
          _ -> {[], str}
        end
    end
  end

  defp parse_attrs(s) do
    Regex.scan(~r/([A-Za-z0-9_:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')/, s)
    |> Map.new(fn
      [_, k, d] -> {k, d}
      [_, k, d, ""] -> {k, d}
      [_, k, "", s] -> {k, s}
      [_, k, d, _] -> {k, d}
    end)
  end

  defp add3({ax, ay, az}, {bx, by, bz}), do: {ax + bx, ay + by, az + bz}
  defp sub3({ax, ay, az}, {bx, by, bz}), do: {ax - bx, ay - by, az - bz}
  defp scale3({x, y, z}, s), do: {x * s, y * s, z * s}
  defp norm3({x, y, z}), do: :math.sqrt(x * x + y * y + z * z)

  defp rotq({w, x, y, z}, {vx, vy, vz}) do
    tx = 2 * (y * vz - z * vy)
    ty = 2 * (z * vx - x * vz)
    tz = 2 * (x * vy - y * vx)

    {vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx)}
  end

  defp normalize_quat({w, x, y, z}) do
    n = :math.sqrt(w * w + x * x + y * y + z * z)
    if n < 1.0e-12, do: {1.0, 0.0, 0.0, 0.0}, else: {w / n, x / n, y / n, z / n}
  end

  defp quat_from_z({x, y, z}) do
    n = norm3({x, y, z})

    if n < 1.0e-12 do
      {1.0, 0.0, 0.0, 0.0}
    else
      v = {x / n, y / n, z / n}
      {zx, zy, zz} = {0.0, 0.0, 1.0}
      {cx, cy, cz} = {zy * elem(v, 2) - zz * elem(v, 1), zz * elem(v, 0) - zx * elem(v, 2), zx * elem(v, 1) - zy * elem(v, 0)}
      cnorm = norm3({cx, cy, cz})
      dot = zz * elem(v, 2) + zy * elem(v, 1) + zx * elem(v, 0)

      cond do
        cnorm < 1.0e-8 and dot > 0 ->
          {1.0, 0.0, 0.0, 0.0}

        cnorm < 1.0e-8 ->
          {0.0, 1.0, 0.0, 0.0}

        true ->
          axis = scale3({cx, cy, cz}, 1.0 / cnorm)
          ang = :math.atan2(cnorm, dot)
          s = :math.sin(ang / 2)
          {ax, ay, az} = axis
          normalize_quat({:math.cos(ang / 2), ax * s, ay * s, az * s})
      end
    end
  end

  defp quat_to_mat({w, x, y, z}) do
    {{1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)},
     {2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)},
     {2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)}}
  end

  defp zero_mat, do: {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}}

  defp add_mat({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}, {{b00, b01, b02}, {b10, b11, b12}, {b20, b21, b22}}) do
    {{a00 + b00, a01 + b01, a02 + b02}, {a10 + b10, a11 + b11, a12 + b12}, {a20 + b20, a21 + b21, a22 + b22}}
  end

  defp mul_mat({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}, {{b00, b01, b02}, {b10, b11, b12}, {b20, b21, b22}}) do
    {{a00 * b00 + a01 * b10 + a02 * b20, a00 * b01 + a01 * b11 + a02 * b21, a00 * b02 + a01 * b12 + a02 * b22},
     {a10 * b00 + a11 * b10 + a12 * b20, a10 * b01 + a11 * b11 + a12 * b21, a10 * b02 + a11 * b12 + a12 * b22},
     {a20 * b00 + a21 * b10 + a22 * b20, a20 * b01 + a21 * b11 + a22 * b21, a20 * b02 + a21 * b12 + a22 * b22}}
  end

  defp transpose({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}) do
    {{a00, a10, a20}, {a01, a11, a21}, {a02, a12, a22}}
  end
end
