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

      def start_unloading
        @lock.start_exclusive(purpose: :unload, compatible: [:load, :unload])
      end

      def done_unloading
        @lock.stop_exclusive(compatible: [:load, :unload])
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

      def raw_state(&block) # :nodoc:
        @lock.raw_state(&block)
      end
    end
  end
end
