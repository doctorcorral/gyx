defmodule TrainingWorker do
  @behaviour Honeydew.Worker

  def train(seed) do
    IO.puts "Worker #{inspect(self())} - Starting training with seed: #{seed}!"
  end
end
