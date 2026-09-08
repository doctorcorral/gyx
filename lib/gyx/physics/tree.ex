defmodule Gyx.Physics.Tree do
  @moduledoc false

  @eps 1.0e-5

  @type q :: tuple()
  @type model :: map()

  @spec step(q(), q(), q(), model(), float(), pos_integer()) :: {q(), q()}
  def step(q, qd, tau, model, dt, nsub \\ 1) do
    Enum.reduce(1..nsub, {q, qd}, fn _, {q, qd} ->
      acc = accelerations(q, qd, tau, model)
      qd = add_scaled(qd, acc, dt)
      q = add_scaled(q, qd, dt)
      {q, qd} = apply_limits(q, qd, model)
      project_ground(q, qd, model)
    end)
  end

  @spec fk(q(), model()) :: %{term() => map()}
  def fk(q, model) do
    Enum.reduce(model.bodies, %{}, fn body, acc ->
      {pos, rot} = pose(body, q, acc)
      Map.put(acc, body.name, %{pos: pos, rot: rot, body: body})
    end)
  end

  @spec world_point(map(), {number(), number(), number()}) :: {float(), float(), float()}
  def world_point(%{pos: pos, rot: rot}, local), do: add(pos, apply_r(rot, local))

  @spec world_geoms(q(), model()) :: [map()]
  def world_geoms(q, model) do
    poses = fk(q, model)

    Enum.flat_map(model.bodies, fn body ->
      pose = poses[body.name]

      Enum.map(body.geoms, fn geom ->
        %{id: body.name, geom: geom_kind(geom), pose: pose, spec: geom}
      end)
    end)
  end

  defp accelerations(q, qd, tau, model) do
    n = tuple_size(q)
    poses0 = fk(q, model)
    jac = jacobians(q, model, poses0)
    gen_g = gravity_gen(model, jac)
    gen_c = contact_gen(q, qd, model, poses0, jac)
    gen_d = drag_gen(qd, model, jac, poses0)
    damp = Map.get(model, :damping, 0.05)
    inertia = model.inertia

    for i <- 0..(n - 1) do
      force =
        elem(tau, i) + elem(gen_g, i) + elem(gen_c, i) + elem(gen_d, i) -
          damp * elem(qd, i)

      force / elem(inertia, i)
    end
    |> List.to_tuple()
  end

  defp gravity_gen(model, jac) do
    g = Map.get(model, :gravity, 9.81)
    n = tuple_size(jac[hd(Map.keys(jac))].x)

    zeros = List.duplicate(0.0, n)

    model.bodies
    |> Enum.reduce(zeros, fn body, acc ->
      %{z: dz} = jac[{body.name, :com}]

      Enum.zip_with(acc, Tuple.to_list(dz), fn a, j ->
        a - body.mass * g * j
      end)
    end)
    |> List.to_tuple()
  end

  defp contact_gen(_q, qd, model, poses0, jac) do
    points = contact_points(model)
    k = Map.get(model, :contact_k, 4000.0)
    c = Map.get(model, :contact_c, 80.0)
    mu = Map.get(model, :friction, 1.2)
    n = jac_size(jac)
    zeros = List.duplicate(0.0, n)

    points
    |> Enum.reduce(zeros, fn %{body: name, offset: off, radius: radius}, acc ->
      pose = poses0[name]
      {_x, _y, z} = world_point(pose, off)
      %{x: jx, y: jy, z: jz} = point_jac(jac, name, off, pose)

      vx = dot(jx, qd)
      vy = dot(jy, qd)
      vz = dot(jz, qd)
      pen = radius - z

      if pen > 0.0 do
        fn_ = max(0.0, k * pen - c * vz)
        ft_cap = mu * fn_
        fx = clamp(-120.0 * vx, -ft_cap, ft_cap)
        fy = clamp(-120.0 * vy, -ft_cap, ft_cap)

        acc
        |> add_col(jx, fx)
        |> add_col(jy, fy)
        |> add_col(jz, fn_)
      else
        acc
      end
    end)
    |> List.to_tuple()
  end

  defp drag_gen(qd, model, jac, _poses0) do
    coeff = Map.get(model, :drag, 0.0)
    n = tuple_size(qd)
    zeros = List.duplicate(0.0, n)

    if coeff == 0.0 do
      List.to_tuple(zeros)
    else
      model.bodies
      |> Enum.reduce(zeros, fn body, acc ->
        %{x: jx, y: jy, z: jz} = jac[{body.name, :com}]
        vx = dot(jx, qd)
        vy = dot(jy, qd)
        vz = dot(jz, qd)

        acc
        |> add_col(jx, -coeff * vx)
        |> add_col(jy, -coeff * vy)
        |> add_col(jz, -coeff * vz)
      end)
      |> List.to_tuple()
    end
  end

  defp jac_size(jac) do
    jac
    |> Map.values()
    |> hd()
    |> Map.fetch!(:x)
    |> tuple_size()
  end

  defp jacobians(q, model, poses0) do
    n = tuple_size(q)

    contact_keys =
      Enum.map(contact_points(model), fn %{body: name, offset: off} -> {name, off} end)

    keys =
      model.bodies
      |> Enum.flat_map(fn body -> [{body.name, :com}, {body.name, :origin}] end)
      |> Kernel.++(contact_keys)
      |> Enum.uniq()

    Enum.reduce(keys, %{}, fn key, acc ->
      cols =
        for i <- 0..(n - 1) do
          q2 = put_elem(q, i, elem(q, i) + @eps)
          p0 = key_pos(key, poses0, model)
          p1 = key_pos(key, fk(q2, model), model)
          {dx, dy, dz} = sub(p1, p0)
          {dx / @eps, dy / @eps, dz / @eps}
        end

      {xs, ys, zs} = unzip3(cols)
      Map.put(acc, key, %{x: List.to_tuple(xs), y: List.to_tuple(ys), z: List.to_tuple(zs)})
    end)
  end

  defp key_pos({name, :com}, poses, _model) do
    pose = poses[name]
    world_point(pose, pose.body.com)
  end

  defp key_pos({name, :origin}, poses, _model), do: poses[name].pos
  defp key_pos({name, off}, poses, _model), do: world_point(poses[name], off)

  defp point_jac(jac, name, off, _pose) do
    Map.get_lazy(jac, {name, off}, fn -> jac[{name, :origin}] end)
  end

  defp pose(body, q, acc) do
    case body.joint do
      :fixed ->
        {body[:pos] || {0.0, 0.0, 0.0}, id()}

      {:slide_x, i} ->
        {{elem(q, i), 0.0, 0.0}, id()}

      {:free_planar, ix, iz, it} ->
        theta = elem(q, it)
        {{elem(q, ix), 0.0, elem(q, iz)}, ry(theta)}

      {:free_planar_xy, ix, iy, it} ->
        z = Map.get(body, :z, 0.05)
        {{elem(q, ix), elem(q, iy), z}, rz(elem(q, it))}

      {:free, ix, iy, iz, ir, ip, iw} ->
        pos = {elem(q, ix), elem(q, iy), elem(q, iz)}
        rot = mul(rz(elem(q, iw)), mul(ry(elem(q, ip)), rx(elem(q, ir))))
        {pos, rot}

      {:hinge, i, axis} ->
        parent = acc[body.parent]
        attach = body[:attach] || {0.0, 0.0, 0.0}
        pos = add(parent.pos, apply_r(parent.rot, attach))
        rest = Map.get(body, :rest, id())
        rot = mul(parent.rot, mul(rest, rot_axis(axis, elem(q, i))))
        {pos, rot}
    end
  end

  defp contact_points(model) do
    explicit =
      Enum.map(Map.get(model, :contacts, []), fn p ->
        Map.put_new(p, :radius, 0.0)
      end)

    auto =
      if Map.get(model, :auto_contacts, false) do
        Enum.flat_map(model.bodies, fn body ->
          Enum.flat_map(body.geoms, fn
            {:capsule, a, b, r, _} ->
              [
                %{body: body.name, offset: a, radius: r},
                %{body: body.name, offset: b, radius: r}
              ]

            {:sphere, p, r, _} ->
              [%{body: body.name, offset: p, radius: r}]

            {:box, p, {_sx, _sy, sz}, _} ->
              [%{body: body.name, offset: p, radius: sz}]
          end)
        end)
      else
        []
      end

    explicit ++ auto
  end

  defp project_ground(q, qd, model) do
    case root_z_index(model) do
      nil ->
        {q, qd}

      iz ->
        poses = fk(q, model)

        clearance =
          contact_points(model)
          |> Enum.map(fn %{body: name, offset: off, radius: radius} ->
            {_, _, z} = world_point(poses[name], off)
            z - radius
          end)
          |> case do
            [] -> 0.0
            xs -> Enum.min(xs)
          end

        if clearance < 0.0 do
          q = put_elem(q, iz, elem(q, iz) - clearance)
          qd = if elem(qd, iz) < 0.0, do: put_elem(qd, iz, 0.0), else: qd
          {q, qd}
        else
          {q, qd}
        end
    end
  end

  defp root_z_index(model) do
    case hd(model.bodies).joint do
      {:free_planar, _ix, iz, _it} -> iz
      {:free, _ix, _iy, iz, _ir, _ip, _iw} -> iz
      _ -> nil
    end
  end

  defp apply_limits(q, qd, model) do
    limits = Map.get(model, :limits, [])

    Enum.reduce(limits, {q, qd}, fn {i, lo, hi}, {q, qd} ->
      v = elem(q, i)

      cond do
        v < lo -> {put_elem(q, i, lo), put_elem(qd, i, max(elem(qd, i), 0.0))}
        v > hi -> {put_elem(q, i, hi), put_elem(qd, i, min(elem(qd, i), 0.0))}
        true -> {q, qd}
      end
    end)
  end

  defp geom_kind({:capsule, _, _, _, _}), do: :capsule
  defp geom_kind({:box, _, _, _}), do: :box
  defp geom_kind({:sphere, _, _, _}), do: :sphere

  defp add_scaled(a, b, s) do
    for i <- 0..(tuple_size(a) - 1) do
      elem(a, i) + s * elem(b, i)
    end
    |> List.to_tuple()
  end

  defp add_col(acc, jac, scale) do
    Enum.zip_with(acc, Tuple.to_list(jac), fn a, j -> a + scale * j end)
  end

  defp dot(jac, qd) do
    jac
    |> Tuple.to_list()
    |> Enum.with_index()
    |> Enum.reduce(0.0, fn {j, i}, acc -> acc + j * elem(qd, i) end)
  end

  defp unzip3(cols) do
    {xs, ys, zs} =
      Enum.reduce(cols, {[], [], []}, fn {x, y, z}, {xs, ys, zs} ->
        {[x | xs], [y | ys], [z | zs]}
      end)

    {Enum.reverse(xs), Enum.reverse(ys), Enum.reverse(zs)}
  end

  defp add({ax, ay, az}, {bx, by, bz}), do: {ax + bx, ay + by, az + bz}
  defp sub({ax, ay, az}, {bx, by, bz}), do: {ax - bx, ay - by, az - bz}

  defp clamp(x, lo, hi), do: min(max(x, lo), hi)

  defp id, do: {{1.0, 0.0, 0.0}, {0.0, 1.0, 0.0}, {0.0, 0.0, 1.0}}

  defp rx(a) do
    c = :math.cos(a)
    s = :math.sin(a)
    {{1.0, 0.0, 0.0}, {0.0, c, -s}, {0.0, s, c}}
  end

  defp ry(a) do
    c = :math.cos(a)
    s = :math.sin(a)
    {{c, 0.0, s}, {0.0, 1.0, 0.0}, {-s, 0.0, c}}
  end

  defp rz(a) do
    c = :math.cos(a)
    s = :math.sin(a)
    {{c, -s, 0.0}, {s, c, 0.0}, {0.0, 0.0, 1.0}}
  end

  defp rot_axis({ax, ay, az}, a) do
    n = :math.sqrt(ax * ax + ay * ay + az * az)
    n = if n == 0.0, do: 1.0, else: n
    ax = ax / n
    ay = ay / n
    az = az / n
    c = :math.cos(a)
    s = :math.sin(a)
    t = 1.0 - c

    {{t * ax * ax + c, t * ax * ay - s * az, t * ax * az + s * ay},
     {t * ax * ay + s * az, t * ay * ay + c, t * ay * az - s * ax},
     {t * ax * az - s * ay, t * ay * az + s * ax, t * az * az + c}}
  end

  defp mul(a, b) do
    {{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}} = a
    {{b00, b01, b02}, {b10, b11, b12}, {b20, b21, b22}} = b

    {{a00 * b00 + a01 * b10 + a02 * b20, a00 * b01 + a01 * b11 + a02 * b21,
      a00 * b02 + a01 * b12 + a02 * b22},
     {a10 * b00 + a11 * b10 + a12 * b20, a10 * b01 + a11 * b11 + a12 * b21,
      a10 * b02 + a11 * b12 + a12 * b22},
     {a20 * b00 + a21 * b10 + a22 * b20, a20 * b01 + a21 * b11 + a22 * b21,
      a20 * b02 + a21 * b12 + a22 * b22}}
  end

  defp apply_r({{r00, r01, r02}, {r10, r11, r12}, {r20, r21, r22}}, {x, y, z}) do
    {r00 * x + r01 * y + r02 * z, r10 * x + r11 * y + r12 * z, r20 * x + r21 * y + r22 * z}
  end
end
