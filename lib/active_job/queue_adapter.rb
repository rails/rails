require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  module QueueAdapter
    mattr_reader(:queue_adapter) { ActiveJob::QueueAdapters::InlineAdapter }

    def queue_adapter=(name_or_adapter)
      @@queue_adapter = \
        case name_or_adapter
        when Symbol, String
          load_adapter(name_or_adapter)
        when Class
          name_or_adapter
        end
    end

    private
      def load_adapter(name)
        require "active_job/queue_adapters/#{name}_adapter"
        "ActiveJob::QueueAdapters::#{name.to_s.camelize}Adapter".constantize
      end
  end
end