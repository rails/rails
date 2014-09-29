require 'active_support/concurrency/share_lock'

module ActiveSupport
  module Dependencies #:nodoc:
    class Interlock
      def initialize
        @lock = ActiveSupport::Concurrency::ShareLock.new(true)
      end

      def loading
        @lock.exclusive do
          yield
        end
      end

      # Attempt to obtain a "loading" (exclusive) lock. If possible,
      # execute the supplied block while holding the lock. If there is
      # concurrent activity, return immediately (without executing the
      # block) instead of waiting.
      def attempt_loading
        @lock.exclusive(true) do
          yield
        end
      end

      def start_running
        @lock.start_sharing
      end

      def done_running
        @lock.stop_sharing
      end

      def running
        @lock.sharing do
          yield
        end
      end

      # Match the Mutex API, so we can be used by Rack::Lock
      alias :lock :start_running
      alias :unlock :done_running
    end
  end
end
