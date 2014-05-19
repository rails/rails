module ActiveJob
  module QueueAdapters
    class InlineAdapter
      class << self
        def queue(job, *args)
          job.perform *Parameters.deserialize(args)
        end
      end
    end
  end
end