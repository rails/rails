module ResqueJobsManager
  def clear_jobs
    Resque.queues.each { |queue_name| Resque.redis.del "queue:#{queue_name}" }
    Resque.redis.keys("delayed:*").each  { |key| Resque.redis.del "#{key}" }
    Resque.redis.del "delayed_queue_schedule"
  end

  def start_workers
    @thread = Thread.new do
      Resque::Worker.new("*").work(0.5)
    end
  end

  def stop_workers
    @thread.kill
  end
end

