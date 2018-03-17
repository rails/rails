# frozen_string_literal: true

require "faktory_worker_ruby"
require "faktory/testing"
Faktory::Testing.disable!

module FaktoryJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :faktory
    unless can_run?
      puts "Cannot run integration tests for faktory. To be able to run integration tests for faktory you need to install and start the faktory server.\n"
      status = ENV["CI"] ? false : true
      exit status
    end
  end

  def clear_jobs
    #Faktory.server{|s| s.flush }
  end

  def start_workers
    continue_read, continue_write = IO.pipe
    death_read, death_write = IO.pipe

    @pid = fork do
      continue_read.close
      death_write.close

      # Faktory is not warning-clean :(
      $VERBOSE = false

      $stdin.reopen(File::NULL)
      $stdout.sync = true
      $stderr.sync = true

      logfile = Rails.root.join("log/faktory.log").to_s
      Faktory.logger = Logger.new(logfile)
      #Faktory::Logging.initialize_logger(logfile)

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

      require "faktory/cli"
      require "faktory/launcher"
      faktory = Faktory::Launcher.new(queues: ["blarf"],
                                       environment: "test",
                                       concurrency: 1,
                                       timeout: 1)
      begin
        faktory.run
        continue_write.puts "started"
        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          raise Interrupt if signal == "TERM"
        end
      rescue Interrupt
      end

      faktory.stop
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
      Faktory::Client.new.info
    rescue
      return false
    end
    true
  end
end
