# frozen_string_literal: true

require "sidekiq/api"

require "sidekiq/testing"
Sidekiq::Testing.disable!

module SidekiqJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :sidekiq
    unless can_run?
      puts "Cannot run integration tests for Sidekiq. To be able to run integration tests for Sidekiq you need to install and start Redis.\n"
      status = ENV["BUILDKITE"] ? false : true
      exit status
    end
  end

  def clear_jobs
    Sidekiq::ScheduledSet.new.clear
    Sidekiq::Queue.new("integration_tests").clear
  end

  def start_workers
    continue_read, continue_write = IO.pipe
    death_read, death_write = IO.pipe

    @pid = fork do
      Sidekiq.redis_pool.reload(&:close)
      continue_read.close
      death_write.close

      # Sidekiq is not warning-clean :(
      $VERBOSE = false

      $stdin.reopen(File::NULL)
      $stdout.sync = true
      $stderr.sync = true

      logfile = Rails.root.join("log/sidekiq.log").to_s
      set_logger(Sidekiq::Logger.new(logfile))

      self_read, self_write = IO.pipe
      trap "TERM" do
        self_write.puts("TERM")
      end

      Thread.new do
        begin
          death_read.read
        rescue Exception
        end
        self_write.puts("TERM")
      end

      require "sidekiq/cli"
      require "sidekiq/launcher"
      if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("7")
        config = Sidekiq.default_configuration
        config.queues = ["integration_tests"]
        config.concurrency = 1
        config.average_scheduled_poll_interval = 0.5
        config.merge!(
          environment: "test",
          timeout: 1,
          poll_interval_average: 1
        )
      elsif Sidekiq.respond_to?(:[]=)
        # Sidekiq 6.5
        config = Sidekiq
        config[:queues] = ["integration_tests"]
        config[:environment] = "test"
        config[:concurrency] = 1
        config[:timeout] = 1
      else
        config = {
          queues: ["integration_tests"],
          environment: "test",
          concurrency: 1,
          timeout: 1,
          average_scheduled_poll_interval: 0.5,
          poll_interval_average: 1
        }
      end
      sidekiq = Sidekiq::Launcher.new(config)
      begin
        sidekiq.run
        continue_write.puts "started"
        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          raise Interrupt if signal == "TERM"
        end
      rescue Interrupt
      end

      sidekiq.stop
      exit!
    end
    continue_write.close
    death_read.close
    @worker_lifeline = death_write

    raise "Failed to start worker" unless continue_read.gets == "started\n"
  end

  def stop_workers
    if @pid
      Process.kill "TERM", @pid
      Process.wait @pid
    end
  end

  def can_run?
    begin
      Sidekiq.redis(&:info)
    rescue => e
      if e.class.to_s.include?("CannotConnectError")
        return false
      else
        raise
      end
    end
    set_logger(nil)
    true
  end

  def set_logger(logger)
    if Gem::Version.new(Sidekiq::VERSION) >= Gem::Version.new("7")
      Sidekiq.default_configuration.logger = logger
    else
      Sidekiq.logger = logger
    end
  end
end
