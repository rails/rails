module QC; WAIT_TIME = 0.5; end

module QueueClassicJobsManager
  def clear_jobs
    # disabling this as it locks
    # QC::Queue.new("active_jobs_default").delete_all
  end

  def start_workers
    @pid = fork do
      QC::Conn.connection = QC::Conn.connect
      worker = QC::Worker.new(q_name: 'active_jobs_default')
      worker.start
    end
  end

  def stop_workers
    Process.kill 'HUP', @pid
  end
end

