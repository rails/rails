# frozen_string_literal: true

require "securerandom"
require "concurrent/scheduled_task"
require "concurrent/executor/thread_pool_executor"
require "concurrent/utility/processor_counter"

module ActiveJob
  module QueueAdapters
    # = Active Job Async adapter
    #
    # The Async adapter runs jobs with an in-process thread pool.
    #
    # This is the default queue adapter. It's well-suited for dev/test since
    # it doesn't need an external infrastructure, but it's a poor fit for
    # production since it drops pending jobs on restart.
    #
    # To use this adapter, set queue adapter to +:async+:
    #
    #   config.active_job.queue_adapter = :async
    #
    # To configure the adapter's thread pool, instantiate the adapter and
    # pass your own config:
    #
    #   config.active_job.queue_adapter = ActiveJob::QueueAdapters::AsyncAdapter.new \
    #     min_threads: 1,
    #     max_threads: 2 * Concurrent.processor_count,
    #     idletime: 600.seconds
    #
    # The adapter uses a {Concurrent Ruby}[https://github.com/ruby-concurrency/concurrent-ruby] thread pool to schedule and execute
    # jobs. Since jobs share a single thread pool, long-running jobs will block
    # short-lived jobs. Fine for dev/test; bad for production.
    class AsyncAdapter < AbstractAdapter
      # See {Concurrent::ThreadPoolExecutor}[https://ruby-concurrency.github.io/concurrent-ruby/master/Concurrent/ThreadPoolExecutor.html] for executor options.
      def initialize(**executor_options)
        @scheduler = Scheduler.new(**executor_options)
      end

      def enqueue(job) # :nodoc:
        @scheduler.enqueue JobWrapper.new(job), queue_name: job.queue_name
      end

      def enqueue_at(job, timestamp) # :nodoc:
        @scheduler.enqueue_at JobWrapper.new(job), timestamp, queue_name: job.queue_name
      end

      # Gracefully stop processing jobs. Finishes in-progress work and handles
      # any new jobs following the executor's fallback policy (`caller_runs`).
      # Waits for termination by default. Pass `wait: false` to continue.
      def shutdown(wait: true) # :nodoc:
        @scheduler.shutdown wait: wait
      end

      # Used for our test suite.
      def immediate=(immediate) # :nodoc:
        @scheduler.immediate = immediate
      end

      # Note that we don't actually need to serialize the jobs since we're
      # performing them in-process, but we do so anyway for parity with other
      # adapters and deployment environments. Otherwise, serialization bugs
      # may creep in undetected.
      class JobWrapper # :nodoc:
        def initialize(job)
          job.provider_job_id = SecureRandom.uuid
          @job_data = job.serialize
        end

        def perform
          Base.execute @job_data
        end
      end

      class Scheduler # :nodoc:
        DEFAULT_EXECUTOR_OPTIONS = {
          min_threads:     0,
          max_threads:     Concurrent.processor_count,
          auto_terminate:  true,
          idletime:        60, # 1 minute
          max_queue:       0, # unlimited
          fallback_policy: :caller_runs # shouldn't matter -- 0 max queue
        }.freeze

        attr_accessor :immediate

        def initialize(**options)
          self.immediate = false
          @immediate_executor = Concurrent::ImmediateExecutor.new
          @async_executor = Concurrent::ThreadPoolExecutor.new(DEFAULT_EXECUTOR_OPTIONS.merge(options))
        end

        def enqueue(job, queue_name:)
          executor.post(job, &:perform)
        end

        def enqueue_at(job, timestamp, queue_name:)
          delay = timestamp - Time.current.to_f
          if !immediate && delay > 0
            Concurrent::ScheduledTask.execute(delay, args: [job], executor: executor, &:perform)
          else
            enqueue(job, queue_name: queue_name)
          end
        end

        def shutdown(wait: true)
          @async_executor.shutdown
          @async_executor.wait_for_termination if wait
        end

        def executor
          immediate ? @immediate_executor : @async_executor
        end
      end
    end
  end
end
