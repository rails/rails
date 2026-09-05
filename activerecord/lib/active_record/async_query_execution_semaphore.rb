# frozen_string_literal: true

# :markup: markdown

require "active_support/isolated_execution_state"
require "concurrent/atomic/semaphore"

module ActiveRecord
  class AsyncQueryExecutionSemaphore # :nodoc:
    STATE_KEY = :active_record_async_query_execution_semaphore
    RESERVED_PERMIT_KEY = :active_record_async_query_execution_semaphore_permit
    private_constant :STATE_KEY, :RESERVED_PERMIT_KEY

    class Permit # :nodoc:
      def initialize(semaphore)
        @semaphore = semaphore
        @mutex = Mutex.new
        @claimed = false
        @released = false
      end

      def claim
        @mutex.synchronize do
          return if @released

          @claimed = true
          self
        end
      end

      def claimed?
        @mutex.synchronize { @claimed }
      end

      def release
        semaphore = @mutex.synchronize do
          return if @released

          @released = true
          @semaphore
        end
        semaphore.release
      end
    end
    private_constant :Permit

    class << self
      def with(limit, &block)
        if current
          raise ArgumentError, "nested async query execution limits are not supported"
        end

        with_state(STATE_KEY, new(limit), &block)
      end

      def reserve(pool, &block)
        semaphore = current
        return block.call unless semaphore && pool.async_executor
        return block.call if pool.active_connection || reserved_permit?

        permit = semaphore.acquire
        with_state(RESERVED_PERMIT_KEY, permit, &block)
      ensure
        permit.release if permit && !permit.claimed?
      end

      def claim_reserved_permit
        ActiveSupport::IsolatedExecutionState[RESERVED_PERMIT_KEY]&.claim
      end

      private
        def current
          ActiveSupport::IsolatedExecutionState[STATE_KEY]
        end

        def reserved_permit?
          ActiveSupport::IsolatedExecutionState.key?(RESERVED_PERMIT_KEY)
        end

        def with_state(key, value)
          state = ActiveSupport::IsolatedExecutionState
          state[key] = value
          yield
        ensure
          state.delete(key)
        end
    end

    def initialize(limit)
      unless limit.is_a?(Integer) && limit.positive?
        raise ArgumentError, "limit must be a positive integer"
      end

      @semaphore = Concurrent::Semaphore.new(limit)
    end

    def acquire
      @semaphore.acquire
      Permit.new(@semaphore)
    end
  end
end
