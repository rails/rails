require 'active_job/parameters'

module ActiveJob
  module Enqueuing
    ##
    # Push a job onto the queue.  The arguments must be legal JSON types
    # (string, int, float, nil, true, false, hash or array) or
    # ActiveModel::GlobalIdentication instances.  Arbitrary Ruby objects
    # are not supported.
    #
    # The return value is adapter-specific and may change in a future
    # ActiveJob release.
    def enqueue(*args)
      ActiveSupport::Notifications.instrument "enqueue.active_job", adapter: queue_adapter, job: self, params: args
      queue_adapter.queue self, *Parameters.serialize(args)
    end

    ##
    # Enqueue a job to be performed at +interval+ from now.
    #
    #   enqueue_in(1.week, "mike")
    #
    # Returns truthy if a job was scheduled.
    def enqueue_in(interval, *args)
      enqueue_at(interval.from_now, *args)
    end

    ##
    # Enqueue a job to be performed at an explicit point in time.
    #
    #   enqueue_at(Date.tomorrow.midnight, "mike")
    #
    # Returns truthy if a job was scheduled.
    def enqueue_at(timestamp, *args)
      if Time.now.to_f > timestamp
        queue.adapter.queue self, *Parameters.serialize(args)
      else
        queue_adapter.queue_at self, timestamp.to_f, *Parameters.serialize(args)
      end
    end
  end
end
