require 'active_job/queue_adapters/inline_adapter'
require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'

module ActiveJob
  # The <tt>ActiveJob::QueueAdapter</tt> module is used to load the
  # correct adapter. The default queue adapter is the +:async+ queue.
  module QueueAdapter #:nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_queue_adapter, instance_accessor: false, instance_predicate: false
      self.queue_adapter = :async
    end

    # Includes the setter method for changing the active queue adapter.
    module ClassMethods
      # Returns the backend queue provider. The default queue adapter
      # is the +:async+ queue. See QueueAdapters for more information.
      def queue_adapter
        _queue_adapter
      end

      # Specify the backend queue provider. The default queue adapter
      # is the +:async+ queue. See QueueAdapters for more
      # information.
      def queue_adapter=(name_or_adapter_or_class)
        self._queue_adapter = interpret_adapter(name_or_adapter_or_class)
      end

      private

      def interpret_adapter(name_or_adapter_or_class)
        case name_or_adapter_or_class
        when Symbol, String
          ActiveJob::QueueAdapters.lookup(name_or_adapter_or_class).new
        else
          if queue_adapter?(name_or_adapter_or_class)
            name_or_adapter_or_class
          elsif queue_adapter_class?(name_or_adapter_or_class)
            ActiveSupport::Deprecation.warn "Passing an adapter class is deprecated " \
              "and will be removed in Rails 5.1. Please pass an adapter name " \
              "(.queue_adapter = :#{name_or_adapter_or_class.name.demodulize.remove('Adapter').underscore}) " \
              "or an instance (.queue_adapter = #{name_or_adapter_or_class.name}.new) instead."
              name_or_adapter_or_class.new
          else
            raise ArgumentError
          end
        end
      end

      QUEUE_ADAPTER_METHODS = [:enqueue, :enqueue_at].freeze

      def queue_adapter?(object)
        QUEUE_ADAPTER_METHODS.all? { |meth| object.respond_to?(meth) }
      end

      def queue_adapter_class?(object)
        object.is_a?(Class) && QUEUE_ADAPTER_METHODS.all? { |meth| object.public_method_defined?(meth) }
      end
    end
  end
end
