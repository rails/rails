module AsyncJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :async
  end

  def clear_jobs
    ActiveJob::AsyncJob::QUEUES.clear
  end
end
