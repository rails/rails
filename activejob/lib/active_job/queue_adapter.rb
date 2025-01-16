# frozen_string_literal: true

require "active_support/core_ext/string/inflections"

module ActiveJob
  class << self
    def adapter_name(adapter) # :nodoc:
      return adapter.queue_adapter_name if adapter.respond_to?(:queue_adapter_name)

      adapter_class = adapter.is_a?(Module) ? adapter : adapter.class
      "#{adapter_class.name.demodulize.delete_suffix('Adapter')}"
    end
  end

  # = Active Job Queue adapter
  #
  # The +ActiveJob::QueueAdapter+ module is used to load the
  # correct adapter. The default queue adapter is +:async+,
  # which loads the ActiveJob::QueueAdapters::AsyncAdapter.
  module QueueAdapter # :nodoc:
    extend ActiveSupport::Concern

    included do
      class_attribute :_queue_adapter_name, instance_accessor: false, instance_predicate: false
      class_attribute :_queue_adapter, instance_accessor: false, instance_predicate: false

      delegate :queue_adapter, to: :class
    end

    # Includes the setter method for changing the active queue adapter.
    module ClassMethods
      # Returns the backend queue provider. The default queue adapter
      # is +:async+. See QueueAdapters for more information.
      def queue_adapter
        self.queue_adapter = :async if _queue_adapter.nil?
        _queue_adapter
      end

      # Returns string denoting the name of the configured queue adapter.
      # By default returns <tt>"async"</tt>.
      def queue_adapter_name
        self.queue_adapter = :async if _queue_adapter_name.nil?
        _queue_adapter_name
      end

      # Specify the backend queue provider. The default queue adapter
      # is the +:async+ queue. See QueueAdapters for more
      # information.
      def queue_adapter=(name_or_adapter)
        case name_or_adapter
        when Symbol, String
          queue_adapter = ActiveJob::QueueAdapters.lookup(name_or_adapter).new
          queue_adapter.try(:check_adapter)
          assign_adapter(name_or_adapter.to_s, queue_adapter)
        else
          if queue_adapter?(name_or_adapter)
            adapter_name = ActiveJob.adapter_name(name_or_adapter).underscore
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
