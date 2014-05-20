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
      ActiveSupport::Notifications.instrument "enqueue.active_job", adapter: queue_adapter, job: self, args: serialized_args
      queue_adapter.queue self, *serialized_args
    end
  end
end
