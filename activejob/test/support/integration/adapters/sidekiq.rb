require 'sidekiq/cli'
require 'sidekiq/api'

module SidekiqJobsManager

  def setup
    ActiveJob::Base.queue_adapter = :sidekiq
    unless can_run?
      puts "Cannot run integration tests for sidekiq. To be able to run integration tests for sidekiq you need to install and start redis.\n"
      exit
    end
  end

  def clear_jobs
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::Queue.new("integration_tests").clear
  end

  def start_workers
    fork do
      sidekiq = Sidekiq::CLI.instance
      logfile = Rails.root.join("log/sidekiq.log").to_s
      pidfile = Rails.root.join("tmp/sidekiq.pid").to_s
      sidekiq.parse([ "--require", Rails.root.to_s,
                      "--queue",   "integration_tests",
                      "--logfile", logfile,
                      "--pidfile", pidfile,
                      "--environment", "test",
                      "--concurrency", "1",
                      "--timeout", "1",
                      "--daemon",
                      ])
      require 'celluloid'
      require 'sidekiq/scheduled'
      Sidekiq.poll_interval = 0.5
      Sidekiq::Scheduled.const_set :INITIAL_WAIT, 1
      sidekiq.run
    end
    sleep 1
  end

  def stop_workers
    pidfile = Rails.root.join("tmp/sidekiq.pid").to_s
    Process.kill 'TERM', File.open(pidfile).read.to_i
    FileUtils.rm_f pidfile
  rescue
  end

  def can_run?
    begin
      Sidekiq.redis { |conn| conn.connect }
    rescue
      return false
    end
    true
  end
end
