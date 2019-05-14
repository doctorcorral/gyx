defmodule Gyx.TrainingScheduler do

  def start_link(_, opts) do
    # Setup Training Job definition queue
    :ok = Honeydew.start_queue(:training_jobs)
    :ok = Honeydew.start_workers(:training_jobs, Gyx.TrainingWorker, num: 2)

    # Setup Experiences gethering queue
    :ok = Honeydew.start_queue(:experiences)
    :ok = Honeydew.start_workers(:experiences, Gyx.ExperiencesGatherer, num: 1)

    {:train, [1]} |> Honeydew.async(:training_jobs) # Enqueue first training job
    {:train, [2]} |> Honeydew.async(:training_jobs) # Enqueue second training job
    Process.sleep(10000)
    {:ok, self()}
  end
end
