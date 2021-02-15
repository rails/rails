# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module ActiveJob
  # The <tt>ActiveJob::QueueAdapter</tt> module is used to load the
  # correct adapter. The default queue adapter is the +:async+ queue.
  module QueueAdapter #:nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_queue_adapter_name, instance_accessor: false, instance_predicate: false
      class_attribute :_queue_adapter, instance_accessor: false, instance_predicate: false

      delegate :queue_adapter, to: :class

      self.queue_adapter = :async
    end

    # Includes the setter method for changing the active queue adapter.
    module ClassMethods
      # Returns the backend queue provider. The default queue adapter
      # is the +:async+ queue. See QueueAdapters for more information.
      def queue_adapter
        _queue_adapter
      end

      # Returns string denoting the name of the configured queue adapter.
      # By default returns <tt>"async"</tt>.
      def queue_adapter_name
        _queue_adapter_name
      end

      # Specify the backend queue provider. The default queue adapter
      # is the +:async+ queue. See QueueAdapters for more
      # information.
      def queue_adapter=(name_or_adapter)
        case name_or_adapter
        when Symbol, String
          queue_adapter = ActiveJob::QueueAdapters.lookup(name_or_adapter).new
          assign_adapter(name_or_adapter.to_s, queue_adapter)
        else
          if queue_adapter?(name_or_adapter)
            adapter_name = "#{name_or_adapter.class.name.demodulize.remove('Adapter').underscore}"
            assign_adapter(adapter_name, name_or_adapter)
          else
            raise ArgumentError
          end
        end
      end

      private
        def assign_adapter(adapter_name, queue_adapter)
          self._queue_adapter_name = adapter_name
          self._queue_adapter = queue_adapter
        end

        QUEUE_ADAPTER_METHODS = [:enqueue, :enqueue_at].freeze

        def queue_adapter?(object)
          QUEUE_ADAPTER_METHODS.all? { |meth| object.respond_to?(meth) }
        end
    end
  end
end
