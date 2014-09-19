require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  module QueueAdapter
    extend ActiveSupport::Concern

    included do
      class_attribute :_queue_adapter
      self._queue_adapter = ActiveJob::QueueAdapters::InlineAdapter unless self._queue_adapter?
    end

    module ClassMethods
      def queue_adapter
        self._queue_adapter
      end

      def queue_adapter=(name_or_adapter)
        self._queue_adapter= \
          case name_or_adapter
          when :test
            ActiveJob::QueueAdapters::TestAdapter.new
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
end