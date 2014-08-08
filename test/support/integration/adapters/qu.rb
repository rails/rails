module QuJobsManager
  def clear_jobs
    Qu.clear "active_jobs_default"
  end

  def start_workers
    @thread = Thread.new { Qu::Worker.new("active_jobs_default").start }
  end

  def stop_workers
    @thread.kill
  end
end

