require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  # The <tt>ActionJob::QueueAdapter</tt> module is used to load the 
  # correct adapter. The default queue adapter is the :inline queue.
  module QueueAdapter #:nodoc:
    extend ActiveSupport::Concern

    # Includes the setter method for changing the active queue adapter.
    module ClassMethods
      mattr_reader(:queue_adapter) { ActiveJob::QueueAdapters::InlineAdapter }

      # Specify the backend queue provider. The default queue adapter
      # is the :inline queue. See QueueAdapters for more
      # information.
      def queue_adapter=(name_or_adapter)
        @@queue_adapter = \
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
