# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # Tracks the remaining automatic-retry allowance for one unit of work
    # against the database: a bounded number of attempts, an optional wall
    # clock deadline, and whether a reconnect (permitted at most once, because
    # reconnect! has its own internal retry loop) is still available.
    class RetryBudget # :nodoc:
      attr_reader :retries_remaining

      def initialize(retries:, deadline:, reconnectable:)
        @retries_total = retries
        @retries_remaining = retries
        @deadline = deadline
        @reconnectable = reconnectable
      end

      def reconnectable?
        @reconnectable
      end

      def reconnect_consumed!
        @reconnectable = false
      end

      def expired?
        @deadline ? @deadline < Process.clock_gettime(Process::CLOCK_MONOTONIC) : false
      end

      def available?
        @retries_remaining > 0 && !expired?
      end

      def consume
        return false unless available?

        @retries_remaining -= 1
        true
      end

      def attempts_used
        @retries_total - @retries_remaining
      end
    end
  end
end
