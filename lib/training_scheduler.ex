defmodule Gyx.TrainingScheduler do

  def start_link(_, opts) do
    :ok = Honeydew.start_queue(:training_jobs)
    :ok = Honeydew.start_workers(:training_jobs, TrainingWorker, num: 2)
    {:train, [10]} |> Honeydew.async(:training_jobs) # Enqueue first training job
    {:train, [20]} |> Honeydew.async(:training_jobs) # Enqueue second training job
    Process.sleep(1000)
    {:ok, self()}
  end
end
