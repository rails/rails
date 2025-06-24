# frozen_string_literal: true

module ActiveJob
  module QueueAdapters
    # = Active Job Abstract Adapter
    #
    # Active Job supports multiple job queue systems. ActiveJob::QueueAdapters::AbstractAdapter
    # forms the abstraction layer which makes this possible.
    class AbstractAdapter
      attr_accessor :stopping

      def enqueue(job)
        raise NotImplementedError
      end

      def enqueue_at(job, timestamp)
        raise NotImplementedError
      end

      def stopping?
        !!@stopping
      end
    end
  end
end
