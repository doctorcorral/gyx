defmodule Gyx.TrainingWorker do
  @behaviour Honeydew.Worker

  def train(seed) do
    IO.puts "worker[#{inspect(self())}] - Starting Gyx.Trainers.TrainerSarsa with seed: #{seed}!"
    result = Gyx.Trainers.TrainerSarsa.train # Replace this with proper step advancing
    IO.puts "worker[#{inspect(self())}] - Storing experience in ReplayBufferETS"
    Gyx.Experience.ReplayBufferETS.add(result)
  end
end
