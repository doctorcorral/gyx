#!/usr/bin/env python3
"""Length-prefixed JSON bridge to Gymnasium.

Elixir talks to this process with Port packet-4 frames. Each env instance
is a real `gymnasium.make` handle so observations, rewards, and terminals
match Farama on the same seed.

Vector observations stay JSON lists. `uint8` frames (Atari and similar)
cross as base64-packed binaries so a 210×160×3 frame is not a JSON array.
Discrete actions stay integers; Box actions stay float lists.
"""

from __future__ import annotations

import json
import math
import struct
import sys
import traceback
import zlib


def recv() -> dict | None:
    header = sys.stdin.buffer.read(4)
    if not header or len(header) < 4:
        return None
    (n,) = struct.unpack(">I", header)
    raw = sys.stdin.buffer.read(n)
    if len(raw) < n:
        return None
    return json.loads(raw.decode("utf-8"))


def send(payload: dict) -> None:
    raw = json.dumps(payload, allow_nan=False).encode("utf-8")
    sys.stdout.buffer.write(struct.pack(">I", len(raw)))
    sys.stdout.buffer.write(raw)
    sys.stdout.buffer.flush()


def json_safe(value):
    if value is None or isinstance(value, (bool, str, int)):
        return value
    if isinstance(value, float):
        return float(value) if math.isfinite(value) else None
    if hasattr(value, "tolist"):
        return json_safe(value.tolist())
    if isinstance(value, (list, tuple)):
        return [json_safe(v) for v in value]
    if isinstance(value, dict):
        return {str(k): json_safe(v) for k, v in value.items()}
    return str(value)


def png_base64(arr) -> str:
    import base64

    try:
        from PIL import Image
        import io

        buf = io.BytesIO()
        Image.fromarray(arr).save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("ascii")
    except Exception:
        return _png_base64_stdlib(arr)


def _png_base64_stdlib(arr) -> str:
    import base64

    arr = arr.astype("uint8")
    height, width = int(arr.shape[0]), int(arr.shape[1])
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", zlib.compress(raw, 6))
        + chunk(b"IEND", b"")
    )
    return base64.b64encode(png).decode("ascii")


def to_list(action):
    if isinstance(action, (int, float)):
        return [float(action)]
    return [float(x) for x in action]


def encode_obs(obs):
    try:
        import numpy as np

        arr = np.asarray(obs)
        if arr.dtype == np.uint8:
            import base64

            packed = np.ascontiguousarray(arr)
            return {
                "encoding": "raw",
                "b64": base64.b64encode(packed.tobytes()).decode("ascii"),
                "shape": [int(d) for d in packed.shape],
                "dtype": "uint8",
            }
    except Exception:
        pass
    return json_safe(obs)


def decode_action(env, action):
    from gymnasium import spaces

    space = env.action_space
    if isinstance(space, spaces.Discrete):
        if isinstance(action, (list, tuple)):
            return int(action[0])
        return int(action)
    import numpy as np

    return np.asarray(to_list(action), dtype=getattr(space, "dtype", np.float32))


def space_info(space) -> dict:
    from gymnasium import spaces

    if isinstance(space, spaces.Discrete):
        return {"type": "discrete", "n": int(space.n)}
    if isinstance(space, spaces.Box):
        low = space.low
        high = space.high
        compact = getattr(low, "size", 1) > 16
        return {
            "type": "box",
            "shape": [int(d) for d in space.shape],
            "dtype": str(space.dtype),
            "low": json_safe(float(low.min()) if compact else low),
            "high": json_safe(float(high.max()) if compact else high),
        }
    return {"type": type(space).__name__}


def action_meanings(env) -> list[str]:
    uw = env.unwrapped
    if hasattr(uw, "get_action_meanings"):
        try:
            return [str(m) for m in uw.get_action_meanings()]
        except Exception:
            return []
    return []


def registry_has_ale(gym) -> bool:
    registry = getattr(gym, "registry", None) or getattr(gym.envs, "registry", {})
    return any(str(key).startswith("ALE/") for key in registry.keys())


class Bridge:
    def __init__(self, gym, mujoco: bool, atari: bool) -> None:
        self.gym = gym
        self.mujoco = mujoco
        self.atari = atari
        self.envs: dict[str, object] = {}
        self.n = 0

    def make(self, req: dict) -> dict:
        self.n += 1
        handle = f"e{self.n}"
        kwargs = {}
        if req.get("render"):
            kwargs["render_mode"] = "rgb_array"
        env = self.gym.make(req["id"], **kwargs)
        self.envs[handle] = env
        return {
            "ok": True,
            "handle": handle,
            "obs_space": space_info(env.observation_space),
            "act_space": space_info(env.action_space),
            "obs_shape": list(getattr(env.observation_space, "shape", []) or []),
            "act_shape": list(getattr(env.action_space, "shape", []) or []),
            "act_low": json_safe(getattr(env.action_space, "low", None)),
            "act_high": json_safe(getattr(env.action_space, "high", None)),
            "act_meanings": action_meanings(env),
            "max_episode_steps": getattr(env.spec, "max_episode_steps", None) if env.spec else None,
        }

    def reset(self, req: dict) -> dict:
        env = self.envs[req["handle"]]
        kwargs = {}
        if req.get("seed") is not None:
            kwargs["seed"] = int(req["seed"])
        obs, info = env.reset(**kwargs)
        return {"ok": True, "obs": encode_obs(obs), "info": json_safe(info)}

    def step(self, req: dict) -> dict:
        env = self.envs[req["handle"]]
        obs, reward, terminated, truncated, info = env.step(decode_action(env, req["action"]))
        return {
            "ok": True,
            "obs": encode_obs(obs),
            "reward": float(reward),
            "terminated": bool(terminated),
            "truncated": bool(truncated),
            "info": json_safe(info),
        }

    def render(self, req: dict) -> dict:
        env = self.envs[req["handle"]]
        frame = env.render()
        if frame is None:
            return {"ok": False, "error": "render returned None (make with render: true)"}
        return {
            "ok": True,
            "png": png_base64(frame),
            "height": int(frame.shape[0]),
            "width": int(frame.shape[1]),
        }

    def close(self, req: dict) -> dict:
        handle = req["handle"]
        env = self.envs.pop(handle, None)
        if env is not None:
            env.close()
        return {"ok": True}


def replay_start(gym, req: dict) -> dict:
    env = gym.make(req["id"])
    seed = req.get("seed")
    reset_kwargs = {"seed": int(seed)} if seed is not None else {}
    start, info = env.reset(**reset_kwargs)
    uw = env.unwrapped
    data = getattr(uw, "data", None)
    qpos0 = json_safe(getattr(data, "qpos", None))
    qvel0 = json_safe(getattr(data, "qvel", None))
    steps = []
    for action in req.get("actions") or []:
        obs, reward, terminated, truncated, step_info = env.step(decode_action(env, action))
        steps.append(
            {
                "obs": encode_obs(obs),
                "reward": float(reward),
                "terminated": bool(terminated),
                "truncated": bool(truncated),
                "info": json_safe(step_info),
            }
        )
        if terminated or truncated:
            break
    env.close()
    return {
        "ok": True,
        "obs": encode_obs(start),
        "info": json_safe(info),
        "qpos": qpos0,
        "qvel": qvel0,
        "steps": steps,
    }


def boot():
    try:
        import gymnasium as gym
    except Exception as exc:
        send({"ok": False, "op": "ready", "error": f"import failed: {exc}"})
        return None

    mujoco = False
    try:
        import mujoco  # noqa: F401

        mujoco = True
    except Exception:
        pass

    atari = False
    try:
        import ale_py

        try:
            gym.register_envs(ale_py)
        except Exception:
            pass
        atari = registry_has_ale(gym)
    except Exception:
        pass

    return gym, mujoco, atari


def main() -> None:
    booted = boot()
    if booted is None:
        return

    gym, mujoco, atari = booted
    bridge = Bridge(gym, mujoco, atari)
    send({"ok": True, "op": "ready", "gymnasium": True, "mujoco": mujoco, "atari": atari})

    while True:
        req = recv()
        if req is None:
            break
        op = req.get("op")
        try:
            if op == "ping":
                send({"ok": True, "op": "ping", "mujoco": bridge.mujoco, "atari": bridge.atari})
            elif op == "make":
                send(bridge.make(req))
            elif op == "reset":
                send(bridge.reset(req))
            elif op == "step":
                send(bridge.step(req))
            elif op == "render":
                send(bridge.render(req))
            elif op == "close":
                send(bridge.close(req))
            elif op == "replay":
                send(replay_start(bridge.gym, req))
            else:
                send({"ok": False, "error": f"unknown op {op}"})
        except Exception as exc:
            send(
                {
                    "ok": False,
                    "error": str(exc),
                    "type": type(exc).__name__,
                    "trace": traceback.format_exc(),
                }
            )


if __name__ == "__main__":
    main()
