# frozen_string_literal: true

require "sidekiq/api"

require "sidekiq/testing"
Sidekiq::Testing.disable!

module SidekiqJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :sidekiq
    unless can_run?
      puts "Cannot run integration tests for sidekiq. To be able to run integration tests for sidekiq you need to install and start redis.\n"
      status = ENV["CI"] ? false : true
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
      continue_read.close
      death_write.close

      # Sidekiq is not warning-clean :(
      $VERBOSE = false

      $stdin.reopen(File::NULL)
      $stdout.sync = true
      $stderr.sync = true

      logfile = Rails.root.join("log/sidekiq.log").to_s
      Sidekiq.logger = Sidekiq::Logger.new(logfile)

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
      sidekiq = Sidekiq::Launcher.new(queues: ["integration_tests"],
                                       environment: "test",
                                       concurrency: 1,
                                       timeout: 1)
      Sidekiq.average_scheduled_poll_interval = 0.5
      Sidekiq.options[:poll_interval_average] = 1
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
      Sidekiq.logger = nil
    rescue
      return false
    end
    true
  end
end
