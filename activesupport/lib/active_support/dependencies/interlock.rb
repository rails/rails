require 'active_support/concurrency/share_lock'

module ActiveSupport #:nodoc:
  module Dependencies #:nodoc:
    class Interlock
      def initialize # :nodoc:
        @lock = ActiveSupport::Concurrency::ShareLock.new
      end

      def loading
        @lock.exclusive(purpose: :load, compatible: [:load], after_compatible: [:load]) do
          yield
        end
      end

      def unloading
        @lock.exclusive(purpose: :unload, compatible: [:load, :unload], after_compatible: [:load, :unload]) do
          yield
        end
      end

      # Attempt to obtain an "unloading" (exclusive) lock. If possible,
      # execute the supplied block while holding the lock. If there is
      # concurrent activity, return immediately (without executing the
      # block) instead of waiting.
      def attempt_unloading
        @lock.exclusive(purpose: :unload, compatible: [:load, :unload], after_compatible: [:load, :unload], no_wait: true) do
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

      def permit_concurrent_loads
        @lock.yield_shares(compatible: [:load]) do
          yield
        end
      end
    end
  end
end
