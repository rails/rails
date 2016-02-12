require 'concurrent/map'
require 'concurrent/scheduled_task'
require 'concurrent/executor/thread_pool_executor'
require 'concurrent/utility/processor_counter'

module ActiveJob
  # == Active Job Async Job
  #
  # When enqueuing jobs with Async Job each job will be executed asynchronously
  # on a +concurrent-ruby+ thread pool. All job data is retained in memory.
  # Because job data is not saved to a persistent datastore there is no
  # additional infrastructure needed and jobs process quickly. The lack of
  # persistence, however, means that all unprocessed jobs will be lost on
  # application restart. Therefore in-memory queue adapters are unsuitable for
  # most production environments but are excellent for development and testing.
  #
  # Read more about Concurrent Ruby {here}[https://github.com/ruby-concurrency/concurrent-ruby].
  #
  # To use Async Job set the queue_adapter config to +:async+.
  #
  #   Rails.application.config.active_job.queue_adapter = :async
  #
  # Async Job supports job queues specified with +queue_as+. Queues are created
  # automatically as needed and each has its own thread pool.
  class AsyncJob

    DEFAULT_EXECUTOR_OPTIONS = {
      min_threads:     [2, Concurrent.processor_count].max,
      max_threads:     Concurrent.processor_count * 10,
      auto_terminate:  true,
      idletime:        60, # 1 minute
      max_queue:       0, # unlimited
      fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
    }.freeze

    QUEUES = Concurrent::Map.new do |hash, queue_name| #:nodoc:
      hash.compute_if_absent(queue_name) { ActiveJob::AsyncJob.create_thread_pool }
    end

    class << self
      # Forces jobs to process immediately when testing the Active Job gem.
      # This should only be called from within unit tests.
      def perform_immediately! #:nodoc:
        @perform_immediately = true
      end

      # Allows jobs to run asynchronously when testing the Active Job gem.
      # This should only be called from within unit tests.
      def perform_asynchronously! #:nodoc:
        @perform_immediately = false
      end

      def create_thread_pool #:nodoc:
        if @perform_immediately
          Concurrent::ImmediateExecutor.new
        else
          Concurrent::ThreadPoolExecutor.new(DEFAULT_EXECUTOR_OPTIONS)
        end
      end

      def enqueue(job_data, queue: 'default') #:nodoc:
        QUEUES[queue].post(job_data) { |job| ActiveJob::Base.execute(job) }
      end

      def enqueue_at(job_data, timestamp, queue: 'default') #:nodoc:
        delay = timestamp - Time.current.to_f
        if delay > 0
          Concurrent::ScheduledTask.execute(delay, args: [job_data], executor: QUEUES[queue]) do |job|
            ActiveJob::Base.execute(job)
          end
        else
          enqueue(job_data, queue: queue)
        end
      end
    end
  end
end
