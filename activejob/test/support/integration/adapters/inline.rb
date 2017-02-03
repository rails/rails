module InlineJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :inline
  end

  def clear_jobs
  end

  def start_workers
  end

  def stop_workers
  end
end
