module BackburnerJobsManager
  def clear_jobs
    Backburner::Worker.connection.tubes.all.map &:clear
  end

  def start_workers
    @thread = Thread.new { Backburner.work "active-jobs-default" }
  end

  def stop_workers
    @thread.kill
  end

end

