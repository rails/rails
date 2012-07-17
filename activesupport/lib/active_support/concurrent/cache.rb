require 'thread_safe'

module ActiveSupport
  module Concurrent
    Cache = ThreadSafe::Cache

    class LowWriteCache < Cache
      # Use as little memory as possible, while sacrificing insert/update/remove concurrency/speed.
      LOW_WRITE_DEFAULTS = {:concurrency_level => 1, :initial_capacity => 1}

      def initialize(options = {}, &block)
        super(LOW_WRITE_DEFAULTS.merge(options), &block)
      end
    end
  end
end