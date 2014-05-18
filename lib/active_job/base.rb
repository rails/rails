require 'active_job/queue_adapters/inline_queue'

module ActiveJob
  class Base
    class << self
      def enqueue(*args)
        ActiveJob::QueueAdapters::InlineQueue.queue self, *args
      end
    end
  end
end