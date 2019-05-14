defmodule Gyx.TrainingScheduler do

  def start_link(_, opts) do
    :ok = Honeydew.start_queue(:training_jobs)
    :ok = Honeydew.start_workers(:training_jobs, Gyx.TrainingWorker, num: 2)

    {:train, [1]} |> Honeydew.async(:training_jobs) # Enqueue second training job
    {:train, [2]} |> Honeydew.async(:training_jobs) # Enqueue second training job

    {:ok, self()}
  end
end
