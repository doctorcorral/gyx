gymnasium? =
  case System.find_executable("python3") do
    nil ->
      false

    python ->
      {_out, code} = System.cmd(python, ["-c", "import gymnasium, mujoco"], stderr_to_stdout: true)
      code == 0
  end

atari? =
  case System.find_executable("python3") do
    nil ->
      false

    python ->
      {_out, code} =
        System.cmd(
          python,
          [
            "-c",
            """
            import gymnasium as gym
            import ale_py
            try:
                gym.register_envs(ale_py)
            except Exception:
                pass
            gym.make("ALE/Pong-v5")
            """
          ],
          stderr_to_stdout: true
        )

      code == 0
  end

unless gymnasium? do
  Mix.shell().info("skipping :gymnasium tests (python3 + gymnasium + mujoco not found)")
end

unless atari? do
  Mix.shell().info("skipping :atari tests (python3 + gymnasium + ale-py + ROMs not found)")
end

exclude = []
exclude = if gymnasium?, do: exclude, else: [:gymnasium | exclude]
exclude = if atari?, do: exclude, else: [:atari | exclude]

ExUnit.start(exclude: exclude)
