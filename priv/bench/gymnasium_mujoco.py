#!/usr/bin/env python3
"""Wall-clock step throughput for Gymnasium MuJoCo (no rendering)."""

from __future__ import annotations

import argparse
import json
import time
import warnings

import gymnasium as gym


DEFAULT_IDS = [
    "InvertedPendulum-v4",
    "InvertedDoublePendulum-v4",
    "Reacher-v4",
    "Swimmer-v4",
    "Hopper-v4",
    "Walker2d-v4",
    "HalfCheetah-v4",
    "Ant-v4",
]


def bench(env_id: str, steps: int, warmup: int, seed: int) -> dict:
    env = gym.make(env_id)
    env.reset(seed=seed)
    for _ in range(warmup):
        action = env.action_space.sample()
        _, _, terminated, truncated, _ = env.step(action)
        if terminated or truncated:
            env.reset()

    resets = 0
    t0 = time.perf_counter()
    for _ in range(steps):
        action = env.action_space.sample()
        _, _, terminated, truncated, _ = env.step(action)
        if terminated or truncated:
            env.reset()
            resets += 1
    seconds = time.perf_counter() - t0
    env.close()
    return {
        "id": env_id,
        "backend": "gymnasium",
        "steps": steps,
        "resets": resets,
        "seconds": seconds,
        "steps_per_sec": steps / seconds if seconds else 0.0,
        "us_per_step": 1e6 * seconds / steps if steps else 0.0,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--steps", type=int, default=2000)
    parser.add_argument("--warmup", type=int, default=100)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--id", action="append", dest="ids")
    args = parser.parse_args()
    ids = args.ids or DEFAULT_IDS

    warnings.filterwarnings("ignore", category=DeprecationWarning)
    rows = []
    for env_id in ids:
        try:
            rows.append(bench(env_id, args.steps, args.warmup, args.seed))
        except Exception as exc:  # noqa: BLE001
            rows.append({"id": env_id, "backend": "gymnasium", "error": str(exc)})
    print(json.dumps(rows))


if __name__ == "__main__":
    main()
