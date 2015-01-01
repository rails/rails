module TestJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true
    ActiveJob::Base.queue_adapter.perform_enqueued_at_jobs = false
  end

  def clear_jobs
  end

  def start_workers
  end

  def stop_workers
  end
end

