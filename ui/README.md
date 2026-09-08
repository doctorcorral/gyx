# Gyx UI

Optional Phoenix LiveView playground. It is **not** part of the Gyx
library: Gyx does not compile or ship this app. The UI talks to Gyx
through `Gyx.Session` (step / reset / render) and `Gyx.Experiment`
(train).

```bash
cd ui
mix deps.get
mix phx.server
```

Open http://127.0.0.1:4000

The same workflows from the shell:

```bash
mix gyx.envs
mix gyx.interact CartPole-v1 --steps 8
mix gyx.train CartPole-v1 --algo q_learning --episodes 50
mix gyx.experiment new cart --env CartPole-v1 --algo a2c
```
