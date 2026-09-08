defmodule Gyx.Physics.Mjx do
  @moduledoc """
  EXLA-compiled Farama step. Same contract as `Gyx.Physics.Mj`.

  Analytic spatial Jacobians and Coriolis, per-body joint lists,
  specialized RK4/Euler kernels, and batched floor contacts.
  """

  import Nx.Defn

  def enabled?, do: Application.get_env(:gyx, :mj_backend, :nx) == :nx

  def pack(model) do
    nb = length(model.bodies)
    nj = max(length(model.joints), 1)
    ng = max(length(model.geoms), 1)
    nv = model.nv
    nu = max(model.nu, 1)
    joints = pad_joints(model.joints)
    geoms = pad_geoms(model.geoms)
    limited = pad_limited(model.joints)
    acts = pad_acts(model.actuators)
    {dof_kind, dof_qidx, dof_axis, dof_body, dof_axis_vec, dof_pivot} = pack_dofs(model.joints, nv)
    {jpb, body_joint} = pack_body_joints(model.bodies, model.joints)
    sites = pad_sites(model.sites)

    floor =
      Enum.find(model.world_geoms, &(&1.type == "plane")) ||
        %{pos: {0.0, 0.0, 0.0}, quat: {1.0, 0.0, 0.0, 0.0}, conaffinity: 0}

    %{
      nq: model.nq,
      nv: nv,
      nb: nb,
      nj: nj,
      ng: ng,
      nu: nu,
      jpb: jpb,
      ns: length(sites),
      nl: length(limited),
      dt: f(model.dt),
      integrator: f(if(model.integrator == :rk4, do: 1.0, else: 0.0)),
      gravity: vec3(model.gravity),
      viscosity: f(model.viscosity || 0.0),
      fluid_density: f(model.fluid_density || 0.0),
      body_parent: ints(Enum.map(model.bodies, & &1.parent)),
      body_pos: stack3(Enum.map(model.bodies, & &1.pos)),
      body_quat: stack4(Enum.map(model.bodies, & &1.quat)),
      body_mass: floats(Enum.map(model.bodies, & &1.mass)),
      body_com: stack3(Enum.map(model.bodies, & &1.com)),
      body_inertia: inertia_tensor(Enum.map(model.bodies, & &1.inertia)),
      joint_type: ints(Enum.map(joints, &joint_code(&1.type))),
      joint_body: ints(Enum.map(joints, & &1.body)),
      joint_qadr: ints(Enum.map(joints, & &1.qadr)),
      joint_vadr: ints(Enum.map(joints, & &1.vadr)),
      joint_axis: stack3(Enum.map(joints, & &1.axis)),
      joint_pos: stack3(Enum.map(joints, & &1.pos)),
      joint_ref: floats(Enum.map(joints, &(&1.ref || 0.0))),
      joint_damping: floats(Enum.map(joints, &(&1.damping || 0.0))),
      joint_stiffness: floats(Enum.map(joints, &(&1.stiffness || 0.0))),
      joint_limited: floats(Enum.map(joints, &if(&1.limited && &1.range, do: 1.0, else: 0.0))),
      joint_lo: floats(Enum.map(joints, &joint_lo/1)),
      joint_hi: floats(Enum.map(joints, &joint_hi/1)),
      act_vadr: ints(Enum.map(acts, & &1.vadr)),
      act_gear: floats(Enum.map(acts, & &1.gear)),
      act_lo: floats(Enum.map(acts, &elem(&1.ctrlrange, 0))),
      act_hi: floats(Enum.map(acts, &elem(&1.ctrlrange, 1))),
      geom_body: ints(Enum.map(geoms, & &1.body)),
      geom_type: ints(Enum.map(geoms, &geom_code(&1.type))),
      geom_pos: stack3(Enum.map(geoms, & &1.pos)),
      geom_quat: stack4(Enum.map(geoms, & &1.quat)),
      geom_radius: floats(Enum.map(geoms, &(hd(&1.size || [0.05])))),
      geom_half: floats(Enum.map(geoms, &geom_half/1)),
      geom_contype: floats(Enum.map(geoms, &(&1.contype * 1.0))),
      geom_margin: floats(Enum.map(geoms, &(&1.margin || 0.0))),
      geom_solref0: floats(Enum.map(geoms, &(Enum.at(&1.solref || [0.02], 0) || 0.02))),
      geom_solref1: floats(Enum.map(geoms, &(Enum.at(&1.solref || [0.02, 1.0], 1) || 1.0))),
      geom_friction: floats(Enum.map(geoms, &(hd(&1.friction || [1.0])))),
      geom_condim: floats(Enum.map(geoms, &(&1.condim * 1.0))),
      floor_pos: vec3(floor.pos),
      floor_quat: vec4(floor.quat),
      floor_aff: f(Map.get(floor, :conaffinity, 0) * 1.0),
      has_free: f(if(Enum.any?(model.joints, &(&1.type == :free)), do: 1.0, else: 0.0)),
      free_qadr: ints([free_qadr(model.joints)]),
      free_vadr: ints([free_vadr(model.joints)]),
      dof_kind: ints(dof_kind),
      dof_qidx: ints(dof_qidx),
      dof_axis: ints(dof_axis),
      dof_body: ints(dof_body),
      dof_axis_vec: stack3(dof_axis_vec),
      dof_pivot_local: stack3(dof_pivot),
      affect: affect_mask(model.bodies, dof_body, nv),
      body_joint: body_joint,
      site_body: ints(Enum.map(sites, & &1.body)),
      site_pos: stack3(Enum.map(sites, & &1.pos)),
      armature_dof: floats(armature_dof(model.joints, nv)),
      limit_qadr: ints(Enum.map(limited, & &1.qadr)),
      limit_vadr: ints(Enum.map(limited, & &1.vadr)),
      limit_lo: floats(Enum.map(limited, &joint_lo/1)),
      limit_hi: floats(Enum.map(limited, &joint_hi/1))
    }
  end

  def step(data, model, nstep) do
    p = model[:nx] || pack(model)
    qpos = data[:qpos_t] || to1(data.qpos, p.nq)
    qvel = data[:qvel_t] || to1(data.qvel, p.nv)
    ctrl = to1(data.ctrl, p.nu)
    nstep_t = Nx.tensor(nstep, type: :s32)
    opts = size_opts(p, model)
    t = tensor_pack(p)
    rk4? = model.integrator == :rk4

    {qpos, qvel, cf, sites} =
      cond do
        model.sites != [] and rk4? -> integrate_kin_rk4(qpos, qvel, ctrl, nstep_t, t, opts)
        model.sites != [] -> integrate_kin_euler(qpos, qvel, ctrl, nstep_t, t, opts)
        rk4? ->
          {qpos, qvel} = integrate_dyn_rk4(qpos, qvel, ctrl, nstep_t, t, opts)
          {qpos, qvel, nil, nil}

        true ->
          {qpos, qvel} = integrate_dyn_euler(qpos, qvel, ctrl, nstep_t, t, opts)
          {qpos, qvel, nil, nil}
      end

    {qpos_h, qvel_h} = from_state(qpos, qvel, p.nq, p.nv)

    data =
      data
      |> Map.put(:qpos, qpos_h)
      |> Map.put(:qvel, qvel_h)
      |> Map.put(:qpos_t, qpos)
      |> Map.put(:qvel_t, qvel)

    data =
      if model.sites == [] do
        data
      else
        data
        |> Map.put(:qfrc_constraint, from1(cf, p.nv))
        |> Map.put(:site_xpos, from3(sites, length(model.sites)))
      end

    data
  end

  def accelerations(model, qpos, qvel, ctrl) do
    p = model[:nx] || pack(model)
    {qacc, act, passive, bias, cf} =
      acc_host(to1(qpos, p.nq), to1(qvel, p.nv), to1(ctrl, p.nu), tensor_pack(p), size_opts(p, model))
    {from1(qacc, p.nv), from1(act, p.nv), from1(passive, p.nv), from1(bias, p.nv), from1(cf, p.nv)}
  end

  defn acc_host(qpos, qvel, ctrl, p, opts \\ []) do
    opts = keyword!(opts, nq: 1, nv: 1, nb: 1, nj: 1, ng: 1, nu: 1, jpb: 1, ns: 1, nl: 1, fluid: 0, free: 0, contact: 0, friction: 0, limit: 0, slide: 0, capsule: 0, sphere: 0, need_cf: 0)
    accelerations_t(qpos, qvel, ctrl, p, opts)
  end

  defn integrate_dyn_rk4(qpos, qvel, ctrl, nstep, p, opts \\ []) do
    opts = keyword!(opts, nq: 1, nv: 1, nb: 1, nj: 1, ng: 1, nu: 1, jpb: 1, ns: 1, nl: 1, fluid: 0, free: 0, contact: 0, friction: 0, limit: 0, slide: 0, capsule: 0, sphere: 0, need_cf: 0)
    advance_dyn_rk4(qpos, qvel, ctrl, nstep, p, opts)
  end

  defn integrate_dyn_euler(qpos, qvel, ctrl, nstep, p, opts \\ []) do
    opts = keyword!(opts, nq: 1, nv: 1, nb: 1, nj: 1, ng: 1, nu: 1, jpb: 1, ns: 1, nl: 1, fluid: 0, free: 0, contact: 0, friction: 0, limit: 0, slide: 0, capsule: 0, sphere: 0, need_cf: 0)
    advance_dyn_euler(qpos, qvel, ctrl, nstep, p, opts)
  end

  defn integrate_kin_rk4(qpos, qvel, ctrl, nstep, p, opts \\ []) do
    opts = keyword!(opts, nq: 1, nv: 1, nb: 1, nj: 1, ng: 1, nu: 1, jpb: 1, ns: 1, nl: 1, fluid: 0, free: 0, contact: 0, friction: 0, limit: 0, slide: 0, capsule: 0, sphere: 0, need_cf: 0)
    {qpos, qvel, cf} = advance_rk4(qpos, qvel, ctrl, nstep, p, opts)
    {pos, quat} = fk(qpos, p, opts)
    {qpos, qvel, cf, site_points(pos, quat, p)}
  end

  defn integrate_kin_euler(qpos, qvel, ctrl, nstep, p, opts \\ []) do
    opts = keyword!(opts, nq: 1, nv: 1, nb: 1, nj: 1, ng: 1, nu: 1, jpb: 1, ns: 1, nl: 1, fluid: 0, free: 0, contact: 0, friction: 0, limit: 0, slide: 0, capsule: 0, sphere: 0, need_cf: 0)
    {qpos, qvel, cf} = advance_euler(qpos, qvel, ctrl, nstep, p, opts)
    {pos, quat} = fk(qpos, p, opts)
    {qpos, qvel, cf, site_points(pos, quat, p)}
  end

  defnp advance_dyn_rk4(qpos, qvel, ctrl, nstep, p, opts) do
    i = Nx.tensor(0, type: :s32)

    {_, qpos, qvel, _, _, _} =
      while {i, qpos, qvel, ctrl, p, nstep}, Nx.less(i, nstep) do
        {qpos, qvel} = rk4_dyn(qpos, qvel, ctrl, p, opts)
        {i + 1, qpos, qvel, ctrl, p, nstep}
      end

    {qpos, qvel}
  end

  defnp advance_dyn_euler(qpos, qvel, ctrl, nstep, p, opts) do
    i = Nx.tensor(0, type: :s32)

    {_, qpos, qvel, _, _, _} =
      while {i, qpos, qvel, ctrl, p, nstep}, Nx.less(i, nstep) do
        {qpos, qvel} = euler_dyn(qpos, qvel, ctrl, p, opts)
        {i + 1, qpos, qvel, ctrl, p, nstep}
      end

    {qpos, qvel}
  end

  defnp advance_rk4(qpos, qvel, ctrl, nstep, p, opts) do
    i = Nx.tensor(0, type: :s32)
    cf = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]})

    {_, qpos, qvel, cf, _, _, _} =
      while {i, qpos, qvel, cf, ctrl, p, nstep}, Nx.less(i, nstep) do
        {qpos, qvel, cf} = rk4_step(qpos, qvel, ctrl, p, opts)
        {i + 1, qpos, qvel, cf, ctrl, p, nstep}
      end

    {qpos, qvel, cf}
  end

  defnp advance_euler(qpos, qvel, ctrl, nstep, p, opts) do
    i = Nx.tensor(0, type: :s32)
    cf = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]})

    {_, qpos, qvel, cf, _, _, _} =
      while {i, qpos, qvel, cf, ctrl, p, nstep}, Nx.less(i, nstep) do
        {qpos, qvel, cf} = euler(qpos, qvel, ctrl, p, opts)
        {i + 1, qpos, qvel, cf, ctrl, p, nstep}
      end

    {qpos, qvel, cf}
  end

  defnp euler_dyn(qpos, qvel, ctrl, p, opts) do
    qacc = acc_only(qpos, qvel, ctrl, p, opts)
    qvel = qvel + qacc * p.dt
    qpos = integrate_pos(qpos, qvel, p.dt, p, opts)
    {qpos, qvel}
  end

  defnp euler(qpos, qvel, ctrl, p, opts) do
    {qacc, cf} = acc_step(qpos, qvel, ctrl, p, opts)
    qvel = qvel + qacc * p.dt
    qpos = integrate_pos(qpos, qvel, p.dt, p, opts)
    {qpos, qvel, cf}
  end

  defnp rk4_dyn(q0, v0, ctrl, p, opts) do
    dt = p.dt
    k1 = acc_only(q0, v0, ctrl, p, opts)
    v1 = v0 + k1 * (dt / 2.0)
    k2 = acc_only(integrate_pos(q0, v0, dt / 2.0, p, opts), v1, ctrl, p, opts)
    v2 = v0 + k2 * (dt / 2.0)
    k3 = acc_only(integrate_pos(q0, v1, dt / 2.0, p, opts), v2, ctrl, p, opts)
    v3 = v0 + k3 * dt
    k4 = acc_only(integrate_pos(q0, v0 + k3 * dt, dt, p, opts), v3, ctrl, p, opts)
    qacc = (k1 + k2 * 2.0 + k3 * 2.0 + k4) / 6.0
    qvel = v0 + qacc * dt
    vpos = (v0 + v1 * 2.0 + v2 * 2.0 + v3) / 6.0
    qpos = integrate_pos(q0, vpos, dt, p, opts)
    {qpos, qvel}
  end

  defnp rk4_step(q0, v0, ctrl, p, opts) do
    dt = p.dt
    {k1, cf} = acc_step(q0, v0, ctrl, p, opts)
    v1 = v0 + k1 * (dt / 2.0)
    {k2, _} = acc_step(integrate_pos(q0, v0, dt / 2.0, p, opts), v1, ctrl, p, opts)
    v2 = v0 + k2 * (dt / 2.0)
    {k3, _} = acc_step(integrate_pos(q0, v1, dt / 2.0, p, opts), v2, ctrl, p, opts)
    v3 = v0 + k3 * dt
    {k4, _} = acc_step(integrate_pos(q0, v0 + k3 * dt, dt, p, opts), v3, ctrl, p, opts)
    qacc = (k1 + k2 * 2.0 + k3 * 2.0 + k4) / 6.0
    qvel = v0 + qacc * dt
    vpos = (v0 + v1 * 2.0 + v2 * 2.0 + v3) / 6.0
    qpos = integrate_pos(q0, vpos, dt, p, opts)
    {qpos, qvel, cf}
  end

  defnp acc_only(qpos, qvel, ctrl, p, opts) do
    {qacc, _act, _passive, _bias, _cf} = accelerations_t(qpos, qvel, ctrl, p, opts)
    qacc
  end

  defnp acc_step(qpos, qvel, ctrl, p, opts) do
    {qacc, _act, _passive, _bias, cf} = accelerations_t(qpos, qvel, ctrl, p, opts)
    {qacc, cf}
  end

  defnp accelerations_t(qpos, qvel, ctrl, p, opts) do
    {mass, bias, jv, jw, pos, quat} = mass_bias(qpos, qvel, p, opts)
    act = actuator_force(ctrl, p, opts)
    passive = passive_force(qpos, qvel, jv, p, opts)
    rhs = act + passive - bias

    {mass, rhs, cf} =
      if opts[:contact] == 1 do
        apply_contacts(qvel, jv, jw, pos, quat, mass, rhs, p, opts)
      else
        {mass, rhs, Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]})}
      end

    {mass, rhs, cf} =
      if opts[:limit] == 1 do
        apply_limits(qpos, qvel, mass, rhs, cf, p, opts)
      else
        {mass, rhs, cf}
      end

    qacc = Nx.LinAlg.solve(mass + Nx.eye(opts[:nv], type: :f64) * 1.0e-12, rhs)
    {Nx.clip(qacc, -1.0e5, 1.0e5), act, passive, bias, cf}
  end

  defnp mass_bias(qpos, qvel, p, opts) do
    {pos, quat} = fk(qpos, p, opts)
    {jv, jw} = jacobians(qpos, pos, quat, p, opts)
    i_w = rotate_inertia_batch(quat, p.body_inertia, p, opts)
    mass_b = Nx.reshape(p.body_mass, {:auto, 1, 1})
    m = Nx.dot(jv * mass_b, [0, 2], jv, [0, 2])
    iw_jw = batched_imat_vec(i_w, jw, p, opts)
    m = m + Nx.dot(jw, [0, 2], iw_jw, [0, 2]) + Nx.put_diagonal(Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv], opts[:nv]}), p.armature_dof)
    g = -Nx.sum(mass_b * jv * Nx.reshape(p.gravity, {1, 1, 3}), axes: [0, 2])
    c = coriolis_bias(pos, quat, qvel, jv, jw, i_w, p, opts)
    {m, g + c, jv, jw, pos, quat}
  end

  defnp coriolis_bias(pos, quat, qvel, jv, jw, i_w, p, opts) do
    v = Nx.dot(jv, [1], qvel, [0])
    w = Nx.dot(jw, [1], qvel, [0])
    w_w = rotq_batch(quat, w)
    {axis_w, pivot, use_w, affect} = dof_twists(pos, quat, p, opts)
    owner = p.dof_body
    com = pos + rotq_batch(quat, p.body_com)
    kind = Nx.broadcast(Nx.reshape(p.dof_kind, {:auto, 1}), {opts[:nv], 3})
    w_parent = Nx.take(w_w, p.body_parent)
    w_frame = Nx.select(kind == 3, Nx.take(w_w, owner), Nx.take(w_parent, owner))
    d_axis = Nx.select(kind == 2, Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv], 3}), cross_batch(w_frame, axis_w))
    com_o = Nx.take(com, owner)
    v_o = Nx.take(v, owner)
    w_o = Nx.take(w_w, owner)
    v_pivot = v_o + cross_batch(w_o, pivot - com_o)
    com_b = Nx.reshape(com, {opts[:nb], 1, 3})
    v_b = Nx.reshape(v, {opts[:nb], 1, 3})
    axis_b = Nx.reshape(axis_w, {1, opts[:nv], 3})
    d_axis_b = Nx.reshape(d_axis, {1, opts[:nv], 3})
    pivot_b = Nx.reshape(pivot, {1, opts[:nv], 3})
    v_pivot_b = Nx.reshape(v_pivot, {1, opts[:nv], 3})
    d_jv = Nx.select(use_w, cross_bnv(d_axis_b, com_b - pivot_b) + cross_bnv(axis_b, v_b - v_pivot_b), d_axis_b) * affect
    zeros = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nb], opts[:nv], 3})
    d_jw_w = Nx.select(use_w, d_axis_b, zeros) * affect
    a = Nx.dot(d_jv, [1], qvel, [0])
    alpha_w = Nx.dot(d_jw_w, [1], qvel, [0])
    alpha = rotq_batch(qconj_batch(quat), alpha_w)
    f = a * Nx.reshape(p.body_mass, {:auto, 1})
    iw_w = batched_i_vec(i_w, w, p, opts)
    t = batched_i_vec(i_w, alpha, p, opts) + cross_batch(w, iw_w)
    Nx.dot(jv, [0, 2], f, [0, 1]) + Nx.dot(jw, [0, 2], t, [0, 1])
  end

  defnp jacobians(_qpos, pos, quat, p, opts) do
    com = pos + rotq_batch(quat, p.body_com)
    {axis_w, pivot, use_w, affect} = dof_twists(pos, quat, p, opts)
    com_b = Nx.reshape(com, {opts[:nb], 1, 3})
    axis_b = Nx.reshape(axis_w, {1, opts[:nv], 3})
    pivot_b = Nx.reshape(pivot, {1, opts[:nv], 3})
    jv = Nx.select(use_w, cross_bnv(axis_b, com_b - pivot_b), axis_b) * affect
    zeros = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nb], opts[:nv], 3})
    jw_w = Nx.select(use_w, axis_b, zeros) * affect
    {jv, rotq_conj_bnv(quat, jw_w)}
  end

  defnp dof_twists(pos, quat, p, opts) do
    quat_pre = qmul_batch(Nx.take(quat, p.body_parent), p.body_quat)
    owner = p.dof_body
    kind = Nx.broadcast(Nx.reshape(p.dof_kind, {:auto, 1}), {opts[:nv], 3})
    axis_w = rotq_batch(Nx.take(quat_pre, owner), p.dof_axis_vec)
    axis_w = Nx.select(kind == 2, p.dof_axis_vec, axis_w)
    axis_w = Nx.select(kind == 3, rotq_batch(Nx.take(quat, owner), p.dof_axis_vec), axis_w)
    pos_d = Nx.take(pos, owner)
    pivot = pos_d + rotq_batch(Nx.take(quat, owner), p.dof_pivot_local)
    pivot = Nx.select(kind == 3, pos_d, pivot)
    affect = Nx.reshape(p.affect, {opts[:nb], opts[:nv], 1})
    use_w = Nx.broadcast(Nx.reshape(p.dof_kind == 0 or p.dof_kind == 3, {1, opts[:nv], 1}), {opts[:nb], opts[:nv], 3})
    {axis_w, pivot, use_w, affect}
  end

  defnp fk(qpos, p, opts) do
    pos = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nb], 3})
    quat = Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nb], 4})
    quat = Nx.put_slice(quat, [0, 0], Nx.tensor([[1.0, 0.0, 0.0, 0.0]], type: :f64))
    i = Nx.tensor(1, type: :s32)

    {_, pos, quat, _, _} =
      while {i, pos, quat, qpos, p}, Nx.less(i, opts[:nb]) do
        parent = p.body_parent[i]
        pos_i = pos[parent] + rotq(quat[parent], p.body_pos[i])
        quat_i = qmul(quat[parent], p.body_quat[i])
        {pos_i, quat_i} = apply_joints(i, qpos, pos_i, quat_i, p, opts)
        pos = Nx.put_slice(pos, [i, 0], Nx.reshape(pos_i, {1, 3}))
        quat = Nx.put_slice(quat, [i, 0], Nx.reshape(quat_i, {1, 4}))
        {i + 1, pos, quat, qpos, p}
      end

    {pos, quat}
  end

  defnp apply_joints(body, qpos, pos, quat, p, opts) do
    {pos, quat} = apply_joint_j(p.body_joint[body][0], body, qpos, pos, quat, p, opts)
    {pos, quat} = if opts[:jpb] > 1, do: apply_joint_j(p.body_joint[body][1], body, qpos, pos, quat, p, opts), else: {pos, quat}
    {pos, quat} = if opts[:jpb] > 2, do: apply_joint_j(p.body_joint[body][2], body, qpos, pos, quat, p, opts), else: {pos, quat}
    {pos, quat}
  end

  defnp site_points(pos, quat, p) do
    b = p.site_body
    Nx.take(pos, b) + rotq_batch(Nx.take(quat, b), p.site_pos)
  end

  defnp apply_joint_j(j, body, qpos, pos, quat, p, opts) do
    live = j >= 0
    j = Nx.max(j, 0)
    belong = live and p.joint_body[j] == body
    typ = p.joint_type[j]
    qadr = p.joint_qadr[j]
    q = at(qpos, qadr) - p.joint_ref[j]

    {pos_n, quat_n} =
      if opts[:free] == 1 and typ == 2 do
        {
          Nx.stack([at(qpos, qadr), at(qpos, qadr + 1), at(qpos, qadr + 2)]),
          Nx.stack([at(qpos, qadr + 3), at(qpos, qadr + 4), at(qpos, qadr + 5), at(qpos, qadr + 6)])
        }
      else
        if opts[:slide] == 1 and typ == 1 do
          {pos + rotq(quat, p.joint_axis[j]) * q, quat}
        else
          hinge(q, p.joint_axis[j], p.joint_pos[j], pos, quat)
        end
      end

    {Nx.select(belong, pos_n, pos), Nx.select(belong, quat_n, quat)}
  end

  defnp hinge(q, axis, jpos, pos, quat) do
    pivot = pos + rotq(quat, jpos)
    r = axis_angle(rotq(quat, axis), q)
    {pivot + rotq(r, pos - pivot), qmul(r, quat)}
  end

  defnp integrate_pos(qpos, qvel, dt, p, opts) do
    if opts[:free] == 1 do
      j = Nx.tensor(0, type: :s32)

      {_, qpos, _, _, _} =
        while {j, qpos, qvel, dt, p}, Nx.less(j, opts[:nj]) do
          qpos = integrate_joint(j, qpos, qvel, dt, p, opts)
          {j + 1, qpos, qvel, dt, p}
        end

      qpos
    else
      Nx.indexed_add(qpos, Nx.reshape(p.joint_qadr, {:auto, 1}), dt * Nx.take(qvel, p.joint_vadr))
    end
  end

  defnp integrate_joint(j, qpos, qvel, dt, p, opts) do
    qadr = p.joint_qadr[j]
    vadr = p.joint_vadr[j]

    if opts[:free] == 1 and p.joint_type[j] == 2 do
      pos = Nx.stack([at(qpos, qadr), at(qpos, qadr + 1), at(qpos, qadr + 2)]) +
              Nx.stack([at(qvel, vadr), at(qvel, vadr + 1), at(qvel, vadr + 2)]) * dt

      quat =
        quat_integrate(
          Nx.stack([at(qpos, qadr + 3), at(qpos, qadr + 4), at(qpos, qadr + 5), at(qpos, qadr + 6)]),
          Nx.stack([at(qvel, vadr + 3), at(qvel, vadr + 4), at(qvel, vadr + 5)]),
          dt
        )

      qpos = put(qpos, qadr, pos[0])
      qpos = put(qpos, qadr + 1, pos[1])
      qpos = put(qpos, qadr + 2, pos[2])
      qpos = put(qpos, qadr + 3, quat[0])
      qpos = put(qpos, qadr + 4, quat[1])
      qpos = put(qpos, qadr + 5, quat[2])
      put(qpos, qadr + 6, quat[3])
    else
      put_add(qpos, qadr, dt * at(qvel, vadr))
    end
  end

  defnp actuator_force(ctrl, p, opts) do
    u = Nx.min(Nx.max(ctrl, p.act_lo), p.act_hi) * p.act_gear
    Nx.indexed_add(Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]}), Nx.reshape(p.act_vadr, {:auto, 1}), u)
  end

  defnp passive_force(qpos, qvel, jv, p, opts) do
    tau = passive_joints(qpos, qvel, p, opts)
    if opts[:fluid] == 1 do
      vel = Nx.dot(jv, [1], qvel, [0])
      speed = Nx.sqrt(Nx.sum(vel * vel, axes: [1]) + 1.0e-16)
      char = Nx.pow(Nx.max(p.body_mass, 1.0e-6) / 1000.0, 1.0 / 3.0)
      pi = 3.141592653589793
      stokes = vel * Nx.reshape(-6.0 * pi * p.viscosity * char, {:auto, 1})
      quad = vel * Nx.reshape(-0.5 * p.fluid_density * char * char * speed, {:auto, 1})
      tau + Nx.dot(jv, [0, 2], stokes + quad, [0, 1])
    else
      tau
    end
  end

  defnp passive_joints(qpos, qvel, p, opts) do
    q = Nx.take(qpos, p.joint_qadr) - p.joint_ref
    v = Nx.take(qvel, p.joint_vadr)
    f = Nx.select(p.joint_type == 2, 0.0, -(p.joint_damping * v + p.joint_stiffness * q))
    Nx.indexed_add(Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]}), Nx.reshape(p.joint_vadr, {:auto, 1}), f)
  end

  defnp apply_contacts(qvel, jv, jw, pos, quat, mass, rhs, p, opts) do
    n = rotq(p.floor_quat, Nx.tensor([0.0, 0.0, 1.0], type: :f64))
    off = Nx.dot(p.floor_pos, n)
    com = pos + rotq_batch(quat, p.body_com)
    bid = p.geom_body
    {pt, rad} = geom_points(pos, quat, n, off, p, opts)
    pen = rad + p.geom_margin - (Nx.dot(pt, n) - off)
    live = p.geom_contype * p.floor_aff
    active = live > 0.0 and pen > 0.0
    r = pt - Nx.take(com, bid)
    j_body = Nx.take(jv, bid) + cross_bnv(Nx.take(jw, bid), Nx.reshape(r, {opts[:ng], 1, 3}))
    jn = Nx.sum(j_body * Nx.reshape(n, {1, 1, 3}), axes: [2])
    vn = Nx.dot(jn, qvel)
    timeconst = Nx.max(p.geom_solref0, 1.0e-8)
    k = 1.0 / (timeconst * timeconst)
    b = 2.0 * p.geom_solref1 / timeconst
    fn_ = Nx.max(0.0, k * pen - b * vn)

    fi =
      if opts[:friction] == 1 do
        vel = Nx.dot(j_body, [1], qvel, [0])
        {tx, ty} = tangents(n)
        ft_cap = p.geom_friction * fn_
        use_f = p.geom_condim >= 3.0
        ftx = Nx.select(use_f, Nx.min(Nx.max(-120.0 * Nx.dot(vel, tx), -ft_cap), ft_cap), 0.0)
        fty = Nx.select(use_f, Nx.min(Nx.max(-120.0 * Nx.dot(vel, ty), -ft_cap), ft_cap), 0.0)
        force = Nx.reshape(n, {1, 3}) * Nx.reshape(fn_, {:auto, 1}) +
                  Nx.reshape(tx, {1, 3}) * Nx.reshape(ftx, {:auto, 1}) +
                  Nx.reshape(ty, {1, 3}) * Nx.reshape(fty, {:auto, 1})
        Nx.sum(j_body * Nx.reshape(force, {opts[:ng], 1, 3}), axes: [2])
      else
        jn * Nx.reshape(fn_, {:auto, 1})
      end

    active_m = Nx.broadcast(Nx.reshape(active, {:auto, 1}), {opts[:ng], opts[:nv]})
    fi = Nx.select(active_m, fi, 0.0)
    scale = Nx.select(active, p.dt * b, 0.0)
    mass = mass + Nx.dot(jn * Nx.reshape(scale, {:auto, 1}), [0], jn, [0])
    rhs = rhs + Nx.sum(fi, axes: [0])
    cf = if opts[:need_cf] == 1, do: Nx.sum(fi, axes: [0]), else: Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]})
    {mass, rhs, cf}
  end

  defnp geom_points(pos, quat, n, off, p, opts) do
    bid = p.geom_body
    pose_pos = Nx.take(pos, bid)
    pose_quat = Nx.take(quat, bid)
    h = Nx.reshape(p.geom_half, {:auto, 1})
    down = Nx.broadcast(Nx.tensor([0.0, 0.0, -1.0], type: :f64), {opts[:ng], 3}) * h
    up = Nx.broadcast(Nx.tensor([0.0, 0.0, 1.0], type: :f64), {opts[:ng], 3}) * h
    a = pose_pos + rotq_batch(pose_quat, p.geom_pos + rotq_batch(p.geom_quat, down))
    b = pose_pos + rotq_batch(pose_quat, p.geom_pos + rotq_batch(p.geom_quat, up))
    da = Nx.dot(a, n) - off
    db = Nx.dot(b, n) - off
    cap = Nx.select(Nx.broadcast(Nx.reshape(da <= db, {:auto, 1}), {opts[:ng], 3}), a, b)
    sph = pose_pos + rotq_batch(pose_quat, p.geom_pos)

    pt =
      if opts[:capsule] == 1 do
        if opts[:sphere] == 1 do
          Nx.select(Nx.broadcast(Nx.reshape(p.geom_type == 1, {:auto, 1}), {opts[:ng], 3}), cap, sph)
        else
          cap
        end
      else
        sph
      end

    {pt, p.geom_radius}
  end

  defnp apply_limits(qpos, qvel, mass, rhs, cf, p, opts) do
    j = Nx.tensor(0, type: :s32)

    {_, mass, rhs, cf, _, _, _} =
      while {j, mass, rhs, cf, qpos, qvel, p}, Nx.less(j, opts[:nl]) do
        {mass, rhs, cf} = limit_joint(j, qpos, qvel, mass, rhs, cf, p, opts)
        {j + 1, mass, rhs, cf, qpos, qvel, p}
      end

    {mass, rhs, cf}
  end

  defnp limit_joint(j, qpos, qvel, mass, rhs, cf, p, opts) do
    q = at(qpos, p.limit_qadr[j])
    v = at(qvel, p.limit_vadr[j])
    over = q > p.limit_hi[j]
    under = q < p.limit_lo[j]
    pen = if over, do: q - p.limit_hi[j], else: if(under, do: p.limit_lo[j] - q, else: 0.0)
    sign = if over, do: -1.0, else: if(under, do: 1.0, else: 0.0)
    active = pen > 0.0
    f = sign * Nx.max(0.0, 2500.0 * pen - 100.0 * v * sign)
    vadr = p.limit_vadr[j]
    rhs2 = put_add(rhs, vadr, f)
    cf2 = if opts[:need_cf] == 1, do: put_add(cf, vadr, f), else: cf
    jn = put_add(Nx.broadcast(Nx.tensor(0.0, type: :f64), {opts[:nv]}), vadr, sign)
    mass2 = mass + Nx.outer(jn, jn) * (p.dt * 100.0)
    {Nx.select(active, mass2, mass), Nx.select(active, rhs2, rhs), Nx.select(active, cf2, cf)}
  end

  defnp tangents(n) do
    ref = if Nx.abs(n[2]) < 0.9, do: Nx.tensor([0.0, 0.0, 1.0], type: :f64), else: Nx.tensor([0.0, 1.0, 0.0], type: :f64)
    t = normalize(cross(n, ref))
    {t, cross(n, t)}
  end

  defnp at(t, i), do: t[Nx.min(Nx.max(i, 0), Nx.axis_size(t, 0) - 1)]
  defnp put(t, i, v), do: Nx.indexed_put(t, Nx.reshape(Nx.min(Nx.max(i, 0), Nx.axis_size(t, 0) - 1), {1, 1}), Nx.reshape(v, {1}))
  defnp put_add(t, i, v), do: Nx.indexed_add(t, Nx.reshape(Nx.min(Nx.max(i, 0), Nx.axis_size(t, 0) - 1), {1, 1}), Nx.reshape(v, {1}))

  defnp batched_imat_vec(i_w, jw, _p, opts) do
    iw = Nx.reshape(i_w, {opts[:nb], 1, 3, 3})
    v = Nx.reshape(jw, {opts[:nb], opts[:nv], 1, 3})
    Nx.sum(iw * v, axes: [3])
  end

  defnp batched_i_vec(i_w, v, _p, _opts) do
    Nx.sum(i_w * Nx.reshape(v, {:auto, 1, 3}), axes: [2])
  end

  defnp rotate_inertia_batch(quat, inertia, _p, opts) do
    r = quat_to_mat_batch(quat)
    nb = opts[:nb]
    ri = Nx.sum(Nx.reshape(r, {nb, 3, 3, 1}) * Nx.reshape(inertia, {nb, 1, 3, 3}), axes: [2])
    rt = Nx.transpose(r, axes: [0, 2, 1])
    Nx.sum(Nx.reshape(ri, {nb, 3, 3, 1}) * Nx.reshape(rt, {nb, 1, 3, 3}), axes: [2])
  end

  defnp quat_to_mat_batch(q) do
    w = q[[0..-1//1, 0]]
    x = q[[0..-1//1, 1]]
    y = q[[0..-1//1, 2]]
    z = q[[0..-1//1, 3]]

    Nx.stack(
      [
        Nx.stack([1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)], axis: 1),
        Nx.stack([2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)], axis: 1),
        Nx.stack([2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)], axis: 1)
      ],
      axis: 1
    )
  end

  defnp cross_bnv(a, b) do
    Nx.stack(
      [
        a[[0..-1//1, 0..-1//1, 1]] * b[[0..-1//1, 0..-1//1, 2]] -
          a[[0..-1//1, 0..-1//1, 2]] * b[[0..-1//1, 0..-1//1, 1]],
        a[[0..-1//1, 0..-1//1, 2]] * b[[0..-1//1, 0..-1//1, 0]] -
          a[[0..-1//1, 0..-1//1, 0]] * b[[0..-1//1, 0..-1//1, 2]],
        a[[0..-1//1, 0..-1//1, 0]] * b[[0..-1//1, 0..-1//1, 1]] -
          a[[0..-1//1, 0..-1//1, 1]] * b[[0..-1//1, 0..-1//1, 0]]
      ],
      axis: 2
    )
  end

  defnp rotq_conj_bnv(q, v) do
    w = Nx.reshape(q[[0..-1//1, 0]], {:auto, 1})
    x = Nx.reshape(-q[[0..-1//1, 1]], {:auto, 1})
    y = Nx.reshape(-q[[0..-1//1, 2]], {:auto, 1})
    z = Nx.reshape(-q[[0..-1//1, 3]], {:auto, 1})
    vx = v[[0..-1//1, 0..-1//1, 0]]
    vy = v[[0..-1//1, 0..-1//1, 1]]
    vz = v[[0..-1//1, 0..-1//1, 2]]
    tx = 2.0 * (y * vz - z * vy)
    ty = 2.0 * (z * vx - x * vz)
    tz = 2.0 * (x * vy - y * vx)

    Nx.stack(
      [
        vx + w * tx + (y * tz - z * ty),
        vy + w * ty + (z * tx - x * tz),
        vz + w * tz + (x * ty - y * tx)
      ],
      axis: 2
    )
  end

  defnp qconj_batch(q) do
    Nx.stack([q[[0..-1//1, 0]], -q[[0..-1//1, 1]], -q[[0..-1//1, 2]], -q[[0..-1//1, 3]]], axis: 1)
  end

  defnp rotq_batch(q, v) do
    w = q[[0..-1//1, 0]]
    x = q[[0..-1//1, 1]]
    y = q[[0..-1//1, 2]]
    z = q[[0..-1//1, 3]]
    vx = v[[0..-1//1, 0]]
    vy = v[[0..-1//1, 1]]
    vz = v[[0..-1//1, 2]]
    tx = 2.0 * (y * vz - z * vy)
    ty = 2.0 * (z * vx - x * vz)
    tz = 2.0 * (x * vy - y * vx)

    Nx.stack(
      [
        vx + w * tx + (y * tz - z * ty),
        vy + w * ty + (z * tx - x * tz),
        vz + w * tz + (x * ty - y * tx)
      ],
      axis: 1
    )
  end

  defnp qmul_batch(a, b) do
    w1 = a[[0..-1//1, 0]]
    x1 = a[[0..-1//1, 1]]
    y1 = a[[0..-1//1, 2]]
    z1 = a[[0..-1//1, 3]]
    w2 = b[[0..-1//1, 0]]
    x2 = b[[0..-1//1, 1]]
    y2 = b[[0..-1//1, 2]]
    z2 = b[[0..-1//1, 3]]

    Nx.stack(
      [
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2
      ],
      axis: 1
    )
  end

  defnp cross_batch(a, b) do
    Nx.stack(
      [
        a[[0..-1//1, 1]] * b[[0..-1//1, 2]] - a[[0..-1//1, 2]] * b[[0..-1//1, 1]],
        a[[0..-1//1, 2]] * b[[0..-1//1, 0]] - a[[0..-1//1, 0]] * b[[0..-1//1, 2]],
        a[[0..-1//1, 0]] * b[[0..-1//1, 1]] - a[[0..-1//1, 1]] * b[[0..-1//1, 0]]
      ],
      axis: 1
    )
  end

  defnp rotq(q, v) do
    w = q[0]
    x = q[1]
    y = q[2]
    z = q[3]
    tx = 2.0 * (y * v[2] - z * v[1])
    ty = 2.0 * (z * v[0] - x * v[2])
    tz = 2.0 * (x * v[1] - y * v[0])

    Nx.stack([
      v[0] + w * tx + (y * tz - z * ty),
      v[1] + w * ty + (z * tx - x * tz),
      v[2] + w * tz + (x * ty - y * tx)
    ])
  end

  defnp qmul(a, b) do
    Nx.stack([
      a[0] * b[0] - a[1] * b[1] - a[2] * b[2] - a[3] * b[3],
      a[0] * b[1] + a[1] * b[0] + a[2] * b[3] - a[3] * b[2],
      a[0] * b[2] - a[1] * b[3] + a[2] * b[0] + a[3] * b[1],
      a[0] * b[3] + a[1] * b[2] - a[2] * b[1] + a[3] * b[0]
    ])
  end

  defnp axis_angle(axis, ang) do
    n = normalize(axis)
    s = Nx.sin(ang / 2.0)
    Nx.stack([Nx.cos(ang / 2.0), n[0] * s, n[1] * s, n[2] * s])
  end

  defnp quat_integrate(q, w, dt) do
    ang = norm3(w) * dt

    if ang < 1.0e-12 do
      q
    else
      qmul(q, axis_angle(w / Nx.max(norm3(w), 1.0e-12), ang))
    end
  end

  defnp cross(a, b) do
    Nx.stack([a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]])
  end

  defnp normalize(v), do: v / Nx.max(norm3(v), 1.0e-12)
  defnp norm3(v), do: Nx.sqrt(Nx.dot(v, v))

  defp tensor_pack(p), do: Map.drop(p, [:nq, :nv, :nb, :nj, :ng, :nu, :jpb, :ns, :nl])

  defp size_opts(p, model) do
    visc = (model[:viscosity] || 0) + (model[:fluid_density] || 0)
    free? = Enum.any?(model[:joints] || [], &(&1.type == :free))

    [
      nq: p.nq,
      nv: p.nv,
      nb: p.nb,
      nj: p.nj,
      ng: p.ng,
      nu: p.nu,
      jpb: p.jpb,
      ns: p.ns,
      nl: p.nl,
      fluid: if(visc > 0, do: 1, else: 0),
      free: if(free?, do: 1, else: 0),
      contact: if(has_floor_contacts?(model), do: 1, else: 0),
      friction: if(has_friction?(model), do: 1, else: 0),
      limit: if(has_limits?(model), do: 1, else: 0),
      slide: if(Enum.any?(model[:joints] || [], &(&1.type == :slide)), do: 1, else: 0),
      capsule: if(Enum.any?(model[:geoms] || [], &capsule?/1), do: 1, else: 0),
      sphere: if(Enum.any?(model[:geoms] || [], &sphere?/1), do: 1, else: 0),
      need_cf: if((model[:sites] || []) != [], do: 1, else: 0)
    ]
  end

  defp free_qadr(joints) do
    case Enum.find(joints, &(&1.type == :free)) do
      %{qadr: q} -> q
      _ -> 0
    end
  end

  defp free_vadr(joints) do
    case Enum.find(joints, &(&1.type == :free)) do
      %{vadr: v} -> v
      _ -> 0
    end
  end

  defp has_floor_contacts?(model) do
    floor = Enum.find(model[:world_geoms] || [], &(&1.type == "plane"))
    aff = if(floor, do: Map.get(floor, :conaffinity, 0), else: 0)
    aff > 0 and Enum.any?(model[:geoms] || [], &(Map.get(&1, :contype, 0) > 0))
  end

  defp has_friction?(model) do
    Enum.any?(model[:geoms] || [], &(Map.get(&1, :condim, 3) >= 3))
  end

  defp has_limits?(model) do
    Enum.any?(model[:joints] || [], &(&1[:limited] && &1[:range] && &1[:type] != :free))
  end

  defp capsule?(%{type: t}) when t in ["capsule", "cylinder"], do: true
  defp capsule?(_), do: false
  defp sphere?(%{type: t}) when t in ["capsule", "cylinder"], do: false
  defp sphere?(_), do: true

  defp pad_limited(joints) do
    case Enum.filter(joints, &(&1.limited && &1.range && &1.type != :free)) do
      [] -> [%{qadr: 0, vadr: 0, range: {0.0, 0.0}}]
      js -> js
    end
  end

  defp from_state(qpos, qvel, nq, nv) do
    qp = floats_tuple(qpos, nq)
    qv = floats_tuple(qvel, nv)
    {qp, qv}
  end

  defp floats_tuple(t, n) do
    bin = t |> Nx.backend_copy(Nx.BinaryBackend) |> Nx.to_binary()
    parse_f64(bin, n, [])
  end

  defp parse_f64(_bin, 0, acc), do: acc |> Enum.reverse() |> List.to_tuple()

  defp parse_f64(<<x::float-native-64, rest::binary>>, n, acc) do
    parse_f64(rest, n - 1, [x | acc])
  end

  defp to1(t, n) when is_tuple(t), do: t |> Tuple.to_list() |> to1(n)
  defp to1(l, n) when is_list(l), do: Nx.tensor(Enum.take(l ++ List.duplicate(0.0, n), n), type: :f64)
  defp to1(%Nx.Tensor{} = t, _), do: Nx.as_type(t, :f64)

  defp from1(t, n) do
    t
    |> Nx.backend_copy(Nx.BinaryBackend)
    |> Nx.to_flat_list()
    |> Enum.take(n)
    |> List.to_tuple()
  end

  defp from3(_t, 0), do: []

  defp from3(t, n) do
    t
    |> Nx.backend_copy(Nx.BinaryBackend)
    |> Nx.to_list()
    |> Enum.take(n)
    |> Enum.map(&List.to_tuple/1)
  end

  defp f(x), do: Nx.tensor(x * 1.0, type: :f64)
  defp vec3({x, y, z}), do: Nx.tensor([x, y, z], type: :f64)
  defp vec4({w, x, y, z}), do: Nx.tensor([w, x, y, z], type: :f64)
  defp floats(xs), do: Nx.tensor(Enum.map(xs, &(&1 * 1.0)), type: :f64)
  defp ints(xs), do: Nx.tensor(xs, type: :s32)
  defp stack3(xs), do: Nx.tensor(Enum.map(xs, fn {x, y, z} -> [x, y, z] end), type: :f64)
  defp stack4(xs), do: Nx.tensor(Enum.map(xs, fn {w, x, y, z} -> [w, x, y, z] end), type: :f64)

  defp inertia_tensor(xs) do
    Nx.tensor(
      Enum.map(xs, fn {{a, b, c}, {d, e, f}, {g, h, i}} -> [[a, b, c], [d, e, f], [g, h, i]] end),
      type: :f64
    )
  end

  defp joint_code(:hinge), do: 0
  defp joint_code(:slide), do: 1
  defp joint_code(:free), do: 2
  defp joint_code(_), do: 0
  defp geom_code(t) when t in ["capsule", "cylinder"], do: 1
  defp geom_code(_), do: 0
  defp geom_half(%{size: [_, h | _]}), do: h
  defp geom_half(%{size: [r | _]}), do: r
  defp geom_half(_), do: 0.05
  defp joint_lo(%{range: {lo, _}}), do: lo
  defp joint_lo(_), do: 0.0
  defp joint_hi(%{range: {_, hi}}), do: hi
  defp joint_hi(_), do: 0.0
  defp pad_joints([]), do: [dummy_joint()]
  defp pad_joints(js), do: js

  defp dummy_joint do
    %{
      type: :hinge,
      body: 0,
      qadr: 0,
      vadr: 0,
      axis: {0.0, 0.0, 1.0},
      pos: {0.0, 0.0, 0.0},
      ref: 0.0,
      armature: 0.0,
      damping: 0.0,
      stiffness: 0.0,
      limited: false,
      range: nil
    }
  end

  defp pad_geoms([]), do: [dummy_geom()]
  defp pad_geoms(gs), do: gs

  defp dummy_geom do
    %{
      body: 0,
      type: "sphere",
      pos: {0.0, 0.0, 0.0},
      quat: {1.0, 0.0, 0.0, 0.0},
      size: [0.01],
      contype: 0,
      margin: 0.0,
      solref: [0.02, 1.0],
      friction: [1.0],
      condim: 1
    }
  end

  defp pad_acts([]), do: [%{vadr: 0, gear: 0.0, ctrlrange: {-1.0, 1.0}}]
  defp pad_acts(as), do: as

  defp pad_sites([]), do: [%{body: 0, pos: {0.0, 0.0, 0.0}}]
  defp pad_sites(ss), do: ss

  defp pack_body_joints(bodies, joints) do
    nb = length(bodies)
    indexed = Enum.with_index(joints)

    by_body =
      Enum.group_by(indexed, fn {j, _} -> j.body end, fn {_, i} -> i end)

    jpb =
      by_body
      |> Map.values()
      |> Enum.map(&length/1)
      |> Enum.max(fn -> 1 end)
      |> max(1)

    table =
      Enum.map(0..(nb - 1), fn b ->
        js = Map.get(by_body, b, [])
        js ++ List.duplicate(-1, jpb - length(js))
      end)

    {jpb, Nx.tensor(table, type: :s32)}
  end

  defp pack_dofs(joints, nv) do
    recs =
      Enum.flat_map(joints, fn
        %{type: :free, body: b, qadr: q} ->
          Enum.map(0..2, &{2, q + &1, &1, b, unit(&1), {0.0, 0.0, 0.0}}) ++
            Enum.map(0..2, &{3, q + 3, &1, b, unit(&1), {0.0, 0.0, 0.0}})

        %{type: :slide, body: b, qadr: q, axis: ax, pos: pos} ->
          [{1, q, 0, b, ax, pos}]

        %{body: b, qadr: q, axis: ax, pos: pos} ->
          [{0, q, 0, b, ax, pos}]
      end)

    pad = {0, 0, 0, 0, {0.0, 0.0, 1.0}, {0.0, 0.0, 0.0}}
    recs = Enum.take(recs ++ List.duplicate(pad, nv), nv)

    {
      Enum.map(recs, &elem(&1, 0)),
      Enum.map(recs, &elem(&1, 1)),
      Enum.map(recs, &elem(&1, 2)),
      Enum.map(recs, &elem(&1, 3)),
      Enum.map(recs, &elem(&1, 4)),
      Enum.map(recs, &elem(&1, 5))
    }
  end

  defp unit(0), do: {1.0, 0.0, 0.0}
  defp unit(1), do: {0.0, 1.0, 0.0}
  defp unit(2), do: {0.0, 0.0, 1.0}

  defp affect_mask(bodies, dof_body, _nv) do
    parents = Enum.map(bodies, & &1.parent)

    sets =
      Enum.map(0..(length(bodies) - 1), fn b ->
        MapSet.new(
          Stream.unfold(b, fn
            nil -> nil
            i -> {i, if(i == 0, do: nil, else: Enum.at(parents, i))}
          end)
        )
      end)

    Nx.tensor(
      Enum.map(sets, fn set ->
        Enum.map(dof_body, fn bid -> if(MapSet.member?(set, bid), do: 1.0, else: 0.0) end)
      end),
      type: :f64
    )
  end

  defp armature_dof(joints, nv) do
    Enum.reduce(joints, List.duplicate(0.0, nv), fn
      %{type: :free, vadr: v, armature: a}, acc ->
        Enum.reduce(0..5, acc, fn k, acc -> List.update_at(acc, v + k, &(&1 + (a || 0.0))) end)

      %{vadr: v, armature: a}, acc ->
        List.update_at(acc, v, &(&1 + (a || 0.0)))
    end)
  end
end
