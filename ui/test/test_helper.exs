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

unless atari? do
  Mix.shell().info("skipping :atari tests (python3 + gymnasium + ale-py + ROMs not found)")
end

ExUnit.start(exclude: if(atari?, do: [], else: [:atari]))
