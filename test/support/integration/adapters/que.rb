module QueJobsManager
  def clear_jobs
    Que.clear!
  end

  def start_workers
    @thread = Thread.new do
      loop do
        Que::Job.work("active_jobs_default")
        sleep 0.5
      end
    end
  end

  def stop_workers
    @thread.kill
  end
end

