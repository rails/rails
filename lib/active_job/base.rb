require 'active_job/queue_adapters/inline_adapter'
require 'active_job/queue_adapters/resque_adapter'
require 'active_job/queue_adapters/sidekiq_adapter'
require 'active_job/queue_adapters/sucker_punch_adapter'

module ActiveJob
  class Base
    cattr_accessor(:queue_adapter)   { ActiveJob::QueueAdapters::InlineAdapter }
    cattr_accessor(:queue_base_name) { "active_jobs" }
    cattr_accessor(:queue_name)      { queue_base_name }

    class << self
      def enqueue(*args)
        queue_adapter.queue self, *args
      end
      
      def queue_as(part_name)
        self.queue_name = "#{queue_base_name}_#{part_name}"
      end
    end
  end
end