module ResqueJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :resque
    Resque.redis = Redis::Namespace.new 'active_jobs_int_test', redis: Redis.connect(url: "tcp://127.0.0.1:6379/12", :thread_safe => true)
    Resque.logger = Rails.logger
    unless can_run?
      puts "Cannot run integration tests for resque. To be able to run integration tests for resque you need to install and start redis.\n"
      exit
    end
  end

  def clear_jobs
    Resque.queues.each { |queue_name| Resque.redis.del "queue:#{queue_name}" }
    Resque.redis.keys("delayed:*").each  { |key| Resque.redis.del "#{key}" }
    Resque.redis.del "delayed_queue_schedule"
  end

  def start_workers
    @resque_thread = Thread.new do
      Resque::Worker.new("integration_tests").work(0.5)
    end
    @scheduler_thread = Thread.new do
      Resque::Scheduler.configure do |c|
        c.poll_sleep_amount = 0.5
        c.dynamic = true
        c.verbose = true
        c.logfile = nil
      end
      Resque::Scheduler.master_lock.release!
      Resque::Scheduler.run
    end
  end

  def stop_workers
    @resque_thread.kill
    @scheduler_thread.kill
  end

  def can_run?
    begin
      Resque.redis.client.connect
    rescue => e
      return false
    end
    true
  end
end
