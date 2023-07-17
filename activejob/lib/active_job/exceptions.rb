# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module ActiveJob
  # Provides behavior for retrying and discarding jobs on exceptions.
  module Exceptions
    extend ActiveSupport::Concern

    included do
      class_attribute :retry_jitter, instance_accessor: false, instance_predicate: false, default: 0.0
    end

    module ClassMethods
      # Catch the exception and reschedule job for re-execution after so many seconds, for a specific number of attempts.
      # If the exception keeps getting raised beyond the specified number of attempts, the exception is allowed to
      # bubble up to the underlying queuing system, which may have its own retry mechanism or place it in a
      # holding queue for inspection.
      #
      # You can also pass a block that'll be invoked if the retry attempts fail for custom logic rather than letting
      # the exception bubble up. This block is yielded with the job instance as the first and the error instance as the second parameter.
      #
      # ==== Options
      # * <tt>:wait</tt> - Re-enqueues the job with a delay specified either in seconds (default: 3 seconds),
      #   as a computing proc that takes the number of executions so far as an argument, or as a symbol reference of
      #   <tt>:exponentially_longer</tt>, which applies the wait algorithm of <tt>((executions**4) + (Kernel.rand * (executions**4) * jitter)) + 2</tt>
      #   (first wait ~3s, then ~18s, then ~83s, etc)
      # * <tt>:attempts</tt> - Re-enqueues the job the specified number of times (default: 5 attempts) or a symbol reference of <tt>:unlimited</tt>
      #   to retry the job until it succeeds
      # * <tt>:queue</tt> - Re-enqueues the job on a different queue
      # * <tt>:priority</tt> - Re-enqueues the job with a different priority
      # * <tt>:jitter</tt> - A random delay of wait time used when calculating backoff. The default is 15% (0.15) which represents the upper bound of possible wait time (expressed as a percentage)
      #
      # ==== Examples
      #
      #  class RemoteServiceJob < ActiveJob::Base
      #    retry_on CustomAppException # defaults to ~3s wait, 5 attempts
      #    retry_on AnotherCustomAppException, wait: ->(executions) { executions * 2 }
      #    retry_on CustomInfrastructureException, wait: 5.minutes, attempts: :unlimited
      #
      #    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
      #    retry_on Net::OpenTimeout, Timeout::Error, wait: :exponentially_longer, attempts: 10 # retries at most 10 times for Net::OpenTimeout and Timeout::Error combined
      #    # To retry at most 10 times for each individual exception:
      #    # retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 10
      #    # retry_on Net::ReadTimeout, wait: 5.seconds, jitter: 0.30, attempts: 10
      #    # retry_on Timeout::Error, wait: :exponentially_longer, attempts: 10
      #
      #    retry_on(YetAnotherCustomAppException) do |job, error|
      #      ExceptionNotifier.caught(error)
      #    end
      #
      #    def perform(*args)
      #      # Might raise CustomAppException, AnotherCustomAppException, or YetAnotherCustomAppException for something domain specific
      #      # Might raise ActiveRecord::Deadlocked when a local db deadlock is detected
      #      # Might raise Net::OpenTimeout or Timeout::Error when the remote service is down
      #    end
      #  end
      def retry_on(*exceptions, wait: 3.seconds, attempts: 5, queue: nil, priority: nil, jitter: JITTER_DEFAULT)
        rescue_from(*exceptions) do |error|
          executions = executions_for(exceptions)
          if attempts == :unlimited || executions < attempts
            retry_job wait: determine_delay(seconds_or_duration_or_algorithm: wait, executions: executions, jitter: jitter), queue: queue, priority: priority, error: error
          else
            if block_given?
              instrument :retry_stopped, error: error do
                yield self, error
              end
            else
              instrument :retry_stopped, error: error
              raise error
            end
          end
        end
      end

      # Discard the job with no attempts to retry, if the exception is raised. This is useful when the subject of the job,
      # like an Active Record, is no longer available, and the job is thus no longer relevant.
      #
      # You can also pass a block that'll be invoked. This block is yielded with the job instance as the first and the error instance as the second parameter.
      #
      # ==== Example
      #
      #  class SearchIndexingJob < ActiveJob::Base
      #    discard_on ActiveJob::DeserializationError
      #    discard_on(CustomAppException) do |job, error|
      #      ExceptionNotifier.caught(error)
      #    end
      #
      #    def perform(record)
      #      # Will raise ActiveJob::DeserializationError if the record can't be deserialized
      #      # Might raise CustomAppException for something domain specific
      #    end
      #  end
      def discard_on(*exceptions)
        rescue_from(*exceptions) do |error|
          instrument :discard, error: error do
            yield self, error if block_given?
          end
        end
      end
    end

    # Reschedules the job to be re-executed. This is useful in combination with
    # {rescue_from}[rdoc-ref:ActiveSupport::Rescuable::ClassMethods#rescue_from].
    # When you rescue an exception from your job you can ask Active Job to retry
    # performing your job.
    #
    # ==== Options
    # * <tt>:wait</tt> - Enqueues the job with the specified delay in seconds
    # * <tt>:wait_until</tt> - Enqueues the job at the time specified
    # * <tt>:queue</tt> - Enqueues the job on the specified queue
    # * <tt>:priority</tt> - Enqueues the job with the specified priority
    #
    # ==== Examples
    #
    #  class SiteScraperJob < ActiveJob::Base
    #    rescue_from(ErrorLoadingSite) do
    #      retry_job queue: :low_priority
    #    end
    #
    #    def perform(*args)
    #      # raise ErrorLoadingSite if cannot scrape
    #    end
    #  end
    def retry_job(options = {})
      instrument :enqueue_retry, options.slice(:error, :wait) do
        enqueue options
      end
    end

    private
      JITTER_DEFAULT = Object.new
      private_constant :JITTER_DEFAULT

      def determine_delay(seconds_or_duration_or_algorithm:, executions:, jitter: JITTER_DEFAULT)
        jitter = jitter == JITTER_DEFAULT ? self.class.retry_jitter : (jitter || 0.0)

        case seconds_or_duration_or_algorithm
        when :exponentially_longer
          delay = executions**4
          delay_jitter = determine_jitter_for_delay(delay, jitter)
          delay + delay_jitter + 2
        when ActiveSupport::Duration, Integer
          delay = seconds_or_duration_or_algorithm.to_i
          delay_jitter = determine_jitter_for_delay(delay, jitter)
          delay + delay_jitter
        when Proc
          algorithm = seconds_or_duration_or_algorithm
          algorithm.call(executions)
        else
          raise "Couldn't determine a delay based on #{seconds_or_duration_or_algorithm.inspect}"
        end
      end

      def determine_jitter_for_delay(delay, jitter)
        return 0.0 if jitter.zero?
        Kernel.rand * delay * jitter
      end

      def executions_for(exceptions)
        if exception_executions
          exception_executions[exceptions.to_s] = (exception_executions[exceptions.to_s] || 0) + 1
        else
          # Guard against jobs that were persisted before we started having individual executions counters per retry_on
          executions
        end
      end
  end
end
