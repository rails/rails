module ActiveJob
  module QueueAdapters
    class InlineAdapter
      class << self
        def enqueue(job)
          Base.execute(job.serialize)
        end

        def enqueue_at(*)
          raise NotImplementedError.new("Use a queueing backend to enqueue jobs in the future. Read more at https://github.com/rails/activejob")
        end
      end
    end
  end
end
