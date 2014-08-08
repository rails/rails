module DelayedJobJobsManager
  def clear_jobs
    Delayed::Job.delete_all
  end

  def start_workers
    @worker = Delayed::Worker.new(quiet: false, sleep_delay: 0.5)
    @thread = Thread.new { @worker.start }
  end

  def stop_workers
    @worker.stop
  end
end
