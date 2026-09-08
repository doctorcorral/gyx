defmodule GyxUI.Layouts do
  @moduledoc false
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
        <title>gyx · Playground</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@300;400;500;600;700&family=Oswald:wght@400;500;600&display=swap"
          rel="stylesheet"
        />
        <script>
          (function () {
            try {
              var stored = localStorage.getItem("gyx-theme")
              document.documentElement.dataset.theme = stored || "dark"
            } catch (_) {
              document.documentElement.dataset.theme = "dark"
            }
          })()
        </script>
        <style>
          :root, [data-theme="dark"] {
            --bg: #121212;
            --bg-accent: #1a1919;
            --ink: #f5f5f5;
            --muted: #a39ca8;
            --line: #2e2a31;
            --panel: #1a1919;
            --panel-2: #221f26;
            --accent: #b089c4;
            --accent-deep: #7a5a91;
            --accent-soft: rgba(151, 119, 168, 0.2);
            --accent-2: #d4c0e8;
            --danger: #e06c75;
            --ok: #7dcea0;
            --warn: #e8c07a;
            --shadow: 0 1px 2px rgba(0, 0, 0, 0.4), 0 22px 48px rgba(0, 0, 0, 0.32);
            --stage: #101010;
            --grid-a: #3a3540;
            --grid-b: #2a2630;
            --raw: #6e6874;
            --topbar: rgba(18, 18, 18, 0.88);
            --pattern: rgba(176, 137, 196, 0.16);
            color-scheme: dark;
          }
          [data-theme="light"] {
            --bg: #f4f1f6;
            --bg-accent: #ebe6f0;
            --ink: #1a1919;
            --muted: #6d6574;
            --line: #ddd6e3;
            --panel: #ffffff;
            --panel-2: #f7f4fa;
            --accent: #7a5a91;
            --accent-deep: #5a4070;
            --accent-soft: rgba(122, 90, 145, 0.12);
            --accent-2: #9777a8;
            --danger: #c2413b;
            --ok: #2f8f62;
            --warn: #b8860b;
            --shadow: 0 1px 2px rgba(26, 25, 25, 0.05), 0 18px 40px rgba(26, 25, 25, 0.06);
            --stage: #faf8fc;
            --grid-a: #d8d2de;
            --grid-b: #ebe6f0;
            --raw: #a39ca8;
            --topbar: rgba(255, 255, 255, 0.86);
            --pattern: rgba(122, 90, 145, 0.1);
            color-scheme: light;
          }
          * { box-sizing: border-box; }
          html, body { margin: 0; background: var(--bg); color: var(--ink); font-family: "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif; }
          body {
            min-height: 100vh;
            background-color: var(--bg);
            background-image:
              url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='56' height='32' viewBox='0 0 56 32'%3E%3Cpath d='M28 2 L54 16 L28 30 L2 16 Z' fill='none' stroke='%239777a8' stroke-width='0.7'/%3E%3C/svg%3E"),
              radial-gradient(900px 420px at 100% -8%, color-mix(in srgb, var(--accent) 18%, transparent), transparent 56%);
            background-size: 56px 32px, auto;
          }
          button, select, input {
            font: inherit;
            color: var(--ink);
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 4px;
          }
          button { padding: 0.48rem 0.8rem; cursor: pointer; }
          button:hover:not(:disabled) { border-color: var(--accent); }
          button:focus-visible, select:focus-visible, input:focus-visible {
            outline: 2px solid var(--accent);
            outline-offset: 2px;
          }
          button:disabled { opacity: 0.42; cursor: default; }
          .btn { display: inline-flex; align-items: center; justify-content: center; gap: 0.4rem; font-weight: 500; letter-spacing: -0.01em; }
          .btn.primary { background: var(--accent-deep); color: #fff; border-color: var(--accent-deep); }
          .btn.active { background: var(--accent-soft); border-color: var(--accent); color: var(--accent); }
          .icon-btn {
            width: 38px; height: 38px; padding: 0; display: grid; place-items: center;
            background: var(--panel); border-radius: 4px;
          }
          .icon-btn svg { width: 18px; height: 18px; fill: none; stroke: currentColor; stroke-width: 1.8; }
          [data-theme="light"] .icon-sun { display: none; }
          [data-theme="dark"] .icon-moon { display: none; }
          .app { max-width: 1280px; margin: 0 auto; padding: 0 1.1rem 2.5rem; }
          .topbar {
            position: sticky; top: 0; z-index: 20;
            display: flex; align-items: center; gap: 1rem; flex-wrap: wrap;
            padding: 0.85rem 0 0.75rem;
            background: var(--topbar);
            backdrop-filter: blur(16px);
            border-bottom: 1px solid var(--line);
            margin: 0 -1.1rem 1.1rem;
            padding-left: 1.1rem; padding-right: 1.1rem;
          }
          .brand { display: flex; align-items: center; gap: 0.75rem; min-width: 12rem; }
          .logo {
            display: block;
            height: 58px;
            width: auto;
            background: transparent;
            border: 0;
          }
          [data-theme="light"] .logo {
            filter: invert(1) hue-rotate(180deg);
          }
          .brand-copy { display: flex; flex-direction: column; gap: 0.08rem; }
          .product {
            font-family: Oswald, "IBM Plex Sans", sans-serif;
            font-weight: 500;
            font-size: 1.05rem;
            letter-spacing: 0.08em;
            text-transform: uppercase;
            line-height: 1;
          }
          .tag {
            font-family: "IBM Plex Mono", ui-monospace, monospace;
            font-size: 0.68rem;
            color: var(--muted);
            letter-spacing: 0.01em;
          }
          .pickers { display: flex; gap: 0.65rem; flex: 1; flex-wrap: wrap; }
          .field { display: flex; flex-direction: column; gap: 0.22rem; min-width: 12rem; }
          .field span {
            font-family: Oswald, "IBM Plex Sans", sans-serif;
            font-size: 0.72rem;
            font-weight: 500;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--muted);
          }
          .field select { min-height: 38px; padding: 0.35rem 0.6rem; }
          .top-actions { margin-left: auto; }
          .workspace { display: grid; grid-template-columns: minmax(0, 1.7fr) minmax(300px, 0.9fr); gap: 1rem; align-items: start; }
          @media (max-width: 920px) { .workspace { grid-template-columns: 1fr; } }
          .viewport {
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 6px;
            box-shadow: var(--shadow);
            overflow: hidden;
            min-height: 420px;
            display: flex;
            flex-direction: column;
          }
          .viewport-chrome {
            display: flex; justify-content: space-between; gap: 0.5rem; flex-wrap: wrap;
            padding: 0.7rem 0.85rem;
            border-bottom: 1px solid var(--line);
            background: var(--panel-2);
          }
          .chips { display: flex; gap: 0.4rem; flex-wrap: wrap; }
          .chip {
            font-family: "IBM Plex Mono", ui-monospace, monospace;
            font-size: 0.72rem;
            padding: 0.18rem 0.5rem;
            border-radius: 999px;
            background: var(--panel);
            border: 1px solid var(--line);
            color: var(--muted);
          }
          .chip.ok { color: var(--ok); border-color: color-mix(in srgb, var(--ok) 40%, var(--line)); }
          .chip.danger { color: var(--danger); border-color: color-mix(in srgb, var(--danger) 40%, var(--line)); }
          .chip.warn { color: var(--warn); border-color: color-mix(in srgb, var(--warn) 40%, var(--line)); }
          .chip.policy { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 40%, var(--line)); }
          .chip.backend-native { color: var(--ok); border-color: color-mix(in srgb, var(--ok) 45%, var(--line)); }
          .chip.backend-tree { color: var(--warn); border-color: color-mix(in srgb, var(--warn) 45%, var(--line)); }
          .chip.backend-gymnasium { color: var(--accent); border-color: color-mix(in srgb, var(--accent) 45%, var(--line)); }
          .chip.backend-atari { color: #e89b6c; border-color: color-mix(in srgb, #e89b6c 45%, var(--line)); }
          .chip.backend-classic { color: var(--muted); }
          .backend-card .backend-title {
            margin: 0 0 0.35rem;
            font-family: Oswald, "IBM Plex Sans", sans-serif;
            font-size: 1.05rem;
            font-weight: 500;
            letter-spacing: 0.04em;
            text-transform: uppercase;
          }
          .backend-card p {
            margin: 0 0 0.7rem;
            color: var(--muted);
            font-size: 0.86rem;
            line-height: 1.45;
          }
          .backend-meta { display: grid; gap: 0.4rem; margin: 0 0 0.75rem; }
          .backend-meta div {
            display: grid;
            grid-template-columns: 6.2rem 1fr;
            gap: 0.45rem;
            font-family: "IBM Plex Mono", ui-monospace, monospace;
            font-size: 0.75rem;
          }
          .backend-meta dt, .backend-meta .k { color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em; }
          .backend-meta .v { color: var(--ink); overflow-wrap: anywhere; }
          .backend-switch { display: flex; flex-wrap: wrap; gap: 0.4rem; }
          .backend-switch .btn { flex: 1 1 auto; min-width: 6.5rem; font-size: 0.82rem; }
          .stage { background: var(--stage); min-height: 320px; padding: 0.8rem; flex: 1; }
          .stage svg { width: 100%; height: auto; display: block; }
          .stage-2d svg > rect:first-child { fill: transparent; }
          [data-theme="dark"] .stage-2d svg { filter: invert(0.9) hue-rotate(180deg); }
          .stage-atari {
            background: #000;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 1.1rem;
          }
          .stage-atari svg {
            width: auto;
            height: min(420px, 70vw);
            max-width: 100%;
            image-rendering: pixelated;
            image-rendering: crisp-edges;
          }
          [data-theme="dark"] .stage-atari svg,
          [data-theme="light"] .stage-atari svg { filter: none; }
          .stage-3d { padding: 0; min-height: 460px; height: 460px; position: relative; }
          .stage-3d canvas { width: 100%; height: 100%; display: block; }
          .atari-controls {
            display: flex;
            flex-wrap: wrap;
            align-items: center;
            gap: 0.75rem;
            margin-top: 0.65rem;
          }
          .viewport-hint {
            margin: 0;
            padding: 0.45rem 0.85rem 0.65rem;
            color: var(--muted);
            font-size: 0.78rem;
            font-family: "IBM Plex Mono", ui-monospace, monospace;
          }
          .rail { display: flex; flex-direction: column; gap: 0.8rem; }
          .card {
            background: var(--panel);
            border: 1px solid var(--line);
            border-radius: 6px;
            box-shadow: var(--shadow);
            padding: 0.85rem 0.95rem;
          }
          .card h2 {
            margin: 0 0 0.65rem;
            font-family: Oswald, "IBM Plex Sans", sans-serif;
            font-size: 0.78rem;
            font-weight: 500;
            letter-spacing: 0.1em;
            text-transform: uppercase;
            color: var(--muted);
          }
          .controls { display: flex; flex-wrap: wrap; gap: 0.45rem; }
          .dpad {
            display: grid;
            grid-template-areas: ". up ." "left . right" ". down .";
            gap: 0.25rem;
          }
          .dpad .up { grid-area: up; }
          .dpad .left { grid-area: left; }
          .dpad .right { grid-area: right; }
          .dpad .down { grid-area: down; }
          .dpad button { min-width: 4.1rem; }
          .params form, .sliders { display: grid; grid-template-columns: 1fr; gap: 0.45rem; }
          .param, .slider {
            background: var(--panel-2);
            border: 1px solid var(--line);
            border-radius: 10px;
            padding: 0.5rem 0.7rem;
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 0.7rem;
          }
          .slider { flex-direction: column; align-items: stretch; gap: 0.28rem; }
          .param .key, .slider span { font-family: "IBM Plex Mono", ui-monospace, monospace; font-size: 0.8rem; color: var(--muted); }
          .slider .val { float: right; color: var(--ink); }
          .slider input { width: 100%; accent-color: var(--accent); }
          .stats { display: grid; grid-template-columns: 1fr 1fr; gap: 0.45rem; }
          .stat { background: var(--panel-2); border: 1px solid var(--line); border-radius: 10px; padding: 0.55rem 0.65rem; min-width: 0; }
          .stat span { display: block; color: var(--muted); font-size: 0.7rem; letter-spacing: 0.04em; text-transform: uppercase; font-weight: 600; }
          .stat strong {
            display: block;
            margin-top: 0.15rem;
            font-size: 0.92rem;
            font-family: "IBM Plex Mono", ui-monospace, monospace;
            font-weight: 500;
            overflow-wrap: anywhere;
          }
          .stat.wide { grid-column: 1 / -1; }
          .message {
            margin: 0;
            font-family: "IBM Plex Mono", ui-monospace, monospace;
            font-size: 0.82rem;
            color: var(--muted);
            line-height: 1.45;
          }
          .done { color: var(--danger); font-weight: 600; }
          .learn-head { display: flex; justify-content: space-between; gap: 0.6rem; flex-wrap: wrap; margin-bottom: 0.5rem; }
          .learn-head span { font-family: "IBM Plex Mono", ui-monospace, monospace; font-size: 0.78rem; color: var(--muted); }
          .meter { height: 8px; background: var(--panel-2); border: 1px solid var(--line); border-radius: 999px; overflow: hidden; }
          .meter-fill { height: 100%; width: 0; background: linear-gradient(90deg, var(--accent), var(--accent-2)); border-radius: inherit; transition: width 140ms linear; }
          .curve { margin-top: 0.7rem; }
          .curve svg { width: 100%; height: auto; display: block; }
          .learn-legend { display: flex; gap: 1rem; margin-top: 0.4rem; font-family: "IBM Plex Mono", ui-monospace, monospace; font-size: 0.72rem; color: var(--muted); }
          .learn-legend i { display: inline-block; width: 0.85rem; height: 2px; margin-right: 0.35rem; vertical-align: middle; }
          .learn-legend .raw { background: var(--raw); }
          .learn-legend .avg { background: var(--accent); height: 3px; }
          .kbd {
            margin-top: 0.15rem;
            color: var(--muted);
            font-size: 0.72rem;
            font-family: "IBM Plex Mono", ui-monospace, monospace;
          }
          kbd {
            font: inherit;
            border: 1px solid var(--line);
            border-bottom-width: 2px;
            border-radius: 5px;
            padding: 0.05rem 0.32rem;
            background: var(--panel-2);
          }
        </style>
        <script defer src="/phoenix/phoenix.js"></script>
        <script defer src="/live_view/phoenix_live_view.js"></script>
        <script>
          const Hooks = {}

          Hooks.Theme = {
            mounted() {
              this.sync()
              this.el.addEventListener("click", () => {
                const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
                document.documentElement.dataset.theme = next
                try { localStorage.setItem("gyx-theme", next) } catch (_) {}
                window.dispatchEvent(new CustomEvent("gyx-theme", { detail: next }))
                this.sync()
              })
            },
            sync() {
              const dark = document.documentElement.dataset.theme === "dark"
              this.el.setAttribute("aria-pressed", dark ? "true" : "false")
              this.el.setAttribute("aria-label", dark ? "Switch to light mode" : "Switch to dark mode")
            }
          }

          Hooks.Shortcuts = {
            mounted() {
              this.onKey = (e) => {
                if (e.target.closest("input, select, textarea")) return
                if (e.key === "r" || e.key === "R") { e.preventDefault(); this.pushEvent("reset", {}) }
                if (e.key === " ") { e.preventDefault(); this.pushEvent("toggle", {}) }
                if (e.key === "n" || e.key === "N") { e.preventDefault(); this.pushEvent("random", {}) }
              }
              window.addEventListener("keydown", this.onKey)
            },
            destroyed() { window.removeEventListener("keydown", this.onKey) }
          }

          Hooks.Scene3D = {
            async mounted() {
              this.THREE = await import("https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.module.js")
              this.azimuth = null
              this.elevation = null
              this.dragging = false
              this.setup()
              this.draw()
              this.onTheme = () => this.applyTheme()
              window.addEventListener("gyx-theme", this.onTheme)
            },
            updated() { if (this.scene) this.draw() },
            destroyed() {
              window.removeEventListener("resize", this.onResize)
              window.removeEventListener("gyx-theme", this.onTheme)
              this.clearGround()
              this.clearWater()
              for (const id of Array.from(this.ghosts ? this.ghosts.keys() : [])) this.dropGhost(id)
              if (this.renderer) this.renderer.dispose()
            },
            setup() {
              const THREE = this.THREE
              const canvas = this.el.querySelector("canvas")
              this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true })
              this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
              this.renderer.shadowMap.enabled = true
              this.renderer.shadowMap.type = THREE.PCFSoftShadowMap
              this.camera = new THREE.PerspectiveCamera(45, 1, 0.05, 80)
              this.scene = new THREE.Scene()
              this.hemi = new THREE.HemisphereLight(0xfff7ed, 0x44403c, 0.95)
              this.scene.add(this.hemi)
              this.sun = new THREE.DirectionalLight(0xffffff, 0.85)
              this.sun.position.set(4, 8, 2)
              this.sun.castShadow = true
              this.sun.shadow.mapSize.set(1024, 1024)
              this.sun.shadow.camera.near = 0.4
              this.sun.shadow.camera.far = 28
              this.sun.shadow.camera.left = -8
              this.sun.shadow.camera.right = 8
              this.sun.shadow.camera.top = 8
              this.sun.shadow.camera.bottom = -8
              this.scene.add(this.sun)
              this.meshes = new Map()
              this.ghosts = new Map()
              this.ground = null
              this.water = null
              this.resize()
              this.applyTheme()
              this.onResize = () => this.resize()
              window.addEventListener("resize", this.onResize)
              canvas.addEventListener("pointerdown", (e) => {
                this.dragging = true
                this.lastX = e.clientX
                this.lastY = e.clientY
                canvas.setPointerCapture(e.pointerId)
              })
              canvas.addEventListener("pointerup", () => { this.dragging = false })
              canvas.addEventListener("pointermove", (e) => {
                if (!this.dragging) return
                this.azimuth = (this.azimuth ?? 135) + (e.clientX - this.lastX) * 0.4
                this.elevation = Math.max(-80, Math.min(80, (this.elevation ?? -18) + (e.clientY - this.lastY) * 0.25))
                this.lastX = e.clientX
                this.lastY = e.clientY
                this.placeCamera()
                this.renderer.render(this.scene, this.camera)
              })
            },
            cssColor(name, fallback) {
              const raw = getComputedStyle(document.documentElement).getPropertyValue(name).trim()
              return raw || fallback
            },
            applyTheme() {
              if (!this.renderer) return
              const THREE = this.THREE
              const dark = document.documentElement.dataset.theme === "dark"
              this.renderer.setClearColor(new THREE.Color(this.cssColor("--stage", dark ? "#101010" : "#faf8fc")), 1)
              this.hemi.color.set(dark ? 0xd4c0e8 : 0xf7f4fa)
              this.hemi.groundColor.set(dark ? 0x2a2430 : 0x8a8490)
              this.clearGround()
              this.clearWater()
              this.draw()
            },
            resize() {
              if (!this.renderer) return
              const w = this.el.clientWidth || 640
              const h = this.el.clientHeight || 420
              this.renderer.setSize(w, h, false)
              this.camera.aspect = w / Math.max(h, 1)
              this.camera.updateProjectionMatrix()
              this.renderer.render(this.scene, this.camera)
            },
            draw() {
              const THREE = this.THREE
              const data = JSON.parse(this.el.dataset.scene || "{}")
              const bodies = data.bodies || []
              const ids = new Set()
              bodies.forEach((body, i) => {
                const id = body.id || (body.geom + "-" + i)
                ids.add(id)
                let mesh = this.meshes.get(id)
                if (!mesh || mesh.userData.kind !== body.geom) {
                  if (mesh) this.scene.remove(mesh)
                  mesh = this.makeMesh(body)
                  this.meshes.set(id, mesh)
                  this.scene.add(mesh)
                }
                this.placeMesh(mesh, body)
              })
              for (const [id, mesh] of this.meshes) {
                if (!ids.has(id)) {
                  this.scene.remove(mesh)
                  this.meshes.delete(id)
                  this.dropGhost(id)
                }
              }
              if (data.ground && !this.ground) this.buildGround()
              if (!data.ground && this.ground) this.clearGround()
              if (data.water && !this.water) this.buildWater()
              if (!data.water && this.water) this.clearWater()
              const reflect = !!(this.ground || this.water)
              bodies.forEach((body, i) => {
                const id = body.id || (body.geom + "-" + i)
                if (reflect) this.mirrorMesh(id, this.meshes.get(id))
                else this.dropGhost(id)
              })
              this.track = data.camera && data.camera.track ? data.camera.track : [0, 0, 0]
              this.distance = (data.camera && data.camera.distance) || 3.6
              if (this.azimuth == null) this.azimuth = (data.camera && data.camera.azimuth) || 135
              if (this.elevation == null) this.elevation = (data.camera && data.camera.elevation) || -18
              this.placeCamera()
              this.renderer.render(this.scene, this.camera)
            },
            toThree(p) { return [p[0], p[2], -(p[1] || 0)] },
            makeMesh(body) {
              const THREE = this.THREE
              const color = new THREE.Color(body.color || "#9777a8")
              const mat = new THREE.MeshPhongMaterial({ color, shininess: 40 })
              let geom
              if (body.geom === "sphere") geom = new THREE.SphereGeometry(body.radius || 0.05, 18, 12)
              else if (body.geom === "box") {
                const s = body.size || [0.1, 0.1, 0.1]
                geom = new THREE.BoxGeometry(s[0] * 2, s[2] * 2, s[1] * 2)
              } else {
                const r = body.radius || 0.04
                geom = new THREE.CapsuleGeometry(r, 0.01, 4, 10)
              }
              const mesh = new THREE.Mesh(geom, mat)
              mesh.userData.kind = body.geom
              mesh.castShadow = true
              mesh.receiveShadow = true
              return mesh
            },
            darkTheme() { return document.documentElement.dataset.theme === "dark" },
            mirrorMesh(id, mesh) {
              if (!mesh) return
              const THREE = this.THREE
              let ghost = this.ghosts.get(id)
              if (!ghost) {
                ghost = new THREE.Mesh(mesh.geometry, mesh.material.clone())
                ghost.material.transparent = true
                ghost.material.opacity = 0.32
                ghost.material.color.multiplyScalar(0.55)
                ghost.castShadow = false
                ghost.receiveShadow = false
                ghost.matrixAutoUpdate = false
                this.ghosts.set(id, ghost)
                this.scene.add(ghost)
              }
              ghost.geometry = mesh.geometry
              mesh.updateMatrix()
              ghost.matrix.makeScale(1, -1, 1).multiply(mesh.matrix)
            },
            dropGhost(id) {
              const ghost = this.ghosts.get(id)
              if (!ghost) return
              this.scene.remove(ghost)
              if (ghost.material) ghost.material.dispose()
              this.ghosts.delete(id)
            },
            buildGround() {
              const THREE = this.THREE
              const dark = this.darkTheme()
              const size = 28
              const group = new THREE.Group()
              const polish = new THREE.Mesh(
                new THREE.PlaneGeometry(size, size),
                new THREE.MeshPhongMaterial({
                  color: dark ? 0x2a2433 : 0xe8e0f0,
                  transparent: true,
                  opacity: dark ? 0.48 : 0.52,
                  shininess: 110,
                  specular: dark ? 0xc4a6d8 : 0x9777a8,
                  side: THREE.DoubleSide
                })
              )
              polish.rotation.x = -Math.PI / 2
              polish.position.y = 0.0
              polish.receiveShadow = true
              group.add(polish)
              const grid = new THREE.GridHelper(size, 28, dark ? 0x8a739c : 0xb9a8cc, dark ? 0x3d3644 : 0xd8d0e4)
              grid.position.y = 0.006
              const mats = Array.isArray(grid.material) ? grid.material : [grid.material]
              mats.forEach((m) => { m.transparent = true; m.opacity = dark ? 0.42 : 0.5 })
              group.add(grid)
              this.ground = group
              this.scene.add(group)
            },
            clearGround() {
              if (!this.ground) return
              this.scene.remove(this.ground)
              this.ground.traverse((obj) => {
                if (obj.geometry) obj.geometry.dispose()
                if (obj.getRenderTarget) obj.getRenderTarget().dispose()
                if (obj.material) {
                  const mats = Array.isArray(obj.material) ? obj.material : [obj.material]
                  mats.forEach((m) => m && m.dispose && m.dispose())
                }
              })
              this.ground = null
            },
            buildWater() {
              const THREE = this.THREE
              const group = new THREE.Group()
              const water = new THREE.Mesh(
                new THREE.PlaneGeometry(28, 28),
                new THREE.MeshPhongMaterial({
                  color: 0x5aa7c8,
                  transparent: true,
                  opacity: 0.62,
                  shininess: 120,
                  specular: 0xd6f0ff
                })
              )
              water.rotation.x = -Math.PI / 2
              water.position.y = 0.01
              group.add(water)
              this.water = group
              this.scene.add(group)
            },
            clearWater() {
              if (!this.water) return
              this.scene.remove(this.water)
              this.water.traverse((obj) => {
                if (obj.geometry) obj.geometry.dispose()
                if (obj.getRenderTarget) obj.getRenderTarget().dispose()
                if (obj.material) {
                  const mats = Array.isArray(obj.material) ? obj.material : [obj.material]
                  mats.forEach((m) => m && m.dispose && m.dispose())
                }
              })
              this.water = null
            },
            placeMesh(mesh, body) {
              const THREE = this.THREE
              if (body.geom === "capsule" && body.from && body.to) {
                const a = new THREE.Vector3(...this.toThree(body.from))
                const b = new THREE.Vector3(...this.toThree(body.to))
                const dir = b.clone().sub(a)
                const len = Math.max(dir.length(), 1e-4)
                mesh.geometry.dispose()
                mesh.geometry = new THREE.CapsuleGeometry(body.radius || 0.04, Math.max(len - 2 * (body.radius || 0.04), 0.001), 4, 10)
                mesh.position.copy(a.clone().add(b).multiplyScalar(0.5))
                mesh.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), dir.normalize())
              } else {
                const p = this.toThree(body.pos || [0, 0, 0])
                mesh.position.set(p[0], p[1], p[2])
              }
            },
            placeCamera() {
              const t = this.toThree(this.track || [0, 0, 0])
              const az = (this.azimuth * Math.PI) / 180
              const el = (this.elevation * Math.PI) / 180
              const d = this.distance
              this.camera.position.set(
                t[0] + d * Math.cos(el) * Math.cos(az),
                t[1] + d * Math.sin(el),
                t[2] + d * Math.cos(el) * Math.sin(az)
              )
              this.camera.lookAt(t[0], t[1], t[2])
            }
          }

          document.addEventListener("DOMContentLoaded", function () {
            const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content")
            const Live = window.LiveView || window.phoenix_live_view
            const liveSocket = new Live.LiveSocket("/live", window.Phoenix.Socket, {
              params: {_csrf_token: csrf},
              hooks: Hooks
            })
            liveSocket.connect()
            window.liveSocket = liveSocket
          })
        </script>
      </head>
      <body>
        {@inner_content}
      </body>
    </html>
    """
  end
end
