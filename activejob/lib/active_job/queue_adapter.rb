require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  module QueueAdapter
    attr_accessor(:queue_adapter) { ActiveJob::QueueAdapters::InlineAdapter }

    alias_method :old_queue_adapter=, :queue_adapter=
    def queue_adapter=(name_or_adapter)
      self.old_queue_adapter= \
        case name_or_adapter
        when Symbol, String
          load_adapter(name_or_adapter)
        when Class
          name_or_adapter
        end
    end

    private
      def load_adapter(name)
        "ActiveJob::QueueAdapters::#{name.to_s.camelize}Adapter".constantize
      end
  end
end