# frozen_string_literal: true

require 'sneakers/runner'
require 'timeout'

module SneakersJobsManager
  def setup
    ActiveJob::Base.queue_adapter = :sneakers
    Sneakers.configure  heartbeat: 2,
                        amqp: ENV['RABBITMQ_URL'] || 'amqp://guest:guest@localhost:5672',
                        vhost: '/',
                        exchange: 'active_jobs_sneakers_int_test',
                        exchange_type: :direct,
                        daemonize: true,
                        threads: 1,
                        workers: 1,
                        pid_path: Rails.root.join('tmp/sneakers.pid').to_s,
                        log: Rails.root.join('log/sneakers.log').to_s
    unless can_run?
      puts "Cannot run integration tests for sneakers. To be able to run integration tests for sneakers you need to install and start rabbitmq.\n"
      status = ENV['CI'] ? false : true
      exit status
    end
  end

  def clear_jobs
    bunny_queue.purge
  end

  def start_workers
    @pid = fork do
      queues = %w(integration_tests)
      workers = queues.map do |q|
        worker_klass = 'ActiveJobWorker' + Digest::MD5.hexdigest(q)
        Sneakers.const_set(worker_klass, Class.new(ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper) do
          from_queue q
        end)
      end
      Sneakers::Runner.new(workers).run
    end
    begin
      Timeout.timeout(10) do
        while bunny_queue.status[:consumer_count] == 0
          sleep 0.5
        end
      end
    rescue Timeout::Error
      stop_workers
      raise 'Failed to start sneakers worker'
    end
  end

  def stop_workers
    Process.kill 'TERM', @pid
    Process.kill 'TERM', File.open(Rails.root.join('tmp/sneakers.pid').to_s).read.to_i
  rescue
  end

  def can_run?
    begin
      bunny_publisher
    rescue
      return false
    end
    true
  end

  private
    def bunny_publisher
      @bunny_publisher ||= begin
        p = ActiveJob::QueueAdapters::SneakersAdapter::JobWrapper.send(:publisher)
        p.ensure_connection!
        p
      end
    end

    def bunny_queue
      @queue ||= bunny_publisher.exchange.channel.queue 'integration_tests', durable: true
    end
end
