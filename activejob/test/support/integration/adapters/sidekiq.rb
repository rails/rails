require 'sidekiq/api'

require 'sidekiq/testing'
Sidekiq::Testing.disable!

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
      logfile = Rails.root.join("log/sidekiq.log").to_s
      pidfile = Rails.root.join("tmp/sidekiq.pid").to_s
      ::Process.daemon(true, true)
      [$stdout, $stderr].each do |io|
        File.open(logfile, 'ab') do |f|
          io.reopen(f)
        end
        io.sync = true
      end
      $stdin.reopen('/dev/null')
      Sidekiq::Logging.initialize_logger(logfile)
      File.open(File.expand_path(pidfile), 'w') do |f|
        f.puts ::Process.pid
      end

      self_read, self_write = IO.pipe
      trap "TERM" do
        self_write.puts("TERM")
      end

      require 'celluloid'
      require 'sidekiq/launcher'
      sidekiq = Sidekiq::Launcher.new({queues: ["integration_tests"],
                                       environment: "test",
                                       concurrency: 1,
                                       timeout: 1,
                                      })
      Sidekiq.poll_interval = 0.5
      Sidekiq::Scheduled.const_set :INITIAL_WAIT, 1
      begin
        sidekiq.run
        while readable_io = IO.select([self_read])
          signal = readable_io.first[0].gets.strip
          raise Interrupt if signal == "TERM"
        end
      rescue Interrupt
        sidekiq.stop
        exit(0)
      end
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
      Sidekiq.redis(&:info)
      Sidekiq.logger = nil
    rescue
      return false
    end
    true
  end
end
