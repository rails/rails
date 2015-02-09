module ActiveJob
  module QueueAdapters
    # == Active Job Inline adapter
    #
    # When enqueueing jobs with the Inline adapter the job will be executed
    # immediately.
    #
    # To use the Inline set the queue_adapter config to +:inline+.
    #
    #   Rails.application.config.active_job.queue_adapter = :inline
    class InlineAdapter
      class << self
        def enqueue(job) #:nodoc:
          Base.execute(job.serialize)
        end

        def enqueue_at(job, _) #:nodoc:
          Base.execute(job.serialize)
        end
      end
    end
  end
end
