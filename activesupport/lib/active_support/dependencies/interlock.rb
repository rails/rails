# frozen_string_literal: true

require "active_support/concurrency/share_lock"

module ActiveSupport # :nodoc:
  module Dependencies # :nodoc:
    class Interlock
      def initialize # :nodoc:
        @lock = ActiveSupport::Concurrency::ShareLock.new
      end

      def loading(&block)
        ActiveSupport.deprecator.warn(
          "ActiveSupport::Dependencies::Interlock#loading is deprecated and " \
          "will be removed in Rails 9.0. The loading interlock is no longer " \
          "used since Rails switched to Zeitwerk for autoloading."
        )
        yield if block
      end

      def unloading(&block)
        @lock.exclusive(purpose: :unload, compatible: [:unload], after_compatible: [:unload], &block)
      end

      def start_unloading
        @lock.start_exclusive(purpose: :unload, compatible: [:unload])
      end

      def done_unloading
        @lock.stop_exclusive(compatible: [:unload])
      end

      def start_running
        @lock.start_sharing
      end

      def done_running
        @lock.stop_sharing
      end

      def running(&block)
        @lock.sharing(&block)
      end

      def permit_concurrent_loads(&block)
        # Soft deprecated: no deprecation warning for now, but this is a no-op.
        yield if block
      end

      def raw_state(&block) # :nodoc:
        @lock.raw_state(&block)
      end
    end
  end
end
