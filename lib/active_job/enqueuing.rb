require 'active_job/parameters'

module ActiveJob
  module Enqueuing
    # Push a job onto the queue.  The arguments must be legal JSON types
    # (string, int, float, nil, true, false, hash or array) or
    # ActiveModel::GlobalIdentication instances.  Arbitrary Ruby objects
    # are not supported.
    #
    # The return value is adapter-specific and may change in a future
    # ActiveJob release.
    def enqueue(*args)
      serialized_args = Parameters.serialize(args)
      instrument_enqueuing :enqueue, args: serialized_args
      queue_adapter.enqueue self, *serialized_args
    end

    # Enqueue a job to be performed at +interval+ from now.
    #
    #   enqueue_in(1.week, "mike")
    #
    # Returns truthy if a job was scheduled.
    def enqueue_in(interval, *args)
      enqueue_at(interval.seconds.from_now, *args)
    end

    # Enqueue a job to be performed at an explicit point in time.
    #
    #   enqueue_at(Date.tomorrow.midnight, "mike")
    #
    # Returns truthy if a job was scheduled.
    def enqueue_at(timestamp, *args)
      serialized_args = Parameters.serialize(args)
      instrument_enqueuing :enqueue_at, args: serialized_args, timestamp: timestamp
      queue_adapter.enqueue_at self, timestamp.to_f, *serialized_args
    end
    
    private
      def instrument_enqueuing(method_name, options = {})
        ActiveSupport::Notifications.instrument "#{method_name}.active_job", options.merge(adapter: queue_adapter, job: self)
      end
  end
end
