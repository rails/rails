require 'active_job/queue_adapters/inline_adapter'
require 'active_job/queue_adapters/resque_adapter'

module ActiveJob
  class Base
    cattr_accessor(:queue_adapter) { ActiveJob::QueueAdapters::InlineAdapter }
    
    class << self
      def enqueue(*args)
        queue_adapter.queue self, *args
      end
    end
  end
end