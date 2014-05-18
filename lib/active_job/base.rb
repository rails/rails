require 'active_job/errors'
require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

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

      def adapter=(adapter_name)
        adapter_name = adapter_name.to_s
        unless %w(inline resque sidekiq sucker_punch).include?(adapter_name)
          fail ActiveJob::NotImplementedError
        end

        begin
          require_relative "queue_adapters/#{adapter_name}_adapter"
          ActiveJob::Base.queue_adapter = "ActiveJob::QueueAdapters::#{adapter_name.camelize}Adapter".constantize
        rescue
          fail ActiveJob::Error.new("#{adapter_name} is missing")
        end
      end
    end

  end
end