require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  module QueueAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      class_attribute :queue_adapter

      def queue_adapter_with_interpretation=(name_or_adapter)
        self.queue_adapter_without_interpretation = \
          case name_or_adapter
          when :test
            ActiveJob::QueueAdapters::TestAdapter.new
          when Symbol, String
            load_adapter(name_or_adapter)
          when Class
            name_or_adapter
          end
      end
      alias_method_chain :queue_adapter, :interpretation

      private
        def load_adapter(name)
          "ActiveJob::QueueAdapters::#{name.to_s.camelize}Adapter".constantize
        end
    end
  end
end
