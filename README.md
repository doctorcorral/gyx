![gyX](images/gyxheader-elixir.png)

# Gyx

Native Elixir reinforcement learning. Environments follow a Gymnasium-shaped
contract and trainers stay in Elixir. Drive them from IEx, the Mix CLI,
or the optional `ui/` playground (a separate Phoenix app).

The Python OpenAI Gym `erlport` bridge is deprecated. Gymnasium interaction
for CSHRL synthesis lives in [synthex](https://github.com/doctorcorral/synthex).

## Usage

```elixir
{:ok, env} = Gyx.make("CartPole-v1")
{env, obs, info} = Gyx.reset(env, seed: 0)
{:ok, env, exp} = Gyx.step(env, 1)

exp.next_observation
exp.reward
exp.terminated
exp.truncated
```

Registered ids include the classic control suite, three MuJoCo backends,
and an Atari wrap. The **env** is `Hopper-v4`; prefixes name the
implementation:

* **Farama MuJoCo** (`Hopper-v4`, …) — official MJCF plus a native
  rigid-body engine (`Gyx.Physics.Mj`) compiled with **Nx/EXLA**.
  Same observation/reward contract as `gymnasium.make("Hopper-v4")`.
  The first step of each body/dof shape compiles an XLA kernel (a few
  seconds); later steps reuse it. Set `config :gyx, :mj_backend, :elixir`
  to use the scalar BEAM path instead.
* **Tree** (`tree/Hopper-v4`, …) — the older approximate
  `Gyx.Physics.Tree` backend. Fast to hack on, not a physics clone.
* **Gymnasium (Python)** (`gymnasium/Hopper-v4`, v4 and v5) — the real
  MuJoCo C engine via a Python Port. Requires `python3` with
  `gymnasium` and `mujoco`.
* **Atari (Python)** (`gymnasium/ALE/Pong-v5`, Breakout, SpaceInvaders,
  MsPacman) — ALE/Stella through the same Port. Observations are
  `uint8` Nx tensors (`210×160×3`); actions are `Discrete`. Requires
  `python3` with `gymnasium` and `ale-py` (and the ALE ROMs). There is
  no unprefixed or `tree/` Atari id.

```elixir
Gyx.envs()
{:ok, svg} = Gyx.render(env, :svg)
{:ok, scene} = Gyx.render(env, :scene)
{:ok, text} = Gyx.render(env, :ansi)

# Pure-Elixir Farama Hopper (official XML + native engine).
{:ok, env} = Gyx.make("Hopper-v4")
{env, obs, info} = Gyx.reset(env, seed: 0)
{:ok, env, exp} = Gyx.step(env, {0.1, 0.0, -0.1})

# Optional: evaluate the same id on the C engine.
{:ok, env} = Gyx.make("gymnasium/Hopper-v4")

# Atari wrap: Discrete joystick, pixel obs as an Nx tensor.
{:ok, env} = Gyx.make("gymnasium/ALE/Pong-v5")
{env, obs, info} = Gyx.reset(env, seed: 0)
Nx.shape(obs)
{:ok, env, exp} = Gyx.step(env, 0)
```

Tabular Q-learning (continuous observations are binned first):

```elixir
alias Gyx.{Agents.QLearning, Encode, Trainers.Episodic}

agent = QLearning.new(alpha: 0.2, gamma: 0.99, epsilon: 0.2)
%{agent: agent} = Episodic.train("FrozenLake-v1", agent, episodes: 1500, env: [is_slippery: false])
Episodic.evaluate("FrozenLake-v1", agent, env: [is_slippery: false])

{agent, opts} = Gyx.Trainers.Presets.q_learning("CartPole-v1")
%{agent: agent} = Episodic.train("CartPole-v1", agent, opts)

{agent, opts} = Gyx.Trainers.Presets.a2c("CartPole-v1")
%{agent: agent} = Episodic.train("CartPole-v1", agent, opts)
```

SARSA and REINFORCE use the same trainer (`Gyx.Agent`). A2C and PPO use
an **Axon** MLP on vector observations, or a small conv net on Atari
frames (`gymnasium/ALE/*`). Pendulum’s Box torque is discretized to
`-2/0/+2` for these discrete policies.

`Gyx.Encode.for_env/1` turns continuous boxes into integer tuples so the
Q-table stays finite.

Pass `server: true` to `Gyx.make/2` when you want a process-backed env.

Synthex can score these envs without Python:

```elixir
scorer = Gyx.Synthex.Scorer.new("CartPole-v1")
scorer.(%{"cmd" => "collect_states", "default" => 0, "seeds" => [0, 1]})
```

Or run a real Oracle pass (collect → features → score) against GYX:

```bash
mix gyx.synthex
mix gyx.synthex --env MountainCar-v0
```

## CLI

```bash
mix gyx.envs
mix gyx.envs CartPole-v1

mix gyx.interact CartPole-v1 --seed 0 --steps 8
mix gyx.interact CartPole-v1 --action 1 --action 0 --render ansi

mix gyx.train CartPole-v1 --algo q_learning --episodes 50
mix gyx.experiment new cart --env CartPole-v1 --algo a2c
mix gyx.experiment run cart --episodes 20
```

`Gyx.Session` is the interactive handle. `Gyx.Experiment` is the named
learning run (JSON under `experiments/`).

## Playground

The LiveView UI is a **separate** Phoenix app under `ui/`. It is not
compiled or shipped with Gyx; it depends on this library and wraps
`Gyx.Session` / `Gyx.Experiment`.

```bash
cd ui
mix deps.get
mix phx.server
```

Compare step time across native Farama, tree, the Python wrap, and
in-process Gymnasium (requires `python3` with `gymnasium` and `mujoco`):

```bash
mix gyx.bench
```

## Layout

* `Gyx.Env` — functional environment behaviour
* `Gyx.Core.Exp` — `{obs, reward, terminated, truncated, info}` transition
* `Gyx.Core.Spaces` — Discrete, Box (`dtype` + Nx tensors for images), Tuple
* `Gyx.Envs.*` — native physics, including the Farama MuJoCo suite
* `Gyx.Physics.Mj` / `Gyx.Physics.Mjx` / `Gyx.Physics.Mjcf` — official MJCF + EXLA-compiled CRBA/RNEA step (analytic J/Coriolis, specialized RK4/Euler kernels)
* `Gyx.Physics.Tree` — approximate articulated bodies (`tree/*` ids)
* `priv/mjcf/` — vendored Farama Gymnasium MuJoCo assets (Apache-2.0)
* `Gyx.Encode` — box → integer-tuple bins for tabular methods
* `Gyx.Agents.{QLearning, Sarsa, Reinforce, ActorCritic}` / `Gyx.Trainers.Episodic` — classical RL (A2C/PPO via Axon+Nx)
* `Gyx.Session` / `Gyx.Experiment` — interactive handle and named learning runs
* `Gyx.Synthex.Scorer` / `Gyx.Synthex.Probe` — Python-free Synthex hook
* `ui/` — optional Phoenix playground (not part of the Hex package)

Legacy Gym/Python/SARSA code is under `legacy/` and is not compiled.
