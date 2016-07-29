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
      # ==== Options
      # * <tt>:wait</tt> - Re-enqueues the job with the specified delay in seconds
      # * <tt>:attempts</tt> - Re-enqueues the job the specified number of times
      #
      # ==== Examples
      #
      #  class RemoteServiceJob < ActiveJob::Base
      #    retry_on Net::OpenTimeout, wait: 30.seconds, attempts: 10
      #
      #    def perform(*args)
      #      # Might raise Net::OpenTimeout when the remote service is down
      #    end
      #  end
      def retry_on(exception, wait: 3.seconds, attempts: 5)
        rescue_from exception do |error|
          logger.error "Retrying #{self.class} in #{wait} seconds, due to a #{exception}. The original exception was #{error.cause.inspect}."
          retry_job wait: wait if executions < attempts
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
  end
end
