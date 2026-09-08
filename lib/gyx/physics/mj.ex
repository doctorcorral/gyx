defmodule Gyx.Physics.Mj do
  @moduledoc """
  Rigid-body step for Farama MuJoCo trees.

  CRBA mass matrix, Jacobian bias (gravity + Coriolis), explicit
  damping/actuators, RK4 or semi-implicit Euler, and soft contacts.
  The default path is `Gyx.Physics.Mjx` (Nx/EXLA). Set
  `config :gyx, :mj_backend, :elixir` for the scalar BEAM stepper.
  """

  @eps 1.0e-7

  def load(xml) do
    model = Gyx.Physics.Mjcf.load(xml)
    Map.put(model, :nx, Gyx.Physics.Mjx.pack(model))
  end

  def data(model, qpos \\ nil, qvel \\ nil) do
    qpos = qpos || model.init_qpos
    qvel = qvel || model.init_qvel

    %{
      qpos: to_tuple(qpos, model.nq),
      qvel: to_tuple(qvel, model.nv),
      qacc: zeros(model.nv),
      ctrl: zeros(model.nu),
      qfrc_actuator: zeros(model.nv),
      qfrc_passive: zeros(model.nv),
      qfrc_bias: zeros(model.nv),
      qfrc_constraint: zeros(model.nv),
      cfrc_ext: List.duplicate({0.0, 0.0, 0.0, 0.0, 0.0, 0.0}, length(model.bodies)),
      site_xpos: [],
      xpos: [],
      xquat: []
    }
  end

  def set_ctrl(data, ctrl), do: %{data | ctrl: to_tuple(ctrl, tuple_size(data.ctrl))}

  def step(data, model, nstep \\ 1)

  def step(%{qpos: _} = data, %{dt: _} = model, nstep) do
    if Gyx.Physics.Mjx.enabled?() and model[:nx] do
      Gyx.Physics.Mjx.step(data, model, nstep)
    else
      Enum.reduce(1..nstep, data, fn _, data -> integrate(model, data) end)
      |> forward(model)
    end
  end

  def step(%{dt: _} = model, %{qpos: _} = data, nstep), do: step(data, model, nstep)

  def forward(data, model) do
    poses = fk(model, data.qpos)
    sites = Enum.map(model.sites, fn s -> site_pos(poses, s) end)
    %{data | xpos: Enum.map(poses, & &1.pos), xquat: Enum.map(poses, & &1.quat), site_xpos: sites}
  end

  def body_com(model, data, name) do
    com_at(model, fk(model, data.qpos), name)
  end

  def com_at(model, poses, name) do
    body = Enum.find(model.bodies, &(&1.name == name))
    pose = Enum.at(poses, body.id)
    add(pose.pos, rotq(pose.quat, body.com))
  end

  def site_xpos(model, data, name) do
    data = if data.site_xpos == [], do: forward(data, model), else: data
    idx = Enum.find_index(model.sites, &(&1.name == name))
    Enum.at(data.site_xpos, idx)
  end

  def fk(model, qpos) do
    qpos = to_tuple(qpos, model.nq)
    n = length(model.bodies)
    acc = List.to_tuple(List.duplicate(nil, n))
    acc = put_elem(acc, 0, %{pos: {0.0, 0.0, 0.0}, quat: {1.0, 0.0, 0.0, 0.0}})

    model.bodies
    |> Enum.drop(1)
    |> Enum.reduce(acc, fn body, acc ->
      parent = elem(acc, body.parent)
      pos = add(parent.pos, rotq(parent.quat, body.pos))
      quat = qmul(parent.quat, body.quat)

      {pos, quat} =
        model.joints
        |> Enum.filter(&(&1.body == body.id))
        |> Enum.reduce({pos, quat}, fn joint, {pos, quat} ->
          apply_joint(joint, qpos, pos, quat)
        end)

      put_elem(acc, body.id, %{pos: pos, quat: quat})
    end)
    |> Tuple.to_list()
  end

  def accelerations(model, qpos, qvel, ctrl) do
    if Gyx.Physics.Mjx.enabled?() and model[:nx] do
      Gyx.Physics.Mjx.accelerations(model, qpos, qvel, ctrl)
    else
      accelerations_elixir(model, qpos, qvel, ctrl)
    end
  end

  defp accelerations_elixir(model, qpos, qvel, ctrl) do
    qpos = to_tuple(qpos, model.nq)
    qvel = to_tuple(qvel, model.nv)
    ctrl = to_tuple(ctrl, model.nu)
    {m, bias, _jac} = mass_bias(model, qpos, qvel)
    act = actuator_force(model, ctrl)
    passive = passive_force(model, qpos, qvel)
    {m, rhs, cforce} = apply_contacts(model, qpos, qvel, m, addv(act, subv(passive, bias)))
    {m, rhs, cforce} = apply_limits(model, qpos, qvel, m, rhs, cforce)
    qacc = rhs |> then(&solve(m, &1)) |> Enum.map(&clamp(&1, -1.0e5, 1.0e5))
    {List.to_tuple(qacc), List.to_tuple(act), List.to_tuple(passive), List.to_tuple(bias), List.to_tuple(cforce)}
  end

  def world_geoms(model, qpos, opts \\ []) do
    poses = fk(model, qpos)
    palette = ~w(#4f46e5 #6366f1 #818cf8 #1e1b4b #0f766e #155e75 #a16207 #9f1239)

    body_geoms =
      Enum.flat_map(model.geoms, fn g ->
        pose = Enum.at(poses, g.body)
        color = Enum.at(palette, rem(g.body, length(palette)))
        [world_geom(g, pose, color)]
      end)

    world = Enum.map(model.world_geoms, &world_geom(&1, %{pos: &1.pos, quat: &1.quat}, "#94a3b8"))
    extras = Keyword.get(opts, :extras, [])
    world ++ body_geoms ++ extras
  end

  def track_pos(model, qpos, name) when is_binary(name) do
    body = Enum.find(model.bodies, &(&1.name == name)) || Enum.at(model.bodies, 1)
    Enum.at(fk(model, qpos), body.id).pos
  end

  def track_pos(model, qpos, name) when is_atom(name), do: track_pos(model, qpos, Atom.to_string(name))
  def track_pos(model, qpos, _), do: track_pos(model, qpos, "torso")

  defp integrate(model, data) do
    case model.integrator do
      :rk4 -> rk4(model, data)
      _ -> euler(model, data)
    end
  end

  defp euler(model, data) do
    {qacc, act, passive, bias, cforce} = accelerations(model, data.qpos, data.qvel, data.ctrl)
    dt = model.dt
    qvel = add_scaled(data.qvel, qacc, dt)
    qpos = integrate_pos(model, data.qpos, qvel, dt)

    %{data | qpos: qpos, qvel: qvel, qacc: qacc, qfrc_actuator: act, qfrc_passive: passive,
      qfrc_bias: bias, qfrc_constraint: cforce}
  end

  defp rk4(model, data) do
    dt = model.dt
    q0 = data.qpos
    v0 = data.qvel
    ctrl = data.ctrl

    {k1, act, passive, bias, cforce} = accelerations(model, q0, v0, ctrl)
    q1 = integrate_pos(model, q0, v0, dt / 2)
    v1 = add_scaled(v0, k1, dt / 2)

    {k2, _, _, _, _} = accelerations(model, q1, v1, ctrl)
    q2 = integrate_pos(model, q0, v1, dt / 2)
    v2 = add_scaled(v0, k2, dt / 2)

    {k3, _, _, _, _} = accelerations(model, q2, v2, ctrl)
    q3 = integrate_pos(model, q0, add_scaled(v0, k3, dt), dt)
    v3 = add_scaled(v0, k3, dt)

    {k4, _, _, _, _} = accelerations(model, q3, v3, ctrl)

    qacc =
      for i <- 0..(model.nv - 1) do
        (elem(k1, i) + 2 * elem(k2, i) + 2 * elem(k3, i) + elem(k4, i)) / 6
      end
      |> List.to_tuple()

    vmid =
      for i <- 0..(model.nv - 1) do
        (elem(v0, i) + elem(v1, i) + elem(v2, i) + elem(v3, i)) / 4
      end
      |> List.to_tuple()

    # Classic RK4 on velocity; position uses the same weighted qvel stages.
    qvel = add_scaled(v0, qacc, dt)

    qpos =
      integrate_pos(
        model,
        q0,
        for(i <- 0..(model.nv - 1), do: (elem(v0, i) + 2 * elem(v1, i) + 2 * elem(v2, i) + elem(v3, i)) / 6)
        |> List.to_tuple(),
        dt
      )

    _ = vmid

    %{data | qpos: qpos, qvel: qvel, qacc: qacc, qfrc_actuator: act, qfrc_passive: passive,
      qfrc_bias: bias, qfrc_constraint: cforce}
  end

  defp integrate_pos(model, qpos, qvel, dt) do
    Enum.reduce(model.joints, qpos, fn joint, q ->
      case joint.type do
        :free ->
          {x, y, z} =
            add(
              {elem(q, joint.qadr), elem(q, joint.qadr + 1), elem(q, joint.qadr + 2)},
              scale({elem(qvel, joint.vadr), elem(qvel, joint.vadr + 1), elem(qvel, joint.vadr + 2)}, dt)
            )

          quat = {elem(q, joint.qadr + 3), elem(q, joint.qadr + 4), elem(q, joint.qadr + 5), elem(q, joint.qadr + 6)}
          w = {elem(qvel, joint.vadr + 3), elem(qvel, joint.vadr + 4), elem(qvel, joint.vadr + 5)}
          quat = quat_integrate(quat, w, dt)

          q
          |> put_elem(joint.qadr, x)
          |> put_elem(joint.qadr + 1, y)
          |> put_elem(joint.qadr + 2, z)
          |> put_elem(joint.qadr + 3, elem(quat, 0))
          |> put_elem(joint.qadr + 4, elem(quat, 1))
          |> put_elem(joint.qadr + 5, elem(quat, 2))
          |> put_elem(joint.qadr + 6, elem(quat, 3))

        _ ->
          put_elem(q, joint.qadr, elem(q, joint.qadr) + dt * elem(qvel, joint.vadr))
      end
    end)
  end

  defp apply_joint(%{type: :free} = joint, qpos, _pos, _quat) do
    pos = {elem(qpos, joint.qadr), elem(qpos, joint.qadr + 1), elem(qpos, joint.qadr + 2)}
    quat = {elem(qpos, joint.qadr + 3), elem(qpos, joint.qadr + 4), elem(qpos, joint.qadr + 5), elem(qpos, joint.qadr + 6)}
    {pos, quat}
  end

  defp apply_joint(%{type: :slide} = joint, qpos, pos, quat) do
    q = elem(qpos, joint.qadr) - joint.ref
    axis = rotq(quat, joint.axis)
    {add(pos, scale(axis, q)), quat}
  end

  defp apply_joint(%{type: :hinge} = joint, qpos, pos, quat) do
    q = elem(qpos, joint.qadr) - joint.ref
    pivot = add(pos, rotq(quat, joint.pos))
    axis = rotq(quat, joint.axis)
    r = axis_angle(axis, q)
    pos = add(pivot, rotq(r, sub(pos, pivot)))
    {pos, qmul(r, quat)}
  end

  defp mass_bias(model, qpos, qvel) do
    poses0 = fk(model, qpos)
    nv = model.nv
    jac = jacobians(model, qpos, poses0)

    m =
      for i <- 0..(nv - 1) do
        for j <- 0..(nv - 1) do
          entry =
            Enum.reduce(model.bodies, 0.0, fn
              %{id: 0}, acc ->
                acc

              body, acc ->
                %{pos: jv, rot: jw} = jac[body.id]
                vi = {elem(jv, i * 3), elem(jv, i * 3 + 1), elem(jv, i * 3 + 2)}
                vj = {elem(jv, j * 3), elem(jv, j * 3 + 1), elem(jv, j * 3 + 2)}
                wi = {elem(jw, i * 3), elem(jw, i * 3 + 1), elem(jw, i * 3 + 2)}
                wj = {elem(jw, j * 3), elem(jw, j * 3 + 1), elem(jw, j * 3 + 2)}
                pose = Enum.at(poses0, body.id)
                i_w = rotate_inertia(pose.quat, body.inertia)
                acc + body.mass * dot(vi, vj) + dot(wi, mul_mat_vec(i_w, wj))
            end)

          armature =
            if i == j do
              model.joints
              |> Enum.filter(&dof_index(&1, i))
              |> Enum.reduce(0.0, fn jnt, acc -> acc + jnt.armature end)
            else
              0.0
            end

          entry + armature
        end
      end

    g = gravity_bias(model, jac)
    c = coriolis_bias(model, qpos, qvel, jac, poses0)
    bias = addv(g, c)
    {m, bias, jac}
  end

  defp dof_index(%{type: :free, vadr: v}, i), do: i >= v and i < v + 6
  defp dof_index(%{vadr: v}, i), do: i == v

  defp gravity_bias(model, jac) do
    {gx, gy, gz} = model.gravity

    Enum.map(0..(model.nv - 1), fn i ->
      Enum.reduce(model.bodies, 0.0, fn
        %{id: 0}, acc ->
          acc

        body, acc ->
          %{pos: jv} = jac[body.id]
          vx = elem(jv, i * 3)
          vy = elem(jv, i * 3 + 1)
          vz = elem(jv, i * 3 + 2)
          acc - body.mass * (gx * vx + gy * vy + gz * vz)
      end)
    end)
  end

  defp coriolis_bias(model, qpos, qvel, jac0, poses0) do
    q1 = integrate_pos(model, qpos, qvel, @eps)
    poses1 = fk(model, q1)
    jac1 = jacobians(model, q1, poses1)

    Enum.map(0..(model.nv - 1), fn i ->
      Enum.reduce(model.bodies, 0.0, fn
        %{id: 0}, acc ->
          acc

        body, acc ->
          v0 = jv_at(jac0[body.id].pos, qvel)
          v1 = jv_at(jac1[body.id].pos, qvel)
          w0 = jv_at(jac0[body.id].rot, qvel)
          a = scale(sub(v1, v0), 1.0 / @eps)
          alpha = scale(sub(jv_at(jac1[body.id].rot, qvel), w0), 1.0 / @eps)
          pose = Enum.at(poses0, body.id)
          i_w = rotate_inertia(pose.quat, body.inertia)
          ji = jac0[body.id]
          jvi = {elem(ji.pos, i * 3), elem(ji.pos, i * 3 + 1), elem(ji.pos, i * 3 + 2)}
          jwi = {elem(ji.rot, i * 3), elem(ji.rot, i * 3 + 1), elem(ji.rot, i * 3 + 2)}
          f = scale(a, body.mass)
          t = add(mul_mat_vec(i_w, alpha), cross(w0, mul_mat_vec(i_w, w0)))
          acc + dot(jvi, f) + dot(jwi, t)
      end)
    end)
  end

  defp jv_at(packed, qvel) do
    nv = tuple_size(qvel)

    Enum.reduce(0..(nv - 1), {0.0, 0.0, 0.0}, fn i, acc ->
      col = {elem(packed, i * 3), elem(packed, i * 3 + 1), elem(packed, i * 3 + 2)}
      add(acc, scale(col, elem(qvel, i)))
    end)
  end

  defp jacobians(model, qpos, poses0) do
    nv = model.nv

    Map.new(model.bodies, fn
      %{id: 0} ->
        {0, %{pos: zeros(nv * 3), rot: zeros(nv * 3)}}

      body ->
        pose0 = Enum.at(poses0, body.id)
        com0 = add(pose0.pos, rotq(pose0.quat, body.com))

        cols =
          for i <- 0..(nv - 1) do
            q2 = perturb(model, qpos, i, @eps)
            poses = fk(model, q2)
            pose = Enum.at(poses, body.id)
            com = add(pose.pos, rotq(pose.quat, body.com))
            dpos = scale(sub(com, com0), 1.0 / @eps)
            dw = quat_diff_vel(pose0.quat, pose.quat, @eps)
            {dpos, dw}
          end

        {pos, rot} =
          Enum.reduce(cols, {[], []}, fn {{px, py, pz}, {wx, wy, wz}}, {ps, rs} ->
            {ps ++ [px, py, pz], rs ++ [wx, wy, wz]}
          end)

        {body.id, %{pos: List.to_tuple(pos), rot: List.to_tuple(rot)}}
    end)
  end

  defp perturb(model, qpos, dof, eps) do
    joint = Enum.find(model.joints, &dof_index(&1, dof))

    cond do
      joint.type == :free and dof >= joint.vadr + 3 ->
        axis_i = dof - joint.vadr - 3
        quat = {elem(qpos, joint.qadr + 3), elem(qpos, joint.qadr + 4), elem(qpos, joint.qadr + 5), elem(qpos, joint.qadr + 6)}
        w = put_elem({0.0, 0.0, 0.0}, axis_i, 1.0)
        {w0, x, y, z} = quat_integrate(quat, w, eps)

        qpos
        |> put_elem(joint.qadr + 3, w0)
        |> put_elem(joint.qadr + 4, x)
        |> put_elem(joint.qadr + 5, y)
        |> put_elem(joint.qadr + 6, z)

      joint.type == :free ->
        put_elem(qpos, joint.qadr + (dof - joint.vadr), elem(qpos, joint.qadr + (dof - joint.vadr)) + eps)

      true ->
        put_elem(qpos, joint.qadr, elem(qpos, joint.qadr) + eps)
    end
  end

  defp actuator_force(model, ctrl) do
    tau = List.duplicate(0.0, model.nv)

    Enum.reduce(Enum.with_index(model.actuators), tau, fn {act, i}, tau ->
      u = clamp(elem(ctrl, i), elem(act.ctrlrange, 0), elem(act.ctrlrange, 1))
      List.update_at(tau, act.vadr, &(&1 + act.gear * u))
    end)
  end

  defp passive_force(model, qpos, qvel) do
    tau =
      Enum.reduce(model.joints, List.duplicate(0.0, model.nv), fn joint, tau ->
        case joint.type do
          :free ->
            tau

          _ ->
            q = elem(qpos, joint.qadr) - joint.ref
            v = elem(qvel, joint.vadr)
            List.update_at(tau, joint.vadr, &(&1 - joint.damping * v - joint.stiffness * q))
        end
      end)

    fluid_force(model, qpos, qvel, tau)
  end

  defp fluid_force(%{viscosity: v, fluid_density: d} = model, qpos, qvel, tau)
       when v > 0 or d > 0 do
    poses = fk(model, qpos)
    jac = jacobians(model, qpos, poses)

    Enum.reduce(model.bodies, tau, fn
      %{id: 0}, tau ->
        tau

      body, tau ->
        vel = jv_at(jac[body.id].pos, qvel)
        speed = norm(vel)
        char = :math.pow(max(body.mass, 1.0e-6) / 1000.0, 1 / 3)
        stokes = scale(vel, -6 * :math.pi() * model.viscosity * char)
        quad = if speed > 1.0e-8, do: scale(vel, -0.5 * model.fluid_density * char * char * speed), else: {0.0, 0.0, 0.0}
        f = add(stokes, quad)

        Enum.reduce(0..(model.nv - 1), tau, fn i, tau ->
          j = jac[body.id].pos
          col = {elem(j, i * 3), elem(j, i * 3 + 1), elem(j, i * 3 + 2)}
          List.update_at(tau, i, &(&1 + dot(col, f)))
        end)
    end)
  end

  defp fluid_force(_, _, _, tau), do: tau

  defp apply_contacts(model, qpos, qvel, mass, rhs) do
    poses = fk(model, qpos)

    contacts =
      model
      |> contacts(poses)
      |> Enum.group_by(&{&1.body_id, &1.geom})
      |> Enum.flat_map(fn {_id, cs} -> [Enum.max_by(cs, & &1.pen)] end)

    Enum.reduce(contacts, {mass, rhs, List.duplicate(0.0, model.nv)}, fn c, {mass, rhs, cf} ->
      jv = point_jac(model, qpos, c.body_id, c.point)
      n = c.normal
      jn = Enum.map(jv, &dot(&1, n))
      vn = Enum.zip_with(jn, Tuple.to_list(qvel), &*/2) |> Enum.sum()
      {timeconst, dampratio} = {Enum.at(c.solref, 0) || 0.02, Enum.at(c.solref, 1) || 1.0}
      k = 1.0 / max(timeconst * timeconst, 1.0e-8)
      b = 2.0 * dampratio / max(timeconst, 1.0e-8)
      fn_ = max(0.0, k * c.pen - b * vn)

      {tx, ty} = tangents(n)
      vel =
        Enum.reduce(Enum.with_index(jv), {0.0, 0.0, 0.0}, fn {col, i}, acc ->
          add(acc, scale(col, elem(qvel, i)))
        end)

      friction? = c.condim >= 3
      mu = hd(c.friction || [1.0])
      ft_cap = mu * fn_
      ftx = if friction?, do: clamp(-120.0 * dot(vel, tx), -ft_cap, ft_cap), else: 0.0
      fty = if friction?, do: clamp(-120.0 * dot(vel, ty), -ft_cap, ft_cap), else: 0.0
      force = add(add(scale(n, fn_), scale(tx, ftx)), scale(ty, fty))

      {rhs, cf} =
        Enum.reduce(0..(model.nv - 1), {rhs, cf}, fn i, {rhs, cf} ->
          fi = dot(Enum.at(jv, i), force)
          {List.update_at(rhs, i, &(&1 + fi)), List.update_at(cf, i, &(&1 + fi))}
        end)

      {add_outer(mass, jn, model.dt * b), rhs, cf}
    end)
  end

  defp point_jac(model, qpos, body_id, world_point) do
    poses0 = fk(model, qpos)
    pose0 = Enum.at(poses0, body_id)
    local = rotq(qconj(pose0.quat), sub(world_point, pose0.pos))

    for i <- 0..(model.nv - 1) do
      poses = fk(model, perturb(model, qpos, i, @eps))
      pose = Enum.at(poses, body_id)
      p1 = add(pose.pos, rotq(pose.quat, local))
      scale(sub(p1, world_point), 1.0 / @eps)
    end
  end

  defp contacts(model, poses) do
    floors = Enum.filter(model.world_geoms, &(&1.type == "plane"))

    Enum.flat_map(model.geoms, fn geom ->
      if geom.contype == 0 or floors == [] do
        []
      else
        pose = Enum.at(poses, geom.body)
        points = geom_contact_points(geom, pose)

        Enum.flat_map(floors, fn floor ->
          if Bitwise.band(geom.contype, floor.conaffinity) == 0 and
               Bitwise.band(floor.contype, geom.conaffinity) == 0 do
            []
          else
            {fx, fy, fz} = floor.pos
            # plane normal from quat; default +Z
            n = rotq(floor.quat, {0.0, 0.0, 1.0})
            off = fx * elem(n, 0) + fy * elem(n, 1) + fz * elem(n, 2)

            Enum.flat_map(points, fn {p, radius} ->
              dist = dot(p, n) - off
              pen = radius + geom.margin - dist

              if pen > 0 do
                [
                    %{
                    body: Enum.at(model.bodies, geom.body).name,
                    body_id: geom.body,
                    geom: geom.name,
                    point: p,
                    normal: n,
                    pen: pen,
                    solref: geom.solref,
                    friction: geom.friction,
                    condim: geom.condim
                  }
                ]
              else
                []
              end
            end)
          end
        end)
      end
    end)
  end

  defp geom_contact_points(%{type: "sphere"} = g, pose) do
    [{add(pose.pos, rotq(pose.quat, g.pos)), hd(g.size)}]
  end

  defp geom_contact_points(%{type: "capsule"} = g, pose) do
    r = hd(g.size)
    h = Enum.at(g.size, 1) || r
    a = add(pose.pos, rotq(pose.quat, add(g.pos, rotq(g.quat, {0.0, 0.0, -h}))))
    b = add(pose.pos, rotq(pose.quat, add(g.pos, rotq(g.quat, {0.0, 0.0, h}))))
    [{a, r}, {b, r}, {scale(add(a, b), 0.5), r}]
  end

  defp geom_contact_points(g, pose) do
    [{add(pose.pos, rotq(pose.quat, g.pos)), hd(g.size || [0.05])}]
  end

  defp apply_limits(model, qpos, qvel, mass, rhs, cf) do
    Enum.reduce(model.joints, {mass, rhs, cf}, fn
      %{type: :free}, acc ->
        acc

      joint, {mass, rhs, cf} ->
        if joint.limited and joint.range do
          {lo, hi} = joint.range
          q = elem(qpos, joint.qadr)
          v = elem(qvel, joint.vadr)

          {pen, sign} =
            cond do
              q > hi -> {q - hi, -1.0}
              q < lo -> {lo - q, 1.0}
              true -> {0.0, 0.0}
            end

          if pen > 0 do
            k = 1.0 / 0.0004
            b = 2.0 / 0.02
            f = sign * max(0.0, k * pen - b * v * sign)
            rhs = List.update_at(rhs, joint.vadr, &(&1 + f))
            cf = List.update_at(cf, joint.vadr, &(&1 + f))
            jn = List.duplicate(0.0, model.nv) |> List.replace_at(joint.vadr, sign)
            {add_outer(mass, jn, model.dt * b), rhs, cf}
          else
            {mass, rhs, cf}
          end
        else
          {mass, rhs, cf}
        end
    end)
  end

  defp add_outer(mass, vec, scale) do
    Enum.with_index(mass)
    |> Enum.map(fn {row, i} ->
      vi = Enum.at(vec, i)

      Enum.with_index(row)
      |> Enum.map(fn {x, j} -> x + scale * vi * Enum.at(vec, j) end)
    end)
  end

  defp tangents({nx, ny, nz}) do
    t =
      if abs(nz) < 0.9 do
        normalize(cross({nx, ny, nz}, {0.0, 0.0, 1.0}))
      else
        normalize(cross({nx, ny, nz}, {0.0, 1.0, 0.0}))
      end

    {t, cross({nx, ny, nz}, t)}
  end

  defp site_pos(poses, site) do
    pose = Enum.at(poses, site.body)
    add(pose.pos, rotq(pose.quat, site.pos))
  end

  defp world_geom(%{type: "capsule"} = g, pose, color) do
    h = Enum.at(g.size, 1) || hd(g.size)
    a = add(pose.pos, rotq(pose.quat, add(g.pos, rotq(g.quat, {0.0, 0.0, -h}))))
    b = add(pose.pos, rotq(pose.quat, add(g.pos, rotq(g.quat, {0.0, 0.0, h}))))
    %{id: g.name, geom: "capsule", from: v3(a), to: v3(b), radius: hd(g.size), color: color}
  end

  defp world_geom(%{type: "sphere"} = g, pose, color) do
    p = add(pose.pos, rotq(pose.quat, g.pos))
    %{id: g.name, geom: "sphere", pos: v3(p), radius: hd(g.size), color: color}
  end

  defp world_geom(%{type: "box"} = g, pose, color) do
    [sx, sy, sz | _] = g.size ++ [0.05, 0.05, 0.05]
    p = add(pose.pos, rotq(pose.quat, g.pos))
    %{id: g.name, geom: "box", pos: v3(p), size: [sx, sy, sz], rot: [1, 0, 0, 0], color: color}
  end

  defp world_geom(%{type: "cylinder"} = g, pose, color), do: world_geom(%{g | type: "capsule"}, pose, color)

  defp world_geom(%{type: "plane"} = g, pose, color) do
    p = add(pose.pos, rotq(pose.quat, g.pos))
    %{id: g.name, geom: "sphere", pos: v3(p), radius: 0.001, color: color}
  end

  defp world_geom(g, pose, color) do
    p = add(pose.pos, rotq(pose.quat, g.pos))
    %{id: Map.get(g, :name, "geom"), geom: "sphere", pos: v3(p), radius: 0.02, color: color}
  end

  defp v3({x, y, z}), do: [x * 1.0, y * 1.0, z * 1.0]

  defp rotate_inertia(q, i), do: rotate_mat(q, i)

  defp rotate_mat(q, m) do
    r = quat_to_mat(q)
    mul_mat(mul_mat(r, m), transpose(r))
  end

  defp quat_to_mat({w, x, y, z}) do
    {{1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)},
     {2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)},
     {2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)}}
  end

  defp mul_mat({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}, {{b00, b01, b02}, {b10, b11, b12}, {b20, b21, b22}}) do
    {{a00 * b00 + a01 * b10 + a02 * b20, a00 * b01 + a01 * b11 + a02 * b21, a00 * b02 + a01 * b12 + a02 * b22},
     {a10 * b00 + a11 * b10 + a12 * b20, a10 * b01 + a11 * b11 + a12 * b21, a10 * b02 + a11 * b12 + a12 * b22},
     {a20 * b00 + a21 * b10 + a22 * b20, a20 * b01 + a21 * b11 + a22 * b21, a20 * b02 + a21 * b12 + a22 * b22}}
  end

  defp mul_mat_vec({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}, {x, y, z}) do
    {a00 * x + a01 * y + a02 * z, a10 * x + a11 * y + a12 * z, a20 * x + a21 * y + a22 * z}
  end

  defp transpose({{a00, a01, a02}, {a10, a11, a12}, {a20, a21, a22}}) do
    {{a00, a10, a20}, {a01, a11, a21}, {a02, a12, a22}}
  end

  defp solve(m, b) do
    n = length(b)
    a = Enum.map(Enum.with_index(m), fn {row, i} -> row ++ [Enum.at(b, i)] end)
    a = Enum.reduce(0..(n - 1), a, fn k, a ->
      {pivot_i, _} =
        k..(n - 1)
        |> Enum.map(fn i -> {i, abs(Enum.at(Enum.at(a, i), k))} end)
        |> Enum.max_by(&elem(&1, 1))

      a = if pivot_i == k, do: a, else: swap(a, k, pivot_i)
      pk = Enum.at(Enum.at(a, k), k)
      pk = if abs(pk) < 1.0e-12, do: 1.0e-12, else: pk
      rowk = Enum.map(Enum.at(a, k), &(&1 / pk))
      a = List.replace_at(a, k, rowk)

      Enum.reduce(0..(n - 1), a, fn i, a ->
        if i == k do
          a
        else
          f = Enum.at(Enum.at(a, i), k)
          row = Enum.zip_with(Enum.at(a, i), rowk, fn x, y -> x - f * y end)
          List.replace_at(a, i, row)
        end
      end)
    end)

    Enum.map(a, &List.last/1)
  end

  defp swap(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)
    list |> List.replace_at(i, b) |> List.replace_at(j, a)
  end

  defp quat_diff_vel(q0, q1, dt) do
    {w0, x0, y0, z0} = qconj(q0)
    {w, x, y, z} = qmul({w0, x0, y0, z0}, q1)
    n = :math.sqrt(x * x + y * y + z * z)
    angle = 2 * :math.atan2(n, w)
    if n < 1.0e-12, do: {0.0, 0.0, 0.0}, else: scale({x / n, y / n, z / n}, angle / dt)
  end

  defp quat_integrate(q, w, dt) do
    ang = norm(w) * dt

    if ang < 1.0e-12 do
      q
    else
      axis = scale(w, 1.0 / norm(w))
      qmul(q, axis_angle(axis, ang))
    end
  end

  defp axis_angle({x, y, z}, ang) do
    s = :math.sin(ang / 2)
    {:math.cos(ang / 2), x * s, y * s, z * s}
  end

  defp qmul({w1, x1, y1, z1}, {w2, x2, y2, z2}) do
    {w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2, w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
     w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2, w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2}
  end

  defp qconj({w, x, y, z}), do: {w, -x, -y, -z}

  defp rotq({w, x, y, z}, {vx, vy, vz}) do
    tx = 2 * (y * vz - z * vy)
    ty = 2 * (z * vx - x * vz)
    tz = 2 * (x * vy - y * vx)
    {vx + w * tx + (y * tz - z * ty), vy + w * ty + (z * tx - x * tz), vz + w * tz + (x * ty - y * tx)}
  end

  defp add({ax, ay, az}, {bx, by, bz}), do: {ax + bx, ay + by, az + bz}
  defp sub({ax, ay, az}, {bx, by, bz}), do: {ax - bx, ay - by, az - bz}
  defp scale({x, y, z}, s), do: {x * s, y * s, z * s}
  defp dot({ax, ay, az}, {bx, by, bz}), do: ax * bx + ay * by + az * bz
  defp cross({ax, ay, az}, {bx, by, bz}), do: {ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx}
  defp norm(v), do: :math.sqrt(dot(v, v))
  defp normalize(v), do: scale(v, 1.0 / max(norm(v), 1.0e-12))

  defp addv(a, b) when is_tuple(a), do: addv(Tuple.to_list(a), b)
  defp addv(a, b) when is_tuple(b), do: addv(a, Tuple.to_list(b))
  defp addv(a, b), do: Enum.zip_with(a, b, &+/2)

  defp subv(a, b) when is_tuple(a), do: subv(Tuple.to_list(a), b)
  defp subv(a, b) when is_tuple(b), do: subv(a, Tuple.to_list(b))
  defp subv(a, b), do: Enum.zip_with(a, b, &-/2)

  defp add_scaled(a, b, s) do
    for(i <- 0..(tuple_size(a) - 1), do: elem(a, i) + s * elem(b, i))
    |> List.to_tuple()
  end

  defp zeros(n), do: List.duplicate(0.0, n) |> List.to_tuple()

  defp to_tuple(t, n) when is_tuple(t) and tuple_size(t) == n, do: t
  defp to_tuple(t, n) when is_tuple(t), do: t |> Tuple.to_list() |> to_tuple(n)
  defp to_tuple(l, n) when is_list(l), do: l |> Enum.take(n) |> pad(n) |> List.to_tuple()
  defp pad(l, n), do: l ++ List.duplicate(0.0, max(n - length(l), 0))

  defp clamp(x, lo, hi), do: min(max(x, lo), hi)
end
