module QuJobsManager
  def setup
    require "qu-rails"
    require "qu-redis"
    ActiveJob::Base.queue_adapter = :qu
    ENV["REDISTOGO_URL"] = "redis://127.0.0.1:6379/12"
    backend = Qu::Backend::Redis.new
    backend.namespace = "active_jobs_int_test"
    Qu.backend  = backend
    Qu.logger   = Rails.logger
    Qu.interval = 0.5
    unless can_run?
      puts "Cannot run integration tests for qu. To be able to run integration tests for qu you need to install and start redis.\n"
      exit
    end
  end

  def clear_jobs
    Qu.clear "integration_tests"
  end

  def start_workers
    @thread = Thread.new { Qu::Worker.new("integration_tests").start }
  end

  def stop_workers
    @thread.kill
  end

  def can_run?
    begin
      Qu.backend.connection.client.connect
    rescue
      return false
    end
    true
  end
end
