require "active_support/core_ext/numeric/time"

module ActiveJob
  # Provides behavior for retrying and discarding jobs on exceptions.
  module Exceptions
    extend ActiveSupport::Concern

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
      #   as a computing proc that the number of executions so far as an argument, or as a symbol reference of
      #   <tt>:exponentially_longer</tt>, which applies the wait algorithm of <tt>(executions ** 4) + 2</tt>
      #   (first wait 3s, then 18s, then 83s, etc)
      # * <tt>:attempts</tt> - Re-enqueues the job the specified number of times (default: 5 attempts)
      # * <tt>:queue</tt> - Re-enqueues the job on a different queue
      # * <tt>:priority</tt> - Re-enqueues the job with a different priority
      #
      # ==== Examples
      #
      #  class RemoteServiceJob < ActiveJob::Base
      #    retry_on CustomAppException # defaults to 3s wait, 5 attempts
      #    retry_on AnotherCustomAppException, wait: ->(executions) { executions * 2 }
      #    retry_on(YetAnotherCustomAppException) do |job, exception|
      #      ExceptionNotifier.caught(exception)
      #    end
      #    retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
      #    retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 10
      #
      #    def perform(*args)
      #      # Might raise CustomAppException, AnotherCustomAppException, or YetAnotherCustomAppException for something domain specific
      #      # Might raise ActiveRecord::Deadlocked when a local db deadlock is detected
      #      # Might raise Net::OpenTimeout when the remote service is down
      #    end
      #  end
      def retry_on(exception, wait: 3.seconds, attempts: 5, queue: nil, priority: nil)
        rescue_from exception do |error|
          if executions < attempts
            logger.error "Retrying #{self.class} in #{wait} seconds, due to a #{exception}. The original exception was #{error.cause.inspect}."
            retry_job wait: determine_delay(wait), queue: queue, priority: priority
          else
            if block_given?
              yield self, exception
            else
              logger.error "Stopped retrying #{self.class} due to a #{exception}, which reoccurred on #{executions} attempts. The original exception was #{error.cause.inspect}."
              raise error
            end
          end
        end
      end

      # Discard the job with no attempts to retry, if the exception is raised. This is useful when the subject of the job,
      # like an Active Record, is no longer available, and the job is thus no longer relevant.
      #
      # ==== Example
      #
      #  class SearchIndexingJob < ActiveJob::Base
      #    discard_on ActiveJob::DeserializationError
      #
      #    def perform(record)
      #      # Will raise ActiveJob::DeserializationError if the record can't be deserialized
      #    end
      #  end
      def discard_on(exception)
        rescue_from exception do |error|
          logger.error "Discarded #{self.class} due to a #{exception}. The original exception was #{error.cause.inspect}."
        end
      end
    end

    # Reschedules the job to be re-executed. This is useful in combination
    # with the +rescue_from+ option. When you rescue an exception from your job
    # you can ask Active Job to retry performing your job.
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
      enqueue options
    end

    private
      def determine_delay(seconds_or_duration_or_algorithm)
        case seconds_or_duration_or_algorithm
        when :exponentially_longer
          (executions**4) + 2
        when ActiveSupport::Duration
          duration = seconds_or_duration_or_algorithm
          duration.to_i
        when Integer
          seconds = seconds_or_duration_or_algorithm
          seconds
        when Proc
          algorithm = seconds_or_duration_or_algorithm
          algorithm.call(executions)
        else
          raise "Couldn't determine a delay based on #{seconds_or_duration_or_algorithm.inspect}"
        end
      end
  end
end
