defmodule Gyx.TrainingWorker do
  @behaviour Honeydew.Worker

  def train(seed) do
    IO.puts "Worker #{inspect(self())} - Starting training with seed: #{seed}!"
    Process.sleep(seed * 500)
    {:learn, ["Experience 1 from #{inspect self()}"]} |> Honeydew.async(:experiences) # Send experience
    Process.sleep(seed * 1000)
    {:learn, ["Experience 2 from #{inspect self()}"]} |> Honeydew.async(:experiences) # Send experience
  end
end
