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

        def enqueue_at(*) #:nodoc:
          raise NotImplementedError.new("Use a queueing backend to enqueue jobs in the future. Read more at http://guides.rubyonrails.org/v4.2.0/active_job_basics.html")
        end
      end
    end
  end
end
